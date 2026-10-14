import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            switch app.phase {
            case .signedOut: SignInView()
            case .signedIn: MainTabView()
            }
        }
        .animation(.smooth, value: app.phase)
    }
}
