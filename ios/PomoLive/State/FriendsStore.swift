import Foundation
import Observation
import UserNotifications

/// The readers this one follows: who is focusing now, this week's ranking, and search to find more.
/// When someone followed sits down while the app is running, a notification says so; while it is
/// closed, the server sends the same as a push.
@MainActor
@Observable
final class FriendsStore {
    private(set) var overview: FriendsOverview?
    private(set) var searchResults: [PublicUser] = []
    var error: LibraryError?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private var searchTask: Task<Void, Never>?
    /// When each friend last triggered a notification, so standing up and sitting back down
    /// does not ping again; matches the server's push cooldown.
    @ObservationIgnored private var lastNotified: [String: Date] = [:]

    private static let notificationCooldown: TimeInterval = 30 * 60

    init(socket: LibrarySocket) {
        self.socket = socket
    }

    var focusingFriends: [Friend] { overview?.friends.filter { $0.activity != nil } ?? [] }

    func refresh() async {
        do {
            overview = try await socket.send(FriendsCommand())
        } catch {
            if overview == nil { self.error = LibraryError(error) }
        }
    }

    func follow(_ userId: String) async throws {
        _ = try await socket.send(FollowCommand(userId: userId))
        await refresh()
    }

    func unfollow(_ userId: String) async throws {
        _ = try await socket.send(UnfollowCommand(userId: userId))
        await refresh()
    }

    func isFollowing(_ userId: String) -> Bool {
        overview?.friends.contains { $0.id == userId } ?? false
    }

    /// Debounced, so typing a name sends one request.
    func search(_ query: String) {
        searchTask?.cancel()
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else { return searchResults = [] }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let users = (try? await socket.send(SearchUsersCommand(query: trimmed)).users) ?? []
            guard !Task.isCancelled else { return }
            searchResults = users
        }
    }

    func apply(_ event: LibraryEvent) {
        guard case .friendStarted(_, let desk) = event else { return }
        Task { await refresh() }
        guard UserDefaults.standard.object(forKey: Preferences.friendNotifications) as? Bool ?? true else { return }
        if let last = lastNotified[desk.userId], Date.now.timeIntervalSince(last) < Self.notificationCooldown { return }
        lastNotified[desk.userId] = .now
        let content = UNMutableNotificationContent()
        content.title = String(localized: "\(desk.userName) çalışmaya başladı")
        content.body = String(localized: "\(desk.category.displayName) · Katılmak için Arkadaşlar'a bak.")
        content.sound = .default
        content.threadIdentifier = "friends"
        content.userInfo = ["kind": "friendStarted", "userId": desk.userId]
        let request = UNNotificationRequest(identifier: "friend-\(desk.userId)", content: content, trigger: nil)
        Task {
            let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
            guard status == .authorized else { return }
            try? await UNUserNotificationCenter.current().add(request)
        }
    }

    func reset() {
        lastNotified = [:]
        overview = nil
        searchResults = []
    }
}
