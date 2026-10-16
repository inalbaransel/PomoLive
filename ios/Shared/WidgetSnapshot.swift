import Foundation

/// What the home and lock screen widgets show, written by the app into the shared App Group
/// whenever stats or the desk change. Widgets never talk to the server themselves.
struct WidgetSnapshot: Codable, Equatable, Sendable {
    struct Desk: Codable, Equatable, Sendable {
        var categoryName: String
        var categorySymbol: String
        /// When the current stretch of focus started, for a ticking stopwatch; nil while on a break.
        var focusingSince: Date?
        /// End of the current pomodoro phase, for a countdown; nil for a stopwatch.
        var phaseEndsAt: Date?
        var isResting: Bool
    }

    var todayMs: Int64
    var weekMs: Int64
    var streakDays: Int
    var dailyGoalMinutes: Int?
    var desk: Desk?
    /// The local day `todayMs` belongs to, so a stale snapshot shows 0 after midnight.
    var day: Date
    var updatedAt: Date

    static let appGroup = "group.com.baransel.pomolive"
    private static let key = "widgetSnapshot"

    static var placeholder: WidgetSnapshot {
        WidgetSnapshot(todayMs: 95 * 60_000, weekMs: 7 * 3_600_000, streakDays: 5, dailyGoalMinutes: 120, desk: nil,
                       day: Calendar.current.startOfDay(for: .now), updatedAt: .now)
    }

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    func save() {
        UserDefaults(suiteName: Self.appGroup)?.set(try? JSONEncoder().encode(self), forKey: Self.key)
    }

    /// Today's focus as of `date`: a snapshot from an earlier day counts as nothing yet.
    func todayMs(at date: Date) -> Int64 {
        Calendar.current.isDate(day, inSameDayAs: date) ? todayMs : 0
    }

    var goalProgress: Double? {
        dailyGoalMinutes.map { min(1, Double(todayMs(at: .now)) / Double($0 * 60_000)) }
    }
}
