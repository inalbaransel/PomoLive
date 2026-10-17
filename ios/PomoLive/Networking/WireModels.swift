import Foundation

// Mirrors the server's wire contract (`server/src/realtime/protocol.ts`, `library.types.ts`).
// Timestamps are milliseconds since the Unix epoch on the server's clock; convert with `ServerClock`.

/// The signed-in reader's own account, with their settings.
struct UserProfile: Codable, Hashable, Sendable {
    var id: String
    var username: String
    var displayName: String
    var avatarSpriteId: String
    var bio: String?
    var statsVisible: Bool
    /// Focus goals in minutes; missing or nil means no goal.
    var dailyGoalMinutes: Int?
    var weeklyGoalMinutes: Int?

    var publicUser: PublicUser {
        PublicUser(id: id, username: username, displayName: displayName, avatarSpriteId: avatarSpriteId)
    }
}

/// What other readers see of someone.
struct PublicUser: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var username: String
    var displayName: String
    var avatarSpriteId: String
}

/// A reader's profile page. `stats` and `focusingOn` are empty when they hide their focus time.
struct PublicProfile: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var username: String
    var displayName: String
    var avatarSpriteId: String
    var bio: String?
    var joinedAt: Int64
    var isSelf: Bool
    var statsVisible: Bool
    /// Focus goals in minutes; missing or nil means no goal.
    var dailyGoalMinutes: Int?
    var weeklyGoalMinutes: Int?
    /// Missing from servers older than follows.
    var isFollowing: Bool?
    /// Whether the viewer blocked this reader; missing from servers older than blocking.
    var isBlocked: Bool?
    var followerCount: Int?
    var followingCount: Int?
    var focusingOn: FocusCategory?
    var stats: StatsSummary?

    var publicUser: PublicUser {
        PublicUser(id: id, username: username, displayName: displayName, avatarSpriteId: avatarSpriteId)
    }
}

/// Someone who belongs to or is inside a room, as listed in its people sheet.
struct RoomPerson: Decodable, Hashable, Sendable, Identifiable {
    enum Role: String, Decodable, Sendable {
        case owner = "OWNER"
        case member = "MEMBER"
        case guest = "GUEST"
    }

    struct Desk: Decodable, Hashable, Sendable {
        var deskId: String
        var category: FocusCategory
        var resting: Bool
    }

    var user: PublicUser
    var role: Role
    /// Looking at the room or holding a desk in it.
    var isHere: Bool
    var desk: Desk?
    /// Focus here over the last 7 days; `nil` when the reader hides it.
    var weekFocusMs: Int64?

    var id: String { user.id }
}

struct RoomMembers: Decodable, Sendable {
    /// Most focused first.
    var people: [RoomPerson]
    /// Only sent to the room's owner.
    var banned: [PublicUser]?
}

/// A focus category: one of the built-in ones or a reader's own (`custom:<id>` keys).
struct FocusCategory: Codable, Hashable, Sendable, Identifiable {
    var key: String
    var name: String
    var symbol: String
    var color: GlyphColor

    var id: String { key }
    var isCustom: Bool { key.hasPrefix("custom:") }
    var customId: String? { isCustom ? String(key.dropFirst("custom:".count)) : nil }
}

enum RoomKind: String, Codable, Sendable {
    case hall = "HALL"
    case `public` = "PUBLIC"
    case `private` = "PRIVATE"
}

/// The look of a room. Every theme shares the same desks; only the scenery around them changes.
enum RoomTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic = "classic"
    case coffeeShop = "coffee_shop"
    case forest = "forest"
    case space = "space"
    case beach = "beach"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: String(localized: "Kütüphane")
        case .coffeeShop: String(localized: "Gece Kafesi")
        case .forest: String(localized: "Orman")
        case .space: String(localized: "Uzay Mekiği")
        case .beach: String(localized: "Sahil")
        }
    }

    var subtitle: String {
        switch self {
        case .classic: String(localized: "Kitaplıklar, ahşap parke, sessiz salon")
        case .coffeeShop: String(localized: "Tuğla duvar, neon tabela, espresso barı")
        case .forest: String(localized: "Ağaçlar, toprak patika, kamp ateşi")
        case .space: String(localized: "Lombozlardan yıldızlar, konsollar")
        case .beach: String(localized: "Deniz, kumsal, palmiyeler ve şemsiyeler")
        }
    }
}

