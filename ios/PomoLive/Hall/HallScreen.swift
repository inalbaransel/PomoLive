import SwiftUI

/// The main screen: the pixel hall full-bleed, navigation chrome in the toolbar, the focus deck at the bottom.
struct HallScreen: View {
    @Environment(AppModel.self) private var app
    @State private var camera = MapCamera()
    @State private var selectedDeskId: String?
    @State private var deskToSit: LayoutDesk?
    @State private var activeSheet: ActiveSheet?
    @State private var isDeckExpanded = true

    private enum ActiveSheet: String, Identifiable {
        case hallSwitcher, profile
        var id: String { rawValue }
    }

    var body: some View {
        @Bindable var hall = app.hall

        NavigationStack {
            content
                .navigationTitle(hall.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .sheet(item: $deskToSit) { desk in
                    SitDownSheet(desk: desk) { label in
                        await hall.sit(at: desk, taskLabel: label)
                        focusOnMyDesk()
                    }
                    .presentationDetents([.medium])
                }
                .sheet(item: $activeSheet) { sheet in
                    switch sheet {
                    case .hallSwitcher:
                        HallSwitcherSheet(
                            room: hall.room,
                            onJoin: { await hall.switchHall(code: $0) },
                            onCreate: { await hall.createPrivateHall() },
                            onReturnToPublic: { await hall.returnToPublicHall() }
                        )
                        .presentationDetents([.medium, .large])
                    case .profile:
                        if let user = app.user {
                            ProfileSheet(user: user, onSave: app.updateProfile, onSignOut: app.signOut)
                        }
                    }
                }
                .errorAlert($hall.error)
        }
    }

    @ViewBuilder
    private var content: some View {
        let hall = app.hall
        if let layout = hall.layout {
            PixelLibraryCanvasView(
                layout: layout,
                desks: hall.desks,
                myUserId: app.user?.id,
                clock: hall.clock,
                camera: camera,
                selectedDeskId: $selectedDeskId,
                onEmptyDeskTap: { deskToSit = $0 }
            )
            .ignoresSafeArea()
            .safeAreaBar(edge: .top, alignment: .trailing) {
                MiniMapView(layout: layout, desks: hall.desks, myUserId: app.user?.id, camera: camera)
                    .padding(.trailing, 16)
            }
            .safeAreaBar(edge: .bottom) {
                if let desk = hall.myDesk {
                    FocusDeckView(
                        desk: desk,
                        cycle: hall.cycle,
                        clock: hall.clock,
                        isExpanded: $isDeckExpanded,
                        onToggleBreak: { Task { await hall.toggleBreak() } },
                        onStand: { Task { await hall.stand() } }
                    )
                    .transition(.move(edge: .bottom).combined(with: .blurReplace))
                }
            }
            .animation(.spring(duration: 0.55, bounce: 0.25), value: hall.myDesk?.deskId)
        } else if app.connection == .offline {
            ContentUnavailableView {
                Label("Bağlantı yok", systemImage: "wifi.slash")
            } description: {
                Text("Salona bağlanılamadı. Tekrar deneniyor.")
            } actions: {
                Button("Şimdi Dene") { app.ensureConnected() }
                    .buttonStyle(.glass)
            }
        } else {
            ProgressView("Salona giriliyor…")
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        // The map is not a scroll view, so the title gets its own glass to stay legible over the pixels.
        ToolbarItem(placement: .principal) {
            VStack(spacing: 1) {
                Text(app.hall.title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
            .glassEffect(.regular, in: .capsule)
            .animation(.smooth, value: subtitle)
        }
        ToolbarItem(placement: .topBarLeading) {
            Button("Masama Git", systemImage: "scope", action: focusOnMyDesk)
                .disabled(app.hall.myDesk == nil)
        }
        if let code = app.hall.room?.code, app.hall.room?.type == .private {
            ToolbarItem(placement: .topBarTrailing) {
                ShareLink(
                    item: "PomoLive'da benimle çalış! Özel salon kodu: \(code)",
                    subject: Text("PomoLive salon kodu")
                ) {
                    Label("Kodu Paylaş", systemImage: "square.and.arrow.up")
                }
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Diğer", systemImage: "ellipsis") {
                if let code = app.hall.room?.code, app.hall.room?.type == .private {
                    Text("Salon kodu: \(code)")
                }
                Button("Salon Değiştir", systemImage: "door.left.hand.open") { activeSheet = .hallSwitcher }
                Button("Profil", systemImage: "person.crop.circle") { activeSheet = .profile }
            }
        }
    }

    private var subtitle: String {
        switch app.connection {
        case .online:
            guard let room = app.hall.room else { return "" }
            return "\(room.presenceCount) kişi · \(room.occupiedCount)/\(room.capacity) masa dolu"
        case .connecting: return "Bağlanıyor…"
        case .offline: return "Çevrimdışı"
        }
    }

    private func focusOnMyDesk() {
        guard let desk = app.hall.myDesk else { return }
        isDeckExpanded = true
        withAnimation(.spring(duration: 0.7, bounce: 0.22)) {
            camera.focus(onTile: CGPoint(x: desk.tileX + 1, y: desk.tileY + 1), zoom: max(camera.zoom, 3))
        }
    }
}
