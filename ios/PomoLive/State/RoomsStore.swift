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

    func reset() {
        overview = nil
    }
}
