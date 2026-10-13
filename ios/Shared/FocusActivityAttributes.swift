import ActivityKit
import Foundation

/// Live Activity contract shared by the app (which starts and updates it) and the widget extension (which draws it).
struct FocusActivityAttributes: ActivityAttributes, Hashable {
    struct ContentState: Codable, Hashable {
        enum Mode: String, Codable, Hashable {
            case focus
            case onBreak
        }

        enum HallPhase: String, Codable, Hashable {
            case focus
            case rest
        }

        var mode: Mode
        var hallPhase: HallPhase
        var hallPhaseEndsAt: Date
        var sessionFocusMinutes: Int
    }

    var taskLabel: String
    var hallName: String
    var avatarSpriteId: String
}
