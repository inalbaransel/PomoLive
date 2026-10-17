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
        case register(email: String, password: String, username: String, displayName: String?)
        /// `login` is the e-mail address or the username.
        case password(login: String, password: String)
        case session(token: String)
    }

    var credential: Credential
    var timeZone = TimeZone.current.identifier

    private enum CodingKeys: String, CodingKey {
        case method, email, login, password, username, displayName, sessionToken, timeZone
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeZone, forKey: .timeZone)
        switch credential {
        case .register(let email, let password, let username, let displayName):
            try container.encode("register", forKey: .method)
            try container.encode(email, forKey: .email)
            try container.encode(password, forKey: .password)
            try container.encode(username, forKey: .username)
            try container.encodeIfPresent(displayName, forKey: .displayName)
        case .password(let login, let password):
            try container.encode("password", forKey: .method)
            try container.encode(login, forKey: .login)
            try container.encode(password, forKey: .password)
        case .session(let token):
            try container.encode("session", forKey: .method)
            try container.encode(token, forKey: .sessionToken)
        }
    }
}

struct UsernameAvailability: Decodable, Sendable {
    var username: String
    var available: Bool
}

/// Works before sign-in, so the registration form can check a handle while it is typed.
struct CheckUsernameCommand: LibraryCommand {
    typealias Result = UsernameAvailability
    static let event = "username:check"
    var username: String
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
    var theme: String?
    var description: String?
}

struct DeleteRoomCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "room:delete"
    var roomId: String
}

struct RoomStateResult: Decodable, Sendable {
    var room: RoomState
}

/// The owner's edits; `nil` fields stay as they are.
struct UpdateRoomCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "room:update"
    var roomId: String
    var name: String?
    var symbol: String?
    var color: GlyphColor?
    var visibility: RoomKind?
    var theme: String?
    /// An empty string clears it.
    var description: String?
}

struct PreviewRoomCommand: LibraryCommand {
    typealias Result = RoomPreviewResult
    static let event = "room:preview"
    var roomId: String
}

struct RoomMembersCommand: LibraryCommand {
    typealias Result = RoomMembers
    static let event = "room:members"
    var roomId: String
}

/// Owner only: frees the reader's desk here and keeps them out until unbanned.
struct RemoveMemberCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "room:remove"
    var roomId: String
    var userId: String
}

struct UnbanMemberCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "room:unban"
    var roomId: String
    var userId: String
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

/// `nil` fields stay as they are; an empty `bio` clears it.
struct UpdateProfileCommand: LibraryCommand {
    typealias Result = ProfileResult
    static let event = "profile:update"
    var username: String?
    var displayName: String?
    var avatarSpriteId: String?
    var bio: String?
    var statsVisible: Bool?
    /// 0 clears the goal.
    var dailyGoalMinutes: Int?
    var weeklyGoalMinutes: Int?
}

struct PublicProfileResult: Decodable, Sendable {
    var profile: PublicProfile
}

struct UserProfileCommand: LibraryCommand {
    typealias Result = PublicProfileResult
    static let event = "user:profile"
    var userId: String
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

struct ChatMessageResult: Decodable, Sendable {
    var message: ChatMessage
}

/// Posts to the room this connection is looking at. Retrying with the same `clientId` never posts twice.
struct SendChatCommand: LibraryCommand {
    typealias Result = ChatMessageResult
    static let event = "chat:send"
    var body: String
    var clientId: String
}

struct ChatHistoryCommand: LibraryCommand {
    typealias Result = ChatPage
    static let event = "chat:history"
    var before: Int64?
}

struct DeleteChatCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "chat:delete"
    var messageId: String
}

struct ChatTypingCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "chat:typing"
}

struct TaskListResult: Decodable, Sendable {
    var tasks: [FocusTask]
}

struct TaskResult: Decodable, Sendable {
    var task: FocusTask
}

struct ListTasksCommand: LibraryCommand {
    typealias Result = TaskListResult
    static let event = "task:list"
}

struct CreateTaskCommand: LibraryCommand {
    typealias Result = TaskResult
    static let event = "task:create"
    var title: String
}

struct SetTaskDoneCommand: LibraryCommand {
    typealias Result = TaskResult
    static let event = "task:done"
    var id: String
    var done: Bool
}

struct DeleteTaskCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "task:delete"
    var id: String
}

struct FollowCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "user:follow"
    var userId: String
}

struct UnfollowCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "user:unfollow"
    var userId: String
}

struct UserSearchResult: Decodable, Sendable {
    var users: [PublicUser]
}

struct SearchUsersCommand: LibraryCommand {
    typealias Result = UserSearchResult
    static let event = "user:search"
    var query: String
}

struct FriendsCommand: LibraryCommand {
    typealias Result = FriendsOverview
    static let event = "friends:list"
}

struct RoomEventsResult: Decodable, Sendable {
    var events: [RoomEventItem]
}

struct RoomEventResult: Decodable, Sendable {
    var event: RoomEventItem
}

struct ListRoomEventsCommand: LibraryCommand {
    typealias Result = RoomEventsResult
    static let event = "event:list"
    var roomId: String
}

struct CreateRoomEventCommand: LibraryCommand {
    typealias Result = RoomEventResult
    static let event = "event:create"
    var roomId: String
    var title: String
    var startsAt: Int64
    var durationMinutes: Int
}

struct DeleteRoomEventCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "event:delete"
    var eventId: String
}

struct RsvpRoomEventCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "event:rsvp"
    var eventId: String
    var going: Bool
}

struct DeleteAccountCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "account:delete"
    var password: String
}

struct BlockCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "user:block"
    var userId: String
}

struct UnblockCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "user:unblock"
    var userId: String
}

struct BlockedUsersCommand: LibraryCommand {
    typealias Result = UserSearchResult
    static let event = "user:blocked"
}

struct ReportCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "report:create"
    var userId: String
    var reason: ReportReason
    var note: String?
    var messageId: String?
}

struct RegisterPushCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "push:register"

    enum Environment: String, Encodable, Sendable {
        case sandbox = "SANDBOX"
        case production = "PRODUCTION"
    }

    var token: String
    var environment: Environment
}

struct UnregisterPushCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "push:unregister"
    var token: String
}

struct ReactCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "desk:react"
    var deskId: String
    var reaction: DeskReaction
}
