import Foundation
import Observation
import SwiftUI
import UIKit

/// Owns the connection lifecycle (sign-in, reconnect with backoff, heartbeats, backgrounding)
/// and the stores the tabs read from.
@MainActor
@Observable
final class AppModel {
    enum Phase {
        case signedOut, signedIn
    }

    enum Connection {
        case offline, connecting, online
    }

    private(set) var phase: Phase
    private(set) var connection: Connection = .offline
    private(set) var user: UserProfile?
    private(set) var isSigningIn = false

    let time = ServerTime()
    let seat: SeatStore
    let hall: HallStore
    let rooms: RoomsStore
    let stats: StatsStore
    let categories: CategoryStore
    let chat: ChatStore
    let tasks: TaskStore
    let friends: FriendsStore
    let events: RoomEventsStore
    let safety: SafetyStore
    let push: PushNotifications
    let plus: PlusStore
    let match: MatchStore
    let sounds = AmbientPlayer()
    /// The server's web pages (privacy policy, terms, support) live next to its socket.
    let website: URL
    @ObservationIgnored private let widgets = WidgetBridge()

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private let sessionStore = SessionStore()
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var isActive = true

    init() {
        let address = Bundle.main.object(forInfoDictionaryKey: "PomoLiveServerURL") as? String
        let socketURL = URL(string: address ?? "")!
        socket = LibrarySocket(url: socketURL)
        website = Self.website(for: socketURL)
        seat = SeatStore(socket: socket, time: time)
        hall = HallStore(socket: socket, time: time, seat: seat)
        rooms = RoomsStore(socket: socket)
        stats = StatsStore(socket: socket)
        categories = CategoryStore(socket: socket)
        chat = ChatStore(socket: socket)
        tasks = TaskStore(socket: socket)
        friends = FriendsStore(socket: socket)
        events = RoomEventsStore(socket: socket)
        safety = SafetyStore(socket: socket)
        push = PushNotifications(socket: socket)
        plus = PlusStore(socket: socket)
        match = MatchStore(socket: socket)

        // A profile cached by an older version may not decode; the session token alone is enough to reconnect.
        phase = sessionStore.token == nil ? .signedOut : .signedIn
        if phase == .signedIn, let restored = sessionStore.profile { adopt(restored) }

        widgets.start(self)
        Task { [weak self, events = socket.events] in
            for await event in events { self?.handle(event) }
        }
    }

    func signIn(with credential: AuthenticateCommand.Credential) async throws {
        isSigningIn = true
        defer { isSigningIn = false }
        try await openSession(credential)
        phase = .signedIn
    }

    func signOut() async {
        await push.signOut()
        connectionTask?.cancel()
        heartbeatTask?.cancel()
        await socket.disconnect()
        endSession()
    }

    /// Permanently deletes the account after re-checking the password.
    func deleteAccount(password: String) async throws {
        _ = try await socket.send(DeleteAccountCommand(password: password))
        connectionTask?.cancel()
        heartbeatTask?.cancel()
        await socket.disconnect()
        endSession()
    }

    func updateProfile(_ changes: UpdateProfileCommand) async throws {
        let result = try await socket.send(changes)
        adopt(result.user)
        sessionStore.save(profile: result.user)
    }

    /// Blocks someone and takes them out of everything on screen at once.
    func block(_ user: PublicUser) async throws {
        try await safety.block(user)
        chat.hideMessages(from: user.id)
        await friends.refresh()
    }

    /// One-off commands whose results belong to a single screen rather than a store.
    func socketSend<Command: LibraryCommand>(_ command: Command) async throws -> Command.Result {
        try await socket.send(command)
    }

    func profile(of userId: String) async throws -> PublicProfile {
        try await socket.send(UserProfileCommand(userId: userId)).profile
    }

    /// Opens a connection without signing in if needed: the server answers this before authentication.
    func isUsernameAvailable(_ username: String) async throws -> Bool {
        if await !socket.isConnected { try await socket.connect() }
        return try await socket.send(CheckUsernameCommand(username: username)).available
    }

    func scenePhaseChanged(to scenePhase: ScenePhase) {
        switch scenePhase {
        case .active:
            isActive = true
            ensureConnected()
        case .background:
            isActive = false
            stretchLeaseForBackground()
        default:
            break
        }
    }