/// A room as listed and as entered: identity plus live counts.
struct RoomState: Codable, Hashable, Sendable, Identifiable {
    var id: String
    var kind: RoomKind
    var name: String
    var symbol: String
    var color: GlyphColor
    var theme: String?
    /// What the room is for; set by its owner.
    var description: String?
    var code: String?
    var ownerId: String?
    var capacity: Int
    var occupiedCount: Int
    var presenceCount: Int

    var roomTheme: RoomTheme { RoomTheme(rawValue: theme ?? "") ?? .classic }
}

/// Someone at a desk, as shown on a room's preview card.
struct RoomOccupant: Decodable, Hashable, Sendable {
    var deskId: String
    /// Missing from servers older than room previews.
    var userId: String?
    var userName: String
    var avatarSpriteId: String
    var resting: Bool
}

/// A room in the lists: identity, live counts and who sits where.
struct RoomSummary: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var kind: RoomKind
    var name: String
    var symbol: String
    var color: GlyphColor
    var theme: String?
    /// What the room is for; set by its owner.
    var description: String?
    var code: String?
    var ownerId: String?
    var capacity: Int
    var occupiedCount: Int
    var presenceCount: Int
    var occupants: [RoomOccupant]

    var roomTheme: RoomTheme { RoomTheme(rawValue: theme ?? "") ?? .classic }
}

struct RoomsOverview: Decodable, Sendable {
    var layout: LibraryLayout
    /// Floor plans by theme; missing from servers older than room themes.
    var layouts: [String: LibraryLayout]?
    var myRooms: [RoomSummary]
    var seatedRoomId: String?
    /// People at a desk in halls and public rooms right now.
    var focusingNow: Int
}

/// A public room in Keşfet: live state plus last week's activity and its ranking score.
struct DiscoverRoom: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var name: String
    var symbol: String
    var color: GlyphColor
    var capacity: Int
    var occupiedCount: Int
    var presenceCount: Int
    var occupants: [RoomOccupant]
    var weeklyFocusMs: Int64
    var weeklyReaders: Int
    var memberCount: Int
    /// The category most focused on here this week.
    var topic: FocusCategory?
    var createdAt: Int64
    var score: Double
    var theme: String?
    var description: String?

    var summary: RoomSummary {
        RoomSummary(
            id: id, kind: .public, name: name, symbol: symbol, color: color, theme: theme, description: description,
            code: nil, ownerId: nil,
            capacity: capacity, occupiedCount: occupiedCount, presenceCount: presenceCount, occupants: occupants
        )
    }
}

struct DiscoverResult: Decodable, Sendable {
    struct Halls: Decodable, Sendable {
        var occupiedCount: Int
        var presenceCount: Int
    }

    var layout: LibraryLayout
    /// Floor plans by theme; missing from servers older than room themes.
    var layouts: [String: LibraryLayout]?
    var seatedRoomId: String?
    var halls: Halls
    /// Best first.
    var rooms: [DiscoverRoom]
}

extension LibraryLayout {
    /// The floor plan for a room's theme, falling back to `fallback` when the server sent none for it.
    static func forTheme(_ theme: String?, in layouts: [String: LibraryLayout]?, fallback: LibraryLayout) -> LibraryLayout {
        theme.flatMap { layouts?[$0] } ?? fallback
    }
}

/// A public room as shown before joining it.
struct RoomPreviewResult: Decodable, Sendable {
    var layout: LibraryLayout
    var room: DiscoverRoom
    var owner: PublicUser?
    var isMember: Bool
    var isSeatedHere: Bool
}

struct DeskRecord: Codable, Hashable, Sendable, Identifiable {
    var deskId: String
    var tileX: Int
    var tileY: Int
    var userId: String
    var userName: String
    var avatarSpriteId: String
    var category: FocusCategory
    var note: String?
    var timer: DeskTimer
    var startedAt: Int64
    var sessionNumber: Int
    var leaseExpiresAt: Int64

