import Foundation
import UserNotifications

/// Local notifications at pomodoro phase changes, so a locked phone still says "Mola zamanı".
/// Scheduled ahead from the timer's anchors; nothing needs to run in the background.
@MainActor
final class PhaseNotifications {
    private static let identifierPrefix = "phase-"
    private static let scheduledChanges = 8
    private let center = UNUserNotificationCenter.current()

    /// Replaces any scheduled reminders with the next phase changes of `timer`. Pass `nil` to clear.
    func schedule(for timer: DeskTimer?, categoryEmoji: String, clock: ServerClock, enabled: Bool) {
        clear()
        guard enabled, let timer else { return }
        let changes = timer.upcomingPhaseChanges(after: clock.now, count: Self.scheduledChanges)
        guard !changes.isEmpty else { return }

        Task {
            guard (try? await center.requestAuthorization(options: [.alert, .sound])) == true else { return }
            for (index, change) in changes.enumerated() {
                let content = UNMutableNotificationContent()
                content.title = change.phase == .rest ? "Mola zamanı ☕" : "Odak zamanı \(categoryEmoji)"
                content.body = change.phase == .rest ? "Biraz dinlen, masan seni bekliyor." : "Mola bitti, kaldığın yerden devam."
                content.sound = .default
                content.interruptionLevel = .timeSensitive
                let delay = max(1, clock.localDate(change.at).timeIntervalSinceNow)
                let trigger = UNTimeIntervalNotificationTrigger(timeInterval: delay, repeats: false)
                try? await center.add(UNNotificationRequest(identifier: "\(Self.identifierPrefix)\(index)", content: content, trigger: trigger))
            }
        }
    }

    func clear() {
        center.removePendingNotificationRequests(withIdentifiers: (0..<Self.scheduledChanges).map { "\(Self.identifierPrefix)\($0)" })
    }
}
