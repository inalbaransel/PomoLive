import Foundation
import Observation

/// The room the reader is looking at: its map and who sits where. The reader's own desk is
/// mirrored into `SeatStore`, which outlives this screen.
@MainActor
@Observable
final class HallStore {
    enum Target: Hashable {
        /// The room where the reader holds a desk, otherwise a hall with space.
        case automatic
        case room(id: String)
        case code(String)
    }

    private(set) var room: RoomState?
    private(set) var layout: LibraryLayout?
    private(set) var desks: [String: DeskRecord] = [:]
    /// Set when the owner deleted the room while the reader was inside.
    private(set) var wasClosed = false
    var userId: String?
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private let time: ServerTime
    @ObservationIgnored private let seat: SeatStore
    /// Bumped on every entry, so a late `leave` from a closed screen cannot undo a newer visit.
    @ObservationIgnored private(set) var visit = 0

    init(socket: LibrarySocket, time: ServerTime, seat: SeatStore) {
        self.socket = socket
        self.time = time
        self.seat = seat
    }

    var myDesk: DeskRecord? {
        desks.values.first { $0.userId == userId }
    }

    var isOwner: Bool {
        room?.ownerId != nil && room?.ownerId == userId
    }

    func enter(_ target: Target) async throws {
        visit += 1
        let command: JoinRoomCommand = switch target {
        case .automatic: JoinRoomCommand()
        case .room(let id): JoinRoomCommand(roomId: id)
        case .code(let code): JoinRoomCommand(code: code)
        }
        apply(try await timed { try await self.socket.send(command) })
    }

    func create(name: String, symbol: String, color: GlyphColor, visibility: RoomKind) async throws {
        visit += 1
        apply(try await timed { try await self.socket.send(CreateRoomCommand(name: name, symbol: symbol, color: color, visibility: visibility)) })
    }

    /// After a reconnect the server has forgotten what this connection looked at.
    func rejoin() async {
        guard let room else { return }
        try? await enter(.room(id: room.id))
    }

    /// Stops looking at the room entered during `visit`. The reader's desk, if any, stays taken.
    func leave(visit: Int) async {
        guard visit == self.visit else { return }
        reset()
        _ = try? await socket.send(LeaveRoomCommand())
    }

    func deleteRoom() async {
        guard let room else { return }
        do {
            _ = try await socket.send(DeleteRoomCommand(roomId: room.id))
            reset()
        } catch {
            self.error = LibraryError(error)
        }
    }

    func sit(at desk: LayoutDesk, timer: TimerSetup, categoryKey: String, note: String?) async -> Bool {
        do {
            let result = try await socket.send(SitCommand(deskId: desk.deskId, timer: timer, categoryKey: categoryKey, note: note))
            desks[result.desk.deskId] = result.desk
            if let room { seat.adopt(result.desk, in: room) }
            return true
        } catch {
            self.error = LibraryError(error)
            return false
        }
    }

    func apply(_ event: LibraryEvent) {
        switch event {
        case .deskOccupied(let roomId, let desk), .deskUpdated(let roomId, let desk):
            guard roomId == room?.id else { return }
            desks[desk.deskId] = desk
            room?.occupiedCount = desks.count
        case .deskVacated(let roomId, let deskId, let userId):
            guard roomId == room?.id, desks[deskId]?.userId == userId else { return }
            desks[deskId] = nil
            room?.occupiedCount = desks.count
        case .presence(let roomId, let presenceCount, let occupiedCount):
            guard roomId == room?.id else { return }
            room?.presenceCount = presenceCount
            room?.occupiedCount = occupiedCount
        case .roomClosed(let roomId):
            guard roomId == room?.id else { return }
            reset()
            wasClosed = true
        }
    }

    func reset() {
        room = nil
        layout = nil
        desks = [:]
        wasClosed = false
    }

    private func apply(_ snapshot: RoomSnapshot) {
        room = snapshot.room
        layout = snapshot.layout
        desks = Dictionary(uniqueKeysWithValues: snapshot.desks.map { ($0.deskId, $0) })
        wasClosed = false
        if let mine = myDesk { seat.adopt(mine, in: snapshot.room) }
    }

    /// Sends a join-style command and calibrates the clock from its snapshot.
    private func timed(_ send: () async throws -> RoomSnapshot) async throws -> RoomSnapshot {
        let sentAt = ServerClock.deviceNow()
        let snapshot = try await send()
        time.calibrate(serverTime: snapshot.serverTime, sentAt: sentAt)
        return snapshot
    }
}
