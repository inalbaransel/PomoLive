import Foundation
import Observation
import UIKit
import UserNotifications

/// Notifications from the server while the app is closed, and where taps on any notification lead.
/// The device is registered with APNs only while the reader wants to hear about friends; the server
/// sends nothing to readers who are online, since the socket already tells them.
@MainActor
@Observable
final class PushNotifications: NSObject {
    enum Route: Hashable {
        case friends
        case stats
    }

    /// Where a tapped notification asked to go; the screen that handles it sets it back to nil.
    var pendingRoute: Route?

    @ObservationIgnored private let socket: LibrarySocket
    @ObservationIgnored private var deviceToken: String?
    @ObservationIgnored private var isSignedIn = false

    private static var environment: RegisterPushCommand.Environment {
        #if DEBUG
        .sandbox
        #else
        .production
        #endif
    }

    init(socket: LibrarySocket) {
        self.socket = socket
        super.init()
        UNUserNotificationCenter.current().delegate = self
    }

    var wantsFriendNotifications: Bool {
        UserDefaults.standard.object(forKey: Preferences.friendNotifications) as? Bool ?? true
    }

    /// Asks for permission once, then registers if the reader agreed.
    func requestPermission() async {
        _ = try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])
        await sync()
    }

    /// Brings the server in line with the preference and permission; call after every sign-in.
    func signedIn() async {
        isSignedIn = true
        await sync()
    }

    func sync() async {
        guard isSignedIn else { return }
        let status = await UNUserNotificationCenter.current().notificationSettings().authorizationStatus
        if wantsFriendNotifications, [.authorized, .provisional, .ephemeral].contains(status) {
            UIApplication.shared.registerForRemoteNotifications()
            await upload()
        } else {
            await withdraw()
        }
    }

    /// Stops pushes to this device before the account leaves it.
    func signOut() async {
        await withdraw()
        isSignedIn = false
    }

    func didRegister(deviceToken data: Data) {
        deviceToken = data.map { String(format: "%02x", $0) }.joined()
        Task { await upload() }
    }

    private func upload() async {
        guard isSignedIn, wantsFriendNotifications, let deviceToken else { return }
        _ = try? await socket.send(RegisterPushCommand(token: deviceToken, environment: Self.environment))
    }

    private func withdraw() async {
        guard isSignedIn, let deviceToken else { return }
        _ = try? await socket.send(UnregisterPushCommand(token: deviceToken))
    }
}

extension PushNotifications: UNUserNotificationCenterDelegate {
    /// Banners show even while the app is in front.
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let kind = response.notification.request.content.userInfo["kind"] as? String
        let route: Route? = switch kind {
        case "friendStarted": .friends
        case WeeklySummary.kind: .stats
        default: nil
        }
        guard let route else { return }
        await MainActor.run { pendingRoute = route }
    }
}
