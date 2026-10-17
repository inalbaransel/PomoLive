import UIKit

/// Owns the app model so system callbacks that only reach the delegate, like the APNs device
/// token, can be handed to it.
final class AppDelegate: NSObject, UIApplicationDelegate {
    let model = AppModel()

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        model.push.didRegister(deviceToken: deviceToken)
    }
}
