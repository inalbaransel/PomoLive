import CryptoKit
import Foundation

/// Replay protection for Apple and Google sign-in: the provider embeds `hashed` in the ID token,
/// the server receives `raw` and checks that they match.
struct SignInNonce {
    let raw: String

    init() {
        raw = Self.randomHex(byteCount: 32)
    }

    var hashed: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    static func randomHex(byteCount: Int) -> String {
        var bytes = [UInt8](repeating: 0, count: byteCount)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return bytes.map { String(format: "%02x", $0) }.joined()
    }
}
