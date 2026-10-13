#if DEBUG
import Foundation

/// A stable per-install identifier for the server's developer sign-in (simulators without an Apple ID).
enum DeveloperIdentity {
    static var deviceId: String {
        let key = "developerDeviceId"
        if let existing = UserDefaults.standard.string(forKey: key) { return existing }
        let created = UUID().uuidString
        UserDefaults.standard.set(created, forKey: key)
        return created
    }
}
#endif
