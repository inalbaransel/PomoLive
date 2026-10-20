import SwiftUI

/// The home tab, alive with whoever is focusing right now: a one-tap start in a hall, friends at
/// their desks, shelves of public rooms (busy now, popular this week, new), then the reader's own
/// rooms. Searching or picking a topic narrows everything to matching rooms.
struct RoomsView: View {
    let openRoom: (HallStore.Target) -> Void
    let openMatch: (MatchFound) -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.scenePhase) private var scenePhase
    @State private var sheet: Sheet?
    /// Opened once the sheet has finished dismissing, so two presentations never overlap.
    @State private var pendingRoom: HallStore.Target?
    @State private var pendingMatch: MatchFound?
    @State private var roomToDelete: RoomSummary?
    @State private var showsFriends = false
    @State private var showsPaywall = false
    @State private var query = ""
    @State private var topic: String?

    private enum Sheet: Identifiable {
        case create, joinByCode, studyBuddy, preview(roomId: String)

        var id: String {
            switch self {
            case .create: "create"
            case .joinByCode: "code"
            case .studyBuddy: "buddy"
            case .preview(let roomId): roomId
            }
        }
    }

    var body: some View {
        @Bindable var rooms = app.rooms

        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    if isNarrowed {
                        results
                    } else {
                        home
                    }
                }
                .padding(.vertical, 12)
                .animation(.smooth, value: isNarrowed)
                .animation(.smooth, value: topic)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Odalar")
            .navigationSubtitle(app.connection == .online ? greeting : String(localized: "Sunucuya bağlanılıyor…"))
            .searchable(text: $query, prompt: "Oda ara")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Oda", systemImage: "plus") {
                        Button("Oda Oluştur", systemImage: "plus.rectangle.on.rectangle", action: createRoom)
                        Button("Kodla Katıl", systemImage: "number") { sheet = .joinByCode }
                    }
                }
            }
            .plusPaywall(isPresented: $showsPaywall)
            .navigationDestination(isPresented: $showsFriends) {
                FriendsView(openRoom: openRoom)
            }
            // A tapped "started focusing" notification lands on the friends list.
            .onChange(of: app.push.pendingRoute, initial: true) { _, route in
                guard route == .friends else { return }
                app.push.pendingRoute = nil
                showsFriends = true
            }
            .refreshable { await refresh() }
            .task(id: app.connection == .online && scenePhase == .active) {
                // Live counts change while the tab is on screen; poll gently instead of streaming every
                // room, and not at all in the background or on other tabs.
                guard app.connection == .online, scenePhase == .active else { return }
                while !Task.isCancelled {
                    await refresh()
                    try? await Task.sleep(for: .seconds(30))
                }
            }
            .sheet(item: $sheet, onDismiss: openPendingRoom) { sheet in
                switch sheet {
                case .create:
                    RoomEditorSheet(layouts: app.rooms.themeLayouts) { draft in
                        pendingRoom = .room(id: try await createRoom(draft))
                    }
                case .joinByCode:
                    JoinByCodeSheet { code in pendingRoom = .code(code) }
                        .presentationDetents([.height(280)])
                case .studyBuddy:
                    StudyBuddySheet(onMatched: { pendingMatch = $0 }, onSitAnyway: { pendingRoom = .automatic })
                        .presentationDetents([.medium])
                case .preview(let roomId):
                    RoomDetailSheet(roomId: roomId) { pendingRoom = .room(id: roomId) }
                        .presentationDetents([.large])
                }
            }
            .confirmationDialog(
                "\(roomToDelete?.displayName ?? String(localized: "Oda")) silinsin mi?",
                isPresented: Binding(get: { roomToDelete != nil }, set: { if !$0 { roomToDelete = nil } }),
                titleVisibility: .visible
            ) {
                Button("Odayı Sil", role: .destructive) {
                    guard let room = roomToDelete else { return }
                    Task { await app.rooms.delete(room) }
                }
            } message: {
                Text("İçerideki herkesin oturumu biter ve oda herkesin listesinden kalkar.")
            }
            .errorAlert($rooms.error)
        }
    }

    // MARK: Home

    @ViewBuilder
    private var home: some View {
        let discover = app.rooms.discover
        VStack(alignment: .leading, spacing: 12) {
            LiveCount(count: app.rooms.overview?.focusingNow ?? 0)
                .padding(.horizontal, 20)
            ActivityTicker(items: app.rooms.activity) { item in openRoom(.room(id: item.roomId)) }
                .padding(.horizontal, 16)
            if let layout = discover?.layout ?? app.rooms.overview?.layout {
                QuickStartCard(layout: layout, halls: discover?.halls) { openRoom(.automatic) }
                    .padding(.horizontal, 16)
            }
            StudyBuddyCard { sheet = .studyBuddy }
                .padding(.horizontal, 16)
        }

        FriendsStrip(
            friends: app.friends.focusingFriends,
            hasFriends: !(app.friends.overview?.friends.isEmpty ?? true),
            showAll: { showsFriends = true }
        )

        if let discover {
            let topics = discoverTopics(discover.rooms)
            let rooms = topic.map { key in discover.rooms.filter { $0.topic?.key == key } } ?? discover.rooms
            let shelves = DiscoverShelves(rooms, now: ServerClock.deviceNow())
            if topics.count > 1 {
                TopicChips(topics: topics, selection: $topic)
            }
            shelf("Şu An Canlı", detail: "Masalarda biri var", rooms: shelves.live, in: discover)
            shelf("Bu Hafta Popüler", rooms: shelves.popular, in: discover)
            shelf("Yeni Açılanlar", rooms: shelves.fresh, in: discover)
            if topic != nil, shelves.live.isEmpty, shelves.popular.isEmpty, shelves.fresh.isEmpty {
                Text("Bu konuda şu an öne çıkan oda yok. Tüm odalara göz at.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 20)
            }
        }

        myRooms

        NavigationLink {
            DiscoverRoomsView(onPreview: { sheet = .preview(roomId: $0) }, onCreate: createRoom)
        } label: {
            HStack(spacing: 14) {
                GlyphIcon(symbol: "globe.europe.africa.fill", color: .indigo, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Tüm Herkese Açık Odalar")
                        .font(.headline)
                    Text("\(app.rooms.discover?.rooms.count ?? 0) oda")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.forward")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 20))
            .contentShape(.rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func shelf(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, rooms: [DiscoverRoom], in result: DiscoverResult) -> some View {
        RoomShelf(title, detail: detail, items: rooms) { room in
            Button { sheet = .preview(roomId: room.id) } label: {
                CompactRoomCard(
                    room: room,
                    layout: .forTheme(room.theme, in: result.layouts, fallback: result.layout),
                    isSeatedHere: room.id == result.seatedRoomId
                )
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var myRooms: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionTitle("Odalarım")
            if let overview = app.rooms.overview {
                if overview.myRooms.isEmpty {
                    emptyState
                }
                ForEach(overview.myRooms) { room in
                    Button { openRoom(.room(id: room.id)) } label: {
                        RoomCard(
                            room: room,
                            layout: .forTheme(room.theme, in: overview.layouts, fallback: overview.layout),
                            isSeatedHere: room.id == overview.seatedRoomId
                        )
                    }
                    .buttonStyle(.plain)
                    .contextMenu { menu(for: room) }
                }
            } else {
                ProgressView()
                    .frame(maxWidth: .infinity)
                    .padding(.top, 40)
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Search and topics

    private var isNarrowed: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// Public rooms whose name or description match, then the reader's own matching rooms.
    @ViewBuilder
    private var results: some View {
        let text = query.trimmingCharacters(in: .whitespaces)
        let publicRooms = (app.rooms.discover?.rooms ?? []).filter { room in
            room.displayName.localizedStandardContains(text) || (room.description?.localizedStandardContains(text) ?? false)
        }
        let mine = (app.rooms.overview?.myRooms ?? []).filter { $0.displayName.localizedStandardContains(text) }
        VStack(alignment: .leading, spacing: 12) {
            if publicRooms.isEmpty, mine.isEmpty {
                ContentUnavailableView.search(text: text)
                    .padding(.top, 40)
            }
            if let discover = app.rooms.discover, !publicRooms.isEmpty {
                SectionTitle("Herkese Açık")
                ForEach(publicRooms) { room in
                    Button { sheet = .preview(roomId: room.id) } label: {
                        RoomCard(
                            room: room.summary,
                            layout: .forTheme(room.theme, in: discover.layouts, fallback: discover.layout),
                            isSeatedHere: room.id == discover.seatedRoomId,
                            detail: room.description
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
            if let overview = app.rooms.overview, !mine.isEmpty {
                SectionTitle("Odalarım")
                ForEach(mine) { room in
                    Button { openRoom(.room(id: room.id)) } label: {
                        RoomCard(
                            room: room,
                            layout: .forTheme(room.theme, in: overview.layouts, fallback: overview.layout),
                            isSeatedHere: room.id == overview.seatedRoomId
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(.horizontal, 16)
    }

    // MARK: Helpers

    /// "Günaydın, Baransel" and so on through the day.
    private var greeting: String {
        guard let name = app.user?.displayName else { return "" }
        switch Calendar.current.component(.hour, from: .now) {
        case 5..<12: return String(localized: "Günaydın, \(name)")
        case 12..<18: return String(localized: "İyi günler, \(name)")
        case 18..<23: return String(localized: "İyi akşamlar, \(name)")
        default: return String(localized: "İyi geceler, \(name)")
        }
    }

    /// Free readers own up to two rooms; the third one is a Plus feature.
    private func createRoom() {
        let owned = app.rooms.overview?.myRooms.filter { $0.ownerId == app.user?.id }.count ?? 0
        if !app.plus.isActive, owned >= PlusCatalog.freeRoomLimit {
            showsPaywall = true
        } else {
            sheet = .create
        }
    }

    private func refresh() async {
        async let overview: Void = app.rooms.refresh()
        async let discover: Void = app.rooms.refreshDiscover()
        _ = await (overview, discover)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Henüz bir odan yok", systemImage: "door.left.hand.open")
        } description: {
            Text("Keşfet'ten bir odaya gidip masaya otur ya da arkadaşlarınla kendi odanı aç.")
        } actions: {
            Button("Oda Oluştur", action: createRoom)
                .buttonStyle(.borderedProminent)
            Button("Kodla Katıl") { sheet = .joinByCode }
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }

    @ViewBuilder
    private func menu(for room: RoomSummary) -> some View {
        if let code = room.code {
            ShareLink(item: String(localized: "PomoLive'da \(room.displayName) odasına gel! Oda kodu: \(code)")) {
                Label("Kodu Paylaş · \(code)", systemImage: "square.and.arrow.up")
            }
        }
        if room.ownerId == app.user?.id {
            Button("Odayı Sil", systemImage: "trash", role: .destructive) { roomToDelete = room }
        } else {
            Button("Odalarımdan Kaldır", systemImage: "minus.circle", role: .destructive) {
                Task { await app.rooms.forget(room) }
            }
        }
    }

    private func openPendingRoom() {
        if let pendingMatch {
            self.pendingMatch = nil
            return openMatch(pendingMatch)
        }
        guard let pendingRoom else { return }
        self.pendingRoom = nil
        openRoom(pendingRoom)
    }

    /// Creating a room also enters it on the server; the room screen re-joins by id.
    private func createRoom(_ draft: RoomEditorSheet.Draft) async throws -> String {
        try await app.hall.create(draft)
        return app.hall.room?.id ?? ""
    }
}
