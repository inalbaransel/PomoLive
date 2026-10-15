import Observation

/// The Odalar tab: system halls, public rooms and the reader's own rooms with live counts.
@MainActor
@Observable
final class RoomsStore {
    private(set) var overview: RoomsOverview?
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    func refresh() async {
        do {
            overview = try await socket.send(ListRoomsCommand())
        } catch {
            if overview == nil { self.error = LibraryError(error) }
        }
    }

    func forget(_ room: RoomSummary) async {
        do {
            _ = try await socket.send(ForgetRoomCommand(roomId: room.id))
            overview?.myRooms.removeAll { $0.id == room.id }
        } catch {
            self.error = LibraryError(error)
        }
    }

    func delete(_ room: RoomSummary) async {
        do {
            _ = try await socket.send(DeleteRoomCommand(roomId: room.id))
            overview?.myRooms.removeAll { $0.id == room.id }
            overview?.publicRooms.removeAll { $0.id == room.id }
        } catch {
            self.error = LibraryError(error)
        }
    }

    func reset() {
        overview = nil
    }
}