    func ensureConnected() {
        guard phase == .signedIn, isActive, connection == .offline, connectionTask == nil else { return }
        connectionTask = Task { [weak self] in
            await self?.reconnectWithBackoff()
            self?.connectionTask = nil
        }
    }

    // MARK: - Private

    /// `wss://host/ws` → `https://host`.
    private static func website(for socketURL: URL) -> URL {
        var components = URLComponents(url: socketURL, resolvingAgainstBaseURL: false)!
        components.scheme = components.scheme == "ws" ? "http" : "https"
        components.path = ""
        return components.url!
    }

    private func adopt(_ profile: UserProfile) {
        user = profile
        seat.userId = profile.id
        hall.userId = profile.id
        chat.userId = profile.id
        stats.userId = profile.id
    }

    private func endSession() {
        sessionStore.clear()
        seat.reset()
        hall.reset()
        rooms.reset()
        stats.reset()
        categories.reset()
        chat.reset()
        tasks.reset()
        friends.reset()
        events.reset()
        safety.reset()
        plus.reset()
        match.reset()
        sounds.stop()
        user = nil
        connection = .offline
        phase = .signedOut
    }

    private func handle(_ event: LibrarySocket.Event) {
        switch event {
        case .disconnected:
            connection = .offline
            heartbeatTask?.cancel()
            ensureConnected()
        case .broadcast(let event):
            hall.apply(event)
            if !isFromBlockedReader(event) { chat.apply(event) }
            friends.apply(event)
            events.apply(event)
            match.apply(event)
            seat.apply(event)
        }
    }

    private func isFromBlockedReader(_ event: LibraryEvent) -> Bool {
        switch event {
        case .chatMessage(let message): safety.isBlocked(message.user.id)
        case .chatTyping(_, let user): safety.isBlocked(user.id)
        default: false
        }
    }

    private func openSession(_ credential: AuthenticateCommand.Credential) async throws {
        connection = .connecting
        do {
            try await socket.connect()
            let auth = try await socket.send(AuthenticateCommand(credential: credential))
            sessionStore.save(token: auth.sessionToken, profile: auth.user)
            adopt(auth.user)
            connection = .online
            startHeartbeat()
            async let seatRefresh: Void = seat.refresh()
            async let categoriesRefresh: Void = categories.refresh()
            async let tasksRefresh: Void = tasks.refresh()
            async let friendsRefresh: Void = friends.refresh()
            async let safetyRefresh: Void = safety.refresh()
            async let hallRejoin: Void = hall.rejoin()
            async let pushSync: Void = push.signedIn()
            async let plusSync: Void = plus.signedIn()
            _ = await (seatRefresh, categoriesRefresh, tasksRefresh, friendsRefresh, safetyRefresh, pushSync, plusSync, hallRejoin)
            // The server forgot what this connection looked at; catch up on messages missed while offline.
            if let roomId = hall.room?.id { await chat.open(roomId: roomId) }
        } catch {
            await socket.disconnect()
            connection = .offline
            throw error
        }
    }

    private func reconnectWithBackoff() async {
        var delay = Duration.seconds(1)
        while !Task.isCancelled, phase == .signedIn, isActive {
            guard let token = sessionStore.token else { return await signOut() }
            do {
                return try await openSession(.session(token: token))
            } catch let error as LibraryError where error.isUnauthorized {
                return await signOut()
            } catch {
                try? await Task.sleep(for: delay)
                delay = min(delay * 2, .seconds(30))
            }
        }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(30))
                await self?.heartbeat(background: false)
            }
        }
    }

    /// Keeps presence and the desk lease alive, and re-measures the clock offset each round-trip.
    private func heartbeat(background: Bool) async {
        let sentAt = ServerClock.deviceNow()
        guard let result = try? await socket.send(HeartbeatCommand(background: background)) else { return }
        time.calibrate(serverTime: result.serverTime, sentAt: sentAt)
    }

    /// One last heartbeat before iOS suspends us, so a locked phone keeps its desk for the background lease.
    private func stretchLeaseForBackground() {
        guard connection == .online else { return }
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "StretchDeskLease")
        Task {
            await heartbeat(background: true)
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }
}
