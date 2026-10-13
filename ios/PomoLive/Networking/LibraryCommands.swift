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
        case apple(identityToken: String, rawNonce: String, displayName: String?)
        case google(identityToken: String, rawNonce: String)
        case email(address: String, code: String)
        case session(token: String)
    }

    var credential: Credential
    var timeZone = TimeZone.current.identifier

    private enum CodingKeys: String, CodingKey {
        case method, identityToken, rawNonce, displayName, email, code, sessionToken, timeZone
    }

    func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(timeZone, forKey: .timeZone)
        switch credential {
        case .apple(let identityToken, let rawNonce, let displayName):
            try container.encode("apple", forKey: .method)
            try container.encode(identityToken, forKey: .identityToken)
            try container.encode(rawNonce, forKey: .rawNonce)
            try container.encodeIfPresent(displayName, forKey: .displayName)
        case .google(let identityToken, let rawNonce):
            try container.encode("google", forKey: .method)
            try container.encode(identityToken, forKey: .identityToken)
            try container.encode(rawNonce, forKey: .rawNonce)
        case .email(let address, let code):
            try container.encode("email", forKey: .method)
            try container.encode(address, forKey: .email)
            try container.encode(code, forKey: .code)
        case .session(let token):
            try container.encode("session", forKey: .method)
            try container.encode(token, forKey: .sessionToken)
        }
    }
}

struct EmailCodeResult: Decodable, Sendable {
    var resendAfterSeconds: Int
}

/// Sent before authentication: mails a 6-digit sign-in code to `email`.
struct RequestEmailCodeCommand: LibraryCommand {
    typealias Result = EmailCodeResult
    static let event = "auth:email-code"
    var email: String
}

struct JoinHallCommand: LibraryCommand {
    typealias Result = RoomSnapshot
    static let event = "room:join"
    var code: String?
}

struct CreateHallCommand: LibraryCommand {
    typealias Result = RoomSnapshot
    static let event = "room:create"
}

struct LeaveHallCommand: LibraryCommand {
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
    var taskLabel: String
}

struct StandCommand: LibraryCommand {
    typealias Result = NoResult
    static let event = "desk:stand"
}

struct SetStatusCommand: LibraryCommand {
    typealias Result = DeskResult
    static let event = "desk:status"
    var status: DeskStatus
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
