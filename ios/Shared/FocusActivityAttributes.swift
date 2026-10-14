import ActivityKit
import Foundation

/// Live Activity contract shared by the app (which starts and updates it) and the widget extension (which draws it).
struct FocusActivityAttributes: ActivityAttributes, Hashable {
    struct ContentState: Codable, Hashable {
        enum Phase: String, Codable, Hashable {
            case focus
            case rest
        }

        var phase: Phase
        /// Pomodoro: the widget counts down to this.
        var phaseEndsAt: Date?
        /// Running stopwatch: the widget counts up from this (total focus so far is folded in).
        var countUpFrom: Date?
        var focusedMinutes: Int
    }

    var categoryEmoji: String
    var categoryName: String
    var roomName: String
    var avatarSpriteId: String
    var isPomodoro: Bool
}
