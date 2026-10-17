import Foundation
import UserNotifications

/// A local notification on Sunday at 20:00 with how the week went, compared to the week before.
/// It is rescheduled with fresh numbers whenever the stats refresh; if the app was last opened in
/// an earlier week, the notification gives no numbers rather than stale ones.
enum WeeklySummary {
    static let identifier = "weekly-summary"
    static let kind = "weeklySummary"

    static var isEnabled: Bool {
        UserDefaults.standard.object(forKey: Preferences.weeklySummary) as? Bool ?? true
    }

    static func schedule(with summary: StatsSummary) async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard isEnabled, await center.notificationSettings().authorizationStatus == .authorized else { return }

        var calendar = Calendar(identifier: .iso8601)
        calendar.timeZone = .current
        let now = Date.now
        guard let fireDate = calendar.nextDate(
            after: now,
            matching: DateComponents(hour: 20, minute: 0, weekday: 1),
            matchingPolicy: .nextTime
        ) else { return }
        let isThisWeek = calendar.isDate(fireDate, equalTo: now, toGranularity: .weekOfYear)

        let content = UNMutableNotificationContent()
        content.title = String(localized: "Haftanın özeti")
        content.body = isThisWeek ? body(for: summary) : String(localized: "Bu hafta nasıl geçti? Odak haftana bir göz at.")
        content.sound = .default
        content.userInfo = ["kind": kind]
        let trigger = UNCalendarNotificationTrigger(
            dateMatching: calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate),
            repeats: false
        )
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content, trigger: trigger))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }

    private static func body(for summary: StatsSummary) -> String {
        guard summary.weekMs >= 60_000 else {
            return String(localized: "Bu hafta henüz odaklanmadın. Pazartesi yeni bir başlangıç!")
        }
        let week = formattedFocus(summary.weekMs)
        guard let last = summary.lastWeekMs, last >= 60_000 else {
            return String(localized: "Bu hafta \(week) odaklandın. Kartını paylaşmaya ne dersin?")
        }
        let change = Int((Double(summary.weekMs - last) / Double(last) * 100).rounded())
        if change >= 5 {
            return String(localized: "Bu hafta \(week) odaklandın, geçen haftadan %\(change) fazla. Harika gidiyorsun!")
        } else if change <= -5 {
            return String(localized: "Bu hafta \(week) odaklandın, geçen haftadan %\(-change) az. Yeni hafta yeni fırsat!")
        }
        return String(localized: "Bu hafta \(week) odaklandın, geçen haftayla neredeyse aynı. İstikrar güzel!")
    }
}
