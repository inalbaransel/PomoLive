import SwiftUI

/// The signed-in app: Odalar, İstatistik and Profil, with the running session pinned above the tab bar.
struct MainTabView: View {
    enum Tab: Hashable {
        case rooms, stats, profile
    }

    @Environment(AppModel.self) private var app
    @State private var selection: Tab = .rooms
    @State private var openRoom: RoomRoute?
    @AppStorage(Preferences.hasSeenOnboarding) private var hasSeenOnboarding = false
    /// Opened once the onboarding sheet has finished dismissing.
    @State private var sitsDownAfterOnboarding = false

    var body: some View {
        TabView(selection: $selection) {
            SwiftUI.Tab("Odalar", systemImage: "books.vertical.fill", value: .rooms) {
                RoomsView(openRoom: { openRoom = RoomRoute(target: $0) })
            }
            SwiftUI.Tab("İstatistik", systemImage: "chart.bar.fill", value: .stats) {
                StatsView()
            }
            SwiftUI.Tab("Profil", systemImage: "person.crop.circle.fill", value: .profile) {
                ProfileView()
            }
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        .tabViewBottomAccessory(isEnabled: app.seat.desk != nil) {
            SeatAccessoryView { openRoom = RoomRoute(target: .automatic) }
        }
        // Widgets link here to bring the reader back to their desk.
        .onOpenURL { url in
            guard url.scheme == "pomolive", url.host() == "desk" else { return }
            selection = .rooms
            openRoom = RoomRoute(target: .automatic)
        }
        .sheet(isPresented: Binding(get: { !hasSeenOnboarding }, set: { if !$0 { hasSeenOnboarding = true } }), onDismiss: {
            if sitsDownAfterOnboarding { openRoom = RoomRoute(target: .automatic) }
        }) {
            OnboardingView { sitsDown in
                sitsDownAfterOnboarding = sitsDown
                hasSeenOnboarding = true
            }
            .presentationDetents([.large])
        }
        .onChange(of: app.push.pendingRoute) { _, route in
            if route == .friends { selection = .rooms }
        }
        .fullScreenCover(item: $openRoom, onDismiss: refreshAfterRoom) { route in
            HallScreen(target: route.target)
        }
        .errorAlert(Bindable(app.seat).error)
    }

    /// Counts, "Odalarım" and today's minutes may all have changed while the room was open.
    private func refreshAfterRoom() {
        Task {
            async let rooms: Void = app.rooms.refresh()
            async let stats: Void = app.stats.refresh()
            _ = await (rooms, stats)
        }
    }
}

/// A request to show a room full-screen.
struct RoomRoute: Identifiable {
    let id = UUID()
    let target: HallStore.Target
}
