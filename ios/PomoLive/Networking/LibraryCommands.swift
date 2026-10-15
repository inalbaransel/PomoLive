import Foundation

/// A client → server request. `Result` is the type of the `result` field in the matching `reply`.
protocol LibraryCommand: Encodable, Sendable {
    associatedtype Result: Decodable & Sendable
    static var event: String { get }
}

struct NoResult: Decodable, Sendable {}

struct AuthResult: Decodable, Sendable {
    var user: UserProfile
    var sessionToken: String
    var sessionExpiresAt: Int64
}

struct AuthenticateCommand: LibraryCommand {
    typealias Result = AuthResult
    static let event = "auth"

    enum Credential: Sendable {
        case register(email: String, password: String, displayName: String?)
        case password(email: String, password: String)
        case session(token: String)
    }

    var credential: Credential
    var timeZone = TimeZone.current.identifier

    private enum CodingKeys: String, CodingKey {
        case method, email, password, displayName, sessionToken, timeZone
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeZone, forKey: .timeZone)
        switch credential {
        case .register(let email, let password, let displayName):
            try container.encode("register", forKey: .method)
            try container.encode(email, forKey: .email)
            try container.encode(password, forKey: .password)
            try container.encodeIfPresent(displayName, forKey: .displayName)
        case .password(let email, let password):
            try container.encode("password", forKey: .method)
            try container.encode(email, forKey: .email)
            try container.encode(password, forKey: .password)
        case .session(let token):
            try container.encode("session", forKey: .method)
            try container.encode(token, forKey: .sessionToken)
        }
    }
}

struct ListRoomsCommand: LibraryCommand {
    typealias Result = RoomsOverview
    static let event = "room:list"
}

struct DiscoverRoomsCommand: LibraryCommand {
    typealias Result = DiscoverResult
    static let event = "room:discover"
}

/// Without a target the server returns the reader to their desk's room, or to a hall with space.
struct JoinRoomCommand: LibraryCommand {
    typealias Result = RoomSnapshot
    static let event = "room:join"
    var roomId: String?
    var code: String?
}

struct CreateRoomCommand: LibraryCommand {
    typealias Result = RoomSnapshot
    static let event = "room:create"
    var name: String
    var symbol: String
    var color: GlyphColor
    var visibility: RoomKind
}

struct DeleteRoomCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "room:delete"
    var roomId: String
}

/// Removes a room from "Odalarım" (not for owners, who delete instead).
struct ForgetRoomCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "room:forget"
    var roomId: String
}

/// Stops looking at the room; a desk held there stays taken.
struct LeaveRoomCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "room:leave"
}

struct DeskResult: Decodable, Sendable {
    var desk: DeskRecord
}

struct SitCommand: LibraryCommand {
    typealias Result = DeskResult
    static let event = "desk:sit"
    var deskId: String
    var timer: TimerSetup
    var categoryKey: String
    var note: String?
}

struct StandCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "desk:stand"
}

struct ChangeTimerCommand: LibraryCommand {
    enum Action: String, Encodable, Sendable {
        /// Pauses a stopwatch, or starts a pomodoro break now.
        case rest = "BREAK"
        /// Resumes a stopwatch, or skips the rest of a pomodoro break.
        case resume = "RESUME"
    }

    typealias Result = DeskResult
    static let event = "desk:timer"
    var action: Action
}

struct MySeatResult: Decodable, Sendable {
    var desk: DeskRecord?
    var room: RoomState?
    var serverTime: Int64
}

struct MySeatCommand: LibraryCommand {
    typealias Result = MySeatResult
    static let event = "desk:mine"
}

struct HeartbeatResult: Decodable, Sendable {
    var serverTime: Int64
    var leaseExpiresAt: Int64?
}

struct HeartbeatCommand: LibraryCommand {
    typealias Result = HeartbeatResult
    static let event = "presence:heartbeat"
    var background: Bool
}

struct ProfileResult: Decodable, Sendable {
    var user: UserProfile
}

struct UpdateProfileCommand: LibraryCommand {
    typealias Result = ProfileResult
    static let event = "profile:update"
    var displayName: String?
    var avatarSpriteId: String?
}

struct CategoriesResult: Decodable, Sendable {
    var builtIn: [FocusCategory]
    var custom: [FocusCategory]
}

struct ListCategoriesCommand: LibraryCommand {
    typealias Result = CategoriesResult
    static let event = "category:list"
}

struct CategoryResult: Decodable, Sendable {
    var category: FocusCategory
}

struct CreateCategoryCommand: LibraryCommand {
    typealias Result = CategoryResult
    static let event = "category:create"
    var name: String
    var symbol: String
    var color: GlyphColor
}

struct DeleteCategoryCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "category:delete"
    var id: String
}

struct StatsSummaryCommand: LibraryCommand {
    typealias Result = StatsSummary
    static let event = "stats:summary"
}

struct HistoryPage: Decodable, Sendable {
    var entries: [HistoryEntry]
    var hasMore: Bool
}

struct HistoryCommand: LibraryCommand {
    typealias Result = HistoryPage
    static let event = "history:list"
    var before: Int64?
    var limit = 30
}

struct DeleteAccountCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "account:delete"
    var password: String
}
