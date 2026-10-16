import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app
    @AppStorage(Preferences.appearance) private var appearance = Appearance.system

    var body: some View {
        Group {
            switch app.phase {
            case .signedOut: SignInView()
            case .signedIn: MainTabView()
            }
        }
        .animation(.smooth, value: app.phase)
        .preferredColorScheme(appearance.colorScheme)
        .environment(\.locale, .app)
    }
}
