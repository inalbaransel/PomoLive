import Foundation
import Observation

/// The people this reader blocked, and reporting others. Blocked readers' chat lines are dropped
/// before they reach the chat, and the server keeps them out of search, follows and profiles.
@MainActor
@Observable
final class SafetyStore {
    private(set) var blocked: [PublicUser] = []
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    func isBlocked(_ userId: String) -> Bool {
        blocked.contains { $0.id == userId }
    }

    func refresh() async {
        do {
            blocked = try await socket.send(BlockedUsersCommand()).users
        } catch {
            self.error = LibraryError(error)
        }
    }

    func block(_ user: PublicUser) async throws {
        _ = try await socket.send(BlockCommand(userId: user.id))
        if !isBlocked(user.id) { blocked.insert(user, at: 0) }
    }

    func unblock(_ userId: String) async throws {
        _ = try await socket.send(UnblockCommand(userId: userId))
        blocked.removeAll { $0.id == userId }
    }

    func report(_ userId: String, reason: ReportReason, note: String?, messageId: String?) async throws {
        let note = note?.trimmingCharacters(in: .whitespacesAndNewlines)
        _ = try await socket.send(ReportCommand(
            userId: userId, reason: reason, note: note?.isEmpty == false ? note : nil, messageId: messageId
        ))
    }

    func reset() {
        blocked = []
    }
}
