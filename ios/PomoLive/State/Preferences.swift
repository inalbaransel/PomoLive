/// `@AppStorage` keys for reader preferences.
enum Preferences {
    static let defaultMode = "defaultTimerMode"
    static let pomodoroFocusMinutes = "pomodoroFocusMinutes"
    static let pomodoroBreakMinutes = "pomodoroBreakMinutes"
    static let lastCategoryKey = "lastCategoryKey"
    static let phaseNotifications = "phaseNotificationsEnabled"
    static let haptics = "hapticsEnabled"
    static let friendNotifications = "friendNotificationsEnabled"
    static let weeklySummary = "weeklySummaryEnabled"
    static let hasSeenOnboarding = "hasSeenOnboarding"
    /// Prefix; one list of already celebrated badge ids per account.
    static let celebratedBadges = "celebratedBadges"
    static let appearance = "appearance"
    static let focusModeStyle = "focusModeStyle"
    static let clockFace = "focusModeClockFace"
    static let clockTint = "focusModeClockTint"
    static let clockShowsSeconds = "focusModeShowsSeconds"
}
