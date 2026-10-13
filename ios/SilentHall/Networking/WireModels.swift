import Foundation

// Mirrors the server's wire contract (`server/src/realtime/protocol.ts`, `library.types.ts`).
// Timestamps are milliseconds since the Unix epoch on the server's clock; convert with `ServerClock`.

struct UserProfile: Codable, Hashable, Sendable {
    var id: String
    var displayName: String
    var avatarSpriteId: String
}

enum DeskStatus: String, Codable, Sendable {
    case focus = "FOCUS"
    case onBreak = "BREAK"
}

enum CyclePhase: String, Codable, Sendable {
    case focus = "FOCUS"
    case rest = "BREAK"
}

enum HallType: String, Codable, Sendable {
    case `public` = "PUBLIC"
    case `private` = "PRIVATE"
}

struct DeskRecord: Codable, Hashable, Sendable, Identifiable {
    var deskId: String
    var tileX: Int
    var tileY: Int
    var userId: String
    var userName: String
    var avatarSpriteId: String
    var taskLabel: String
    var status: DeskStatus
    var startedAt: Int64
    var statusSince: Int64
    var focusAccumulatedMs: Int64
    var sessionNumber: Int
    var leaseExpiresAt: Int64

    var id: String { deskId }
    var number: Int { deskNumber(deskId) }

    func focusedMs(at serverNow: Int64) -> Int64 {
        focusAccumulatedMs + (status == .focus ? max(0, serverNow - statusSince) : 0)
    }

    /// Minutes shown on the overhead badge: focus time while working, time on break while resting.
    func badgeMinutes(at serverNow: Int64) -> Int {
        let elapsed = status == .focus ? focusedMs(at: serverNow) : max(0, serverNow - statusSince)
        return Int(elapsed / 60_000)
    }
}

/// `desk_0` is shown to people as "Masa 1".
private func deskNumber(_ deskId: String) -> Int {
    Int(deskId.drop(while: { !$0.isNumber })).map { $0 + 1 } ?? 0
}

struct RoomState: Codable, Hashable, Sendable {
    var id: String
    var type: HallType
    var code: String?
    var capacity: Int
    var occupiedCount: Int
    var presenceCount: Int
    var focusMinutes: Int
    var breakMinutes: Int
    var cycleAnchorAt: Int64
}

struct LayoutDesk: Codable, Hashable, Sendable, Identifiable {
    var deskId: String
    var tileX: Int
    var tileY: Int

    var id: String { deskId }
    var number: Int { deskNumber(deskId) }
}

struct LayoutProp: Codable, Hashable, Sendable {
    enum Kind: String, Codable, Sendable {
        case window, clock, bookshelf, plant, coffeeMachine, rug, door, unknown

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
    var width: Int
    var height: Int
    var wallHeight: Int
    var desks: [LayoutDesk]
    var props: [LayoutProp]
}

struct RoomSnapshot: Decodable, Sendable {
    var room: RoomState
    var layout: LibraryLayout
    var desks: [DeskRecord]
    var serverTime: Int64
}

/// Room changes pushed by the server without being asked.
enum LibraryEvent: Sendable {
    case deskOccupied(DeskRecord)
    case deskUpdated(DeskRecord)
    case deskVacated(deskId: String, userId: String)
    case presence(presenceCount: Int, occupiedCount: Int)
}
