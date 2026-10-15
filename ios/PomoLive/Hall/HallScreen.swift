import SwiftUI

/// Inside a room: the pixel hall full-bleed, navigation chrome in the toolbar, the focus deck at the bottom.
/// Closing the screen only stops looking at the room; a desk taken here keeps running.
struct HallScreen: View {
    let target: HallStore.Target

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var camera = MapCamera()
    @State private var selectedDeskId: String?
    @State private var deskToSit: LayoutDesk?
    @State private var isDeckExpanded = true
    @State private var confirmsDelete = false
    @State private var entryError: LibraryError?

    var body: some View {
        @Bindable var hall = app.hall

        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .sheet(item: $deskToSit) { desk in
                    SessionSetupSheet(desk: desk) { timer, category, note in
                        let didSit = await hall.sit(at: desk, timer: timer, categoryKey: category.key, note: note)
                        if didSit { focusOnMyDesk() }
                        return didSit
                    }
                    .presentationDetents([.large])
                }
                .confirmationDialog("Oda silinsin mi?", isPresented: $confirmsDelete, titleVisibility: .visible) {
                    Button("Odayı Sil", role: .destructive) {
                        Task {
                            await hall.deleteRoom()
                            dismiss()
                        }
                    }
                } message: {
                    Text("İçerideki herkesin oturumu biter ve oda listeden kalkar.")
                }
                .errorAlert($hall.error)
                .alert("Odaya girilemedi", isPresented: Binding(get: { entryError != nil }, set: { if !$0 { dismiss() } })) {
                    Button("Tamam", role: .cancel) {}
                } message: {
                    Text(entryError?.errorDescription ?? "")
                }
        }
        .task {
            do {
                try await app.hall.enter(target)
            } catch {
                entryError = LibraryError(error)
            }
        }
        .onChange(of: app.hall.wasClosed) { _, wasClosed in
            if wasClosed { dismiss() }
        }
        .onDisappear {
            let visit = app.hall.visit
            Task { await app.hall.leave(visit: visit) }
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
                clock: app.time.clock,
                camera: camera,
                selectedDeskId: $selectedDeskId,
                onEmptyDeskTap: { deskToSit = $0 }
            )
            .ignoresSafeArea()
            .safeAreaBar(edge: .top, alignment: .trailing) {
                MiniMapView(layout: layout, desks: hall.desks, myUserId: app.user?.id, camera: camera, clock: app.time.clock)
                    .padding(.trailing, 16)
            }
            .safeAreaBar(edge: .bottom) {
                if let desk = hall.myDesk {
                    FocusDeckView(
                        desk: desk,
                        clock: app.time.clock,
                        isExpanded: $isDeckExpanded,
                        onChangeTimer: { action in Task { await app.seat.changeTimer(action) } },
                        onFinish: { Task { await app.seat.stand() } }
                    )
                    .transition(.move(edge: .bottom).combined(with: .blurReplace))
                }
            }
            .animation(.spring(duration: 0.55, bounce: 0.25), value: hall.myDesk?.deskId)
        } else {
            ProgressView("Odaya giriliyor…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
        }
        // The map is not a scroll view, so the title gets its own glass to stay legible over the pixels.
        ToolbarItem(placement: .principal) {
            if let room = app.hall.room {
                VStack(spacing: 1) {
                    Label {
                        Text(room.name)
                    } icon: {
                        Image(systemName: room.symbol)
                            .foregroundStyle(room.color.color)
                    }
                    .font(.headline)
                    .lineLimit(1)
                    Text(subtitle(for: room))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .contentTransition(.numericText())
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 6)
                .glassEffect(.regular, in: .capsule)
                .animation(.smooth, value: subtitle(for: room))
            }
        }
        ToolbarItem(placement: .topBarTrailing) {
            Button("Masama Git", systemImage: "scope", action: focusOnMyDesk)
                .disabled(app.hall.myDesk == nil)
        }
        ToolbarItem(placement: .topBarTrailing) {
            Menu("Diğer", systemImage: "ellipsis") {
                if let room = app.hall.room, let code = room.code {
                    ShareLink(
                        item: "PomoLive'da \(room.name) odasına gel! Oda kodu: \(code)",
                        subject: Text("PomoLive oda kodu")
                    ) {
                        Label("Kodu Paylaş · \(code)", systemImage: "square.and.arrow.up")
                    }
                }
                if app.hall.isOwner {
                    Button("Odayı Sil", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                }
            }
            .disabled(app.hall.room?.code == nil && !app.hall.isOwner)
        }
    }

    private func subtitle(for room: RoomState) -> String {
        switch app.connection {
        case .online: "\(room.presenceCount) kişi · \(room.occupiedCount)/\(room.capacity) masa dolu"
        case .connecting: "Bağlanıyor…"
        case .offline: "Çevrimdışı"
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
