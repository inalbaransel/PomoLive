import SwiftUI

/// Inside a room: the pixel hall full-bleed, navigation chrome in the toolbar, the focus deck at the bottom.
/// Closing the screen only stops looking at the room; a desk taken here keeps running.
struct HallScreen: View {
    let target: HallStore.Target

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var camera = MapCamera()
    @State private var selectedDeskId: String?
    @State private var sheet: Sheet?
    @State private var isDeckExpanded = true
    @State private var confirmsDelete = false
    @State private var wasRemoved = false
    @State private var entryError: LibraryError?
    @State private var showsMiniMap = true
    @State private var showsChatToast = false
    @State private var cameraTrigger = 0

    private enum Sheet: Identifiable {
        case sit(LayoutDesk)
        case people
        case profile(userId: String)
        case editRoom(RoomState)

        var id: String {
            switch self {
            case .sit(let desk): "sit-\(desk.deskId)"
            case .people: "people"
            case .profile(let userId): "profile-\(userId)"
            case .editRoom: "edit"
            }
        }
    }

    var body: some View {
        @Bindable var hall = app.hall

        NavigationStack {
            content
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbar }
                .sheet(item: $sheet, onDismiss: { selectedDeskId = nil }) { sheet in
                    switch sheet {
                    case .sit(let desk):
                        SessionSetupSheet(desk: desk) { timer, category, note in
                            let didSit = await hall.sit(at: desk, timer: timer, categoryKey: category.key, note: note)
                            if didSit { focusOnMyDesk() }
                            return didSit
                        }
                        .presentationDetents([.large])
                    case .people:
                        RoomPeopleSheet()
                            .presentationDetents([.medium, .large])
                    case .profile(let userId):
                        NavigationStack {
                            UserProfileView(userId: userId)
                                .toolbar {
                                    ToolbarItem(placement: .topBarLeading) {
                                        Button("Kapat", systemImage: "xmark", role: .close) { self.sheet = nil }
                                    }
                                }
                        }
                        .presentationDetents([.medium, .large])
                    case .editRoom(let room):
                        RoomEditorSheet(room: room) { draft in
                            try await hall.update(name: draft.name, symbol: draft.symbol, color: draft.color, visibility: draft.visibility, theme: draft.theme)
                        }
                    }
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
                .alert("Odadan çıkarıldın", isPresented: $wasRemoved) {
                    Button("Tamam", role: .cancel) { dismiss() }
                } message: {
                    Text("Oda sahibi seni bu odadan çıkardı. Masan boşaltıldı, odak süren geçmişine kaydedildi.")
                }
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
        .task(id: showsChatToast) {
            if showsChatToast {
                try? await Task.sleep(for: .seconds(2.5))
                withAnimation(.easeOut(duration: 0.3)) {
                    showsChatToast = false
                }
            }
        }
        .onChange(of: app.hall.exit) { _, exit in
            switch exit {
            case .closed: dismiss()
            case .removed:
                sheet = nil
                wasRemoved = true
            case nil: break
            }
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
                onEmptyDeskTap: { sheet = .sit($0) },
                onOccupiedDeskTap: { desk in
                    if desk.userId == app.user?.id {
                        isDeckExpanded = true
                    } else {
                        sheet = .profile(userId: desk.userId)
                    }
                }
            )
            .ignoresSafeArea()
            .safeAreaBar(edge: .top, alignment: .trailing) {
                if showsMiniMap {
                    MiniMapView(layout: layout, desks: hall.desks, myUserId: app.user?.id, camera: camera, clock: app.time.clock)
                        .padding(.trailing, 16)
                        .transition(.scale(scale: 0.85).combined(with: .opacity))
                }
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
            .overlay(alignment: .bottomTrailing) {
                floatingControls
                    .padding(.trailing, 16)
                    .padding(.bottom, bottomControlsPadding)
                    .animation(.spring(duration: 0.45, bounce: 0.12), value: isDeckExpanded)
                    .animation(.spring(duration: 0.55, bounce: 0.25), value: hall.myDesk?.deskId)
            }
            .overlay(alignment: .top) {
                chatToastView
                    .padding(.top, 8)
            }
            .animation(.spring(duration: 0.55, bounce: 0.25), value: hall.myDesk?.deskId)
        } else {
            ProgressView("Odaya giriliyor…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    // MARK: - Floating Controls (Bottom Right)

    private var floatingControls: some View {
        VStack(spacing: 12) {
            // Chat button
            Button {
                withAnimation(.spring(duration: 0.35, bounce: 0.2)) {
                    showsChatToast = true
                }
            } label: {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 48, height: 48)
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .sensoryFeedback(.impact(weight: .light), trigger: showsChatToast)
            .accessibilityLabel("Sohbet")

            // Camera recenter / focus on desk button
            Button {
                handleCameraRecenter()
            } label: {
                Image(systemName: app.hall.myDesk != nil ? "scope" : "viewfinder")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(app.hall.myDesk != nil ? (app.hall.room?.color.color ?? .accentColor) : .primary)
                    .frame(width: 48, height: 48)
                    .contentTransition(.symbolEffect(.replace))
            }
            .buttonStyle(.plain)
            .glassEffect(.regular.interactive(), in: .circle)
            .sensoryFeedback(.impact(weight: .light), trigger: cameraTrigger)
            .accessibilityLabel(app.hall.myDesk != nil ? "Masama Odaklan" : "Salonu Ortala")
        }
    }

    private var bottomControlsPadding: CGFloat {
        if app.hall.myDesk != nil {
            return isDeckExpanded ? 330 : 110
        } else {
            return 50
        }
    }

    @ViewBuilder
    private var chatToastView: some View {
        if showsChatToast {
            HStack(spacing: 8) {
                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .foregroundStyle(app.hall.room?.color.color ?? .accentColor)
                Text("Sohbet çok yakında!")
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .glassEffect(.regular, in: .capsule)
            .shadow(color: .black.opacity(0.12), radius: 8, y: 4)
            .transition(.move(edge: .top).combined(with: .opacity))
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .topBarLeading) {
            Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
        }

        // Prominent, centered room pill: icon + name + live count. Tapping it opens room members & details.
        ToolbarItem(placement: .principal) {
            if let room = app.hall.room {
                Button { sheet = .people } label: {
                    roomHeader(for: room)
                }
                .buttonStyle(.plain)
                .accessibilityHint("Odadaki kişileri gösterir")
            }
        }

        ToolbarItem(placement: .topBarTrailing) {
            Menu("Diğer", systemImage: "ellipsis") {
                Toggle(isOn: $showsMiniMap.animation(.spring(duration: 0.4, bounce: 0.2))) {
                    Label("Mini Harita", systemImage: "map")
                }

                Button {
                    sheet = .people
                } label: {
                    Label("Odadaki Kişiler", systemImage: "person.2")
                }

                if let room = app.hall.room, let code = room.code {
                    ShareLink(
                        item: String(localized: "PomoLive'da \(room.displayName) odasına gel! Oda kodu: \(code)"),
                        subject: Text("PomoLive oda kodu")
                    ) {
                        Label("Kodu Paylaş · \(code)", systemImage: "square.and.arrow.up")
                    }
                }

                if app.hall.isOwner, let room = app.hall.room {
                    Divider()
                    Button("Odayı Düzenle", systemImage: "pencil") { sheet = .editRoom(room) }
                    Button("Odayı Sil", systemImage: "trash", role: .destructive) { confirmsDelete = true }
                }
            }
        }
    }

    private func roomHeader(for room: RoomState) -> some View {
        HStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(room.color.color.opacity(0.2))
                Image(systemName: room.symbol)
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(room.color.color)
            }
            .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(room.displayName)
                        .font(.headline)
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    Image(systemName: "chevron.down")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                HStack(spacing: 4) {
                    Circle()
                        .fill(app.connection == .online ? Color.green : Color.orange)
                        .frame(width: 5, height: 5)
                    Text(subtitle(for: room))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
        }
        .padding(.leading, 6)
        .padding(.trailing, 14)
        .padding(.vertical, 5)
        .glassEffect(.regular.interactive(), in: .capsule)
        .animation(.smooth, value: subtitle(for: room))
        .accessibilityLabel("\(room.displayName), \(subtitle(for: room))")
        .accessibilityHint("Odadaki kişileri ve detayları açar")
    }

    private func subtitle(for room: RoomState) -> String {
        switch app.connection {
        case .online: String(localized: "\(room.presenceCount) kişi · \(room.occupiedCount)/\(room.capacity) masa dolu")
        case .connecting: String(localized: "Bağlanıyor…")
        case .offline: String(localized: "Çevrimdışı")
        }
    }

    private func handleCameraRecenter() {
        cameraTrigger += 1
        if let desk = app.hall.myDesk {
            isDeckExpanded = true
            withAnimation(.spring(duration: 0.7, bounce: 0.22)) {
                camera.focus(onTile: CGPoint(x: desk.tileX + 1, y: desk.tileY + 1), zoom: max(camera.zoom, 3))
            }
        } else if let layout = app.hall.layout {
            withAnimation(.spring(duration: 0.7, bounce: 0.22)) {
                camera.focus(
                    onTile: CGPoint(x: CGFloat(layout.width) / 2, y: CGFloat(layout.height) / 2),
                    zoom: 1.4
                )
            }
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
