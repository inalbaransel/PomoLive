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
    var focusingOn: FocusCategory?
    var stats: StatsSummary?
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

/// Available room environments.
enum RoomTheme: String, Codable, CaseIterable, Identifiable, Sendable {
    case classic = "classic"
    case coffeeShop = "coffee_shop"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: String(localized: "Klasik Kütüphane")
        case .coffeeShop: String(localized: "Gece Kafesi")
        }
    }

    var subtitle: String {
        switch self {
        case .classic: String(localized: "Yeşil duvarlar, ahşap parkeler, sessiz salon")
        case .coffeeShop: String(localized: "Sıcak tuğla, espresso barı ve neon ışıklar")
        }
    }

    var symbol: String {
        switch self {
        case .classic: "books.vertical.fill"
        case .coffeeShop: "cup.and.saucer.fill"
        }
    }

    var description: String {
        switch self {
        case .classic: String(localized: "Geleneksel kütüphane atmosferi: kitaplıklar, saksı bitkileri ve klasik kırmızı halı.")
        case .coffeeShop: String(localized: "Sıcak bir kafe atmosferi: tuğla duvarlar, neon tabela, kahve barı ve lo-fi çalışma ortamı.")
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

    var summary: RoomSummary {
        RoomSummary(
            id: id, kind: .public, name: name, symbol: symbol, color: color, code: nil, ownerId: nil,
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
    var seatedRoomId: String?
    var halls: Halls
    /// Best first.
    var rooms: [DiscoverRoom]
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
        case unknown

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
}