    var id: String { deskId }
    var number: Int { deskNumber(deskId) }

    /// Minutes on the overhead badge: total focus while working, time on break while resting.
    func badgeMinutes(at serverNow: Int64) -> Int {
        let reading = timer.reading(at: serverNow)
        let elapsed = reading.phase == .focus ? reading.focusedMs : max(0, serverNow - reading.phaseStartedAt)
        return Int(elapsed / 60_000)
    }
}

struct LayoutDesk: Codable, Hashable, Sendable, Identifiable {
    var deskId: String
    var tileX: Int
    var tileY: Int

    var id: String { deskId }
    var number: Int { deskNumber(deskId) }
}

/// `desk_0` is shown to people as "Masa 1".
private func deskNumber(_ deskId: String) -> Int {
    Int(deskId.drop(while: { !$0.isNumber })).map { $0 + 1 } ?? 0
}

struct LayoutProp: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case window, clock, bookshelf, plant, coffeeMachine, rug, door
        case neonSign, chalkboard, coffeeBar
        case path, tree, bush, flowers, mushroom, campfire, stump, pond
        case walkway, porthole, viewscreen, console, crate, hologram, airlock
        case boardwalk, palm, umbrella, towel, sandcastle, shell, surfboard
        case unknown

        /// Drawn flat on the ground beneath everything else.
        var isGroundCover: Bool {
            switch self {
            case .rug, .path, .walkway, .boardwalk: true
            default: false
            }
        }

        init(from decoder: any Decoder) throws {
            self = Kind(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .unknown
        }
    }

    var kind: Kind
    var tileX: Int
    var tileY: Int
    var width: Int
    var height: Int
}

struct LibraryLayout: Codable, Hashable, Sendable {
    var version: Int
    var theme: String?
    var width: Int
    var height: Int
    var wallHeight: Int
    var desks: [LayoutDesk]
    var props: [LayoutProp]

    var roomTheme: RoomTheme { RoomTheme(rawValue: theme ?? "") ?? .classic }
}

struct RoomSnapshot: Decodable, Sendable {
    var room: RoomState
    var layout: LibraryLayout
    var desks: [DeskRecord]
    var serverTime: Int64
}

struct CategoryTotal: Decodable, Hashable, Sendable, Identifiable {
    var key: String
    var name: String
    var symbol: String
    var color: GlyphColor
    var ms: Int64

    var id: String { key }
}

struct DayTotal: Decodable, Hashable, Sendable, Identifiable {
    /// `YYYY-MM-DD` in the reader's time zone.
    var date: String
    var totalMs: Int64
    var byCategory: [CategoryTotal]

    var id: String { date }
}

struct StatsSummary: Decodable, Hashable, Sendable {
    var todayMs: Int64
    var weekMs: Int64
    var totalMs: Int64
    var sessionCount: Int
    var streakDays: Int
    var last7Days: [DayTotal]
    var categories: [CategoryTotal]
    /// Missing from servers older than badges.
    var badges: [Badge]?
    /// Days with recorded focus; missing from older servers, which always count as unlocked.
    var activeDays: Int?
    var requiredDays: Int?

    /// Charts only mean something after focusing on a couple of separate days.
    var isUnlocked: Bool { (activeDays ?? .max) >= (requiredDays ?? 0) }
}

struct HistoryEntry: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    /// Missing from servers older than the localization release.
    var roomId: String?
    var roomName: String
    var mode: TimerMode
    var category: FocusCategory
    var note: String?
    var startedAt: Int64
    var endedAt: Int64
    var focusedMs: Int64
}

/// Where a followed reader is focusing. Private rooms come without id or name.
struct FriendActivity: Decodable, Hashable, Sendable {
    var roomId: String?
    var roomName: String?
    var category: FocusCategory
    var resting: Bool
    var since: Int64
}

struct Friend: Decodable, Hashable, Sendable, Identifiable {
    var user: PublicUser
    var activity: FriendActivity?
    /// Nil when they hide their focus time.
    var weekFocusMs: Int64?

    var id: String { user.id }
}

