import CryptoKit
import Foundation

/// Replay protection for Sign in with Apple: Apple embeds `hashed` in the identity token,
/// the server receives `raw` and checks that they match.
struct AppleSignInNonce {
    let raw: String

    init() {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        raw = bytes.map { String(format: "%02x", $0) }.joined()
    }

    var hashed: String {
        SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }
}
