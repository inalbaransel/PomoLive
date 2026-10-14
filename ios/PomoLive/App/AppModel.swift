import Foundation
import Observation
import SwiftUI
import UIKit

/// Owns the connection lifecycle: sign-in, reconnect with backoff, heartbeats and app backgrounding.
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
    let hall: HallStore

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private let sessionStore = SessionStore()
    @ObservationIgnored private var connectionTask: Task<Void, Never>?
    @ObservationIgnored private var heartbeatTask: Task<Void, Never>?
    @ObservationIgnored private var isActive = true

    init() {
        let address = Bundle.main.object(forInfoDictionaryKey: "PomoLiveServerURL") as? String
        socket = LibrarySocket(url: URL(string: address ?? "")!)
        hall = HallStore(socket: socket)

        if sessionStore.token != nil, let profile = sessionStore.profile {
            user = profile
            hall.user = profile
            phase = .signedIn
        } else {
            phase = .signedOut
        }

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
        connectionTask?.cancel()
        heartbeatTask?.cancel()
        if connection == .online { _ = try? await socket.send(LeaveHallCommand()) }
        await socket.disconnect()
        sessionStore.clear()
        hall.reset()
        user = nil
        connection = .offline
        phase = .signedOut
    }

    func updateProfile(displayName: String?, avatar: AvatarSprite?) async throws {
        let result = try await socket.send(UpdateProfileCommand(displayName: displayName, avatarSpriteId: avatar?.rawValue))
        user = result.user
        hall.user = result.user
        sessionStore.save(profile: result.user)
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

    private func handle(_ event: LibrarySocket.Event) {
        switch event {
        case .disconnected:
            connection = .offline
            heartbeatTask?.cancel()
            ensureConnected()
        case .broadcast(let event):
            hall.apply(event)
        }
    }

    private func openSession(_ credential: AuthenticateCommand.Credential) async throws {
        connection = .connecting
        do {
            try await socket.connect()
            let auth = try await socket.send(AuthenticateCommand(credential: credential))
            sessionStore.save(token: auth.sessionToken, profile: auth.user)
            user = auth.user
            hall.user = auth.user
            try await hall.enter()
            connection = .online
            startHeartbeat()
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
                await self?.hall.heartbeat(background: false)
            }
        }
    }

    /// One last heartbeat before iOS suspends us, so a locked phone keeps its desk for the background lease.
    private func stretchLeaseForBackground() {
        guard connection == .online else { return }
        let taskId = UIApplication.shared.beginBackgroundTask(withName: "StretchDeskLease")
        Task {
            await hall.heartbeat(background: true)
            UIApplication.shared.endBackgroundTask(taskId)
        }
    }
}
