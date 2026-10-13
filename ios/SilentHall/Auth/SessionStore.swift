import Foundation
import Security

/// Persists the server session (token in the Keychain, profile in defaults) so launches can go straight into the hall.
struct SessionStore {
    private static let service = "com.baransel.silenthall.session"
    private static let account = "sessionToken"
    private static let profileKey = "cachedUserProfile"

    var token: String? {
        var result: CFTypeRef?
        let status = SecItemCopyMatching(Self.query.merging([
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]) { $1 } as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data else { return nil }
        return String(decoding: data, as: UTF8.self)
    }

    var profile: UserProfile? {
        UserDefaults.standard.data(forKey: Self.profileKey).flatMap { try? JSONDecoder().decode(UserProfile.self, from: $0) }
    }

    func save(token: String, profile: UserProfile) {
        SecItemDelete(Self.query as CFDictionary)
        SecItemAdd(Self.query.merging([
            kSecValueData as String: Data(token.utf8),
            kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly,
        ]) { $1 } as CFDictionary, nil)
        save(profile: profile)
    }

    func save(profile: UserProfile) {
        UserDefaults.standard.set(try? JSONEncoder().encode(profile), forKey: Self.profileKey)
    }

    func clear() {
        SecItemDelete(Self.query as CFDictionary)
        UserDefaults.standard.removeObject(forKey: Self.profileKey)
    }

    private static var query: [String: Any] {
        [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecAttrAccount as String: account,
        ]
    }
}