struct LeaderboardRow: Decodable, Hashable, Sendable, Identifiable {
    var user: PublicUser
    var weekFocusMs: Int64
    var isSelf: Bool

    var id: String { user.id }
}

struct FriendsOverview: Decodable, Sendable {
    var friends: [Friend]
    var leaderboard: [LeaderboardRow]
}

/// A session the owner scheduled in a room.
struct RoomEventItem: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var roomId: String
    var title: String
    var startsAt: Int64
    var durationMinutes: Int
    var goingCount: Int
    var isGoing: Bool

    var start: Date { Date(timeIntervalSince1970: Double(startsAt) / 1000) }
    var end: Date { start.addingTimeInterval(Double(durationMinutes) * 60) }
    func isLive(at now: Date) -> Bool { start <= now && now < end }
}

/// A milestone; unknown ids from newer servers are skipped.
struct Badge: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var progress: Double
    var earned: Bool
}

/// A to-do on the reader's own list.
struct FocusTask: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    var title: String
    var createdAt: Int64
    var completedAt: Int64?

    var isDone: Bool { completedAt != nil }
}

/// A line in a room's chat.
struct ChatMessage: Decodable, Hashable, Sendable, Identifiable {
    var id: String
    /// Chosen by the sending device; matches an optimistic local copy to the server's.
    var clientId: String
    var roomId: String
    var user: PublicUser
    var body: String
    var createdAt: Int64
}

struct ChatPage: Decodable, Sendable {
    /// Oldest first.
    var messages: [ChatMessage]
    var hasMore: Bool
}

/// Room changes pushed by the server without being asked. Every one names its room.
enum LibraryEvent: Sendable {
    case deskOccupied(roomId: String, desk: DeskRecord)
    case deskUpdated(roomId: String, desk: DeskRecord)
    case deskVacated(roomId: String, deskId: String, userId: String)
    case presence(roomId: String, presenceCount: Int, occupiedCount: Int)
    case roomClosed(roomId: String)
    /// The owner renamed the room or changed its icon or visibility.
    case roomUpdated(room: RoomState)
    /// The owner removed `userId` from the room.
    case memberRemoved(roomId: String, userId: String)
    case chatMessage(ChatMessage)
    case chatDeleted(roomId: String, messageId: String)
    case chatTyping(roomId: String, user: PublicUser)
    /// Someone the reader follows sat down at a desk in `roomId`.
    case friendStarted(roomId: String, desk: DeskRecord)
    /// A room's scheduled events changed; reload them.
    case roomEventsChanged(roomId: String)
    /// Someone left a reaction on the desk `deskId`, which `ownerId` holds.
    case deskReaction(roomId: String, deskId: String, ownerId: String, reaction: DeskReaction, from: FeedActor)
}

/// Silent encouragement left on someone's desk.
enum DeskReaction: String, Codable, CaseIterable, Identifiable, Sendable {
    case clap = "CLAP"
    case coffee = "COFFEE"
    case fire = "FIRE"
    case strong = "STRONG"
    case star = "STAR"

    var id: String { rawValue }

    var emoji: String {
        switch self {
        case .clap: "👏"
        case .coffee: "☕️"
        case .fire: "🔥"
        case .strong: "💪"
        case .star: "⭐️"
        }
    }
}

/// Who did something in the feed or left a reaction.
struct FeedActor: Decodable, Hashable, Sendable {
    var id: String
    var displayName: String
    var avatarSpriteId: String
}

/// Something that just happened in a hall or public room.
struct FeedItem: Decodable, Hashable, Sendable, Identifiable {
    enum Kind: String, Decodable, Sendable {
        case started = "STARTED"
        case finished = "FINISHED"
    }

    var id: String
    var kind: Kind
    var user: FeedActor
    var category: FocusCategory
    var roomId: String
    var roomName: String
    var minutes: Int?
    var at: Int64
}

/// Why a reader or a message is reported.
enum ReportReason: String, Codable, CaseIterable, Identifiable, Sendable {
    case spam = "SPAM"
    case harassment = "HARASSMENT"
    case hate = "HATE"
    case sexual = "SEXUAL"
    case selfHarm = "SELF_HARM"
    case other = "OTHER"

    var id: String { rawValue }
}
