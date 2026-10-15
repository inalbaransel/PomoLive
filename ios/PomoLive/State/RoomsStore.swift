import Observation

/// The Odalar tab: the reader's own rooms, and the ranked public rooms of Keşfet.
@MainActor
@Observable
final class RoomsStore {
    private(set) var overview: RoomsOverview?
    private(set) var discover: DiscoverResult?
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

    func refreshDiscover() async {
        do {
            discover = try await socket.send(DiscoverRoomsCommand())
        } catch {
            if discover == nil { self.error = LibraryError(error) }
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
            discover?.rooms.removeAll { $0.id == room.id }
        } catch {
            self.error = LibraryError(error)
        }
    }

    func reset() {
        overview = nil
        discover = nil
    }
}
