import Foundation
import Observation

/// Everything about the hall the reader is in: layout, who sits where, and the shared cycle.
/// Server pushes and command replies both flow through here, so the map is always one source of truth.
@MainActor
@Observable
final class HallStore {
    private(set) var room: RoomState?
    private(set) var layout: LibraryLayout?
    private(set) var desks: [String: DeskRecord] = [:]
    private(set) var cycle: HallCycle?
    private(set) var clock = ServerClock()
    var user: UserProfile?
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private let haptics = ArcadeHaptics()
    @ObservationIgnored private let liveActivity = FocusActivityController()
    @ObservationIgnored private var cycleTask: Task<Void, Never>?

    init(socket: LibrarySocket) {
        self.socket = socket
        liveActivity.end()
    }

    var myDesk: DeskRecord? {
        guard let userId = user?.id else { return nil }
        return desks.values.first { $0.userId == userId }
    }

    var title: String {
        guard let room else { return "PomoLive" }
        switch room.type {
        case .public: return "Piksel Salon \(room.id.split(separator: "-").last ?? "")"
        case .private: return "Özel Salon"
        }
    }

    // MARK: - Commands

    /// (Re)enters the current hall after (re)connecting; private halls are re-joined by code.
    func enter() async throws {
        try await join(code: room?.type == .private ? room?.code : nil)
    }

    func join(code: String?) async throws {
        let sentAt = ServerClock.deviceNow()
        let snapshot = try await socket.send(JoinHallCommand(code: code))
        clock.calibrate(serverTime: snapshot.serverTime, sentAt: sentAt, receivedAt: ServerClock.deviceNow())
        apply(snapshot)
    }

    func switchHall(code: String?) async {
        await perform { try await self.join(code: code) }
    }

    func createPrivateHall() async {
        await perform { self.apply(try await self.socket.send(CreateHallCommand())) }
    }

    func returnToPublicHall() async {
        await perform {
            _ = try await self.socket.send(LeaveHallCommand())
            try await self.join(code: nil)
        }
    }

    func sit(at desk: LayoutDesk, taskLabel: String) async {
        await perform {
            let result = try await self.socket.send(SitCommand(deskId: desk.deskId, taskLabel: taskLabel))
            self.upsert(result.desk)
            self.haptics.play(.sitDown)
        }
    }

    func stand() async {
        guard let desk = myDesk else { return }
        await perform {
            _ = try await self.socket.send(StandCommand())
            self.remove(deskId: desk.deskId)
            self.haptics.play(.standUp)
        }
    }

    func toggleBreak() async {
        guard let desk = myDesk else { return }
        await perform {
            let status: DeskStatus = desk.status == .focus ? .onBreak : .focus
            self.upsert(try await self.socket.send(SetStatusCommand(status: status)).desk)
            self.haptics.play(.toggleBreak)
        }
    }

    /// Keeps presence and the desk lease alive, and re-measures the clock offset on every round-trip.
    func heartbeat(background: Bool) async {
        let sentAt = ServerClock.deviceNow()
        guard let result = try? await socket.send(HeartbeatCommand(background: background)) else { return }
        clock.calibrate(serverTime: result.serverTime, sentAt: sentAt, receivedAt: ServerClock.deviceNow())
    }

    func reset() {
        cycleTask?.cancel()
        room = nil
        layout = nil
        desks = [:]
        cycle = nil
        user = nil
        liveActivity.end()
    }

    // MARK: - Server state

    func apply(_ snapshot: RoomSnapshot) {
        room = snapshot.room
        layout = snapshot.layout
        desks = Dictionary(uniqueKeysWithValues: snapshot.desks.map { ($0.deskId, $0) })
        scheduleCycle()
    }

    func apply(_ event: LibraryEvent) {
        switch event {
        case .deskOccupied(let desk), .deskUpdated(let desk):
            upsert(desk)
        case .deskVacated(let deskId, let userId):
            if desks[deskId]?.userId == userId { remove(deskId: deskId) }
        case .presence(let presenceCount, let occupiedCount):
            room?.presenceCount = presenceCount
            room?.occupiedCount = occupiedCount
        }
    }

    private func upsert(_ desk: DeskRecord) {
        desks[desk.deskId] = desk
        room?.occupiedCount = desks.count
        syncLiveActivity()
    }

    private func remove(deskId: String) {
        desks[deskId] = nil
        room?.occupiedCount = desks.count
        syncLiveActivity()
    }

    private func perform(_ operation: () async throws -> Void) async {
        do {
            try await operation()
        } catch {
            self.error = LibraryError(error)
            haptics.play(.denied)
        }
    }

    // MARK: - Cycle & Live Activity

    /// Recomputes the hall cycle exactly at each phase boundary instead of ticking every second.
    private func scheduleCycle() {
        cycleTask?.cancel()
        cycleTask = Task { [weak self] in
            while let delay = self?.advanceCycle() {
                try? await Task.sleep(for: .milliseconds(delay))
                if Task.isCancelled { return }
            }
        }
    }

    private func advanceCycle() -> Int64? {
        guard let room else { return nil }
        let next = HallCycle(room: room, serverNow: clock.now)
        if let cycle, cycle.phase != next.phase, myDesk != nil { haptics.play(.phaseChange) }
        cycle = next
        syncLiveActivity()
        return max(50, next.endsAt - clock.now + 50)
    }

    private func syncLiveActivity() {
        guard let desk = myDesk, let cycle else {
            liveActivity.end()
            return
        }
        liveActivity.sync(
            attributes: FocusActivityAttributes(taskLabel: desk.taskLabel, hallName: title, avatarSpriteId: desk.avatarSpriteId),
            state: FocusActivityAttributes.ContentState(
                mode: desk.status == .focus ? .focus : .onBreak,
                hallPhase: cycle.phase == .focus ? .focus : .rest,
                hallPhaseEndsAt: clock.localDate(cycle.endsAt),
                sessionFocusMinutes: Int(desk.focusedMs(at: clock.now) / 60_000)
            )
        )
    }
}
