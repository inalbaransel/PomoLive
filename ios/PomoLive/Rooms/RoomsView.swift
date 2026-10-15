import SwiftUI

/// The home tab: a way into public rooms, then the reader's own community of rooms as live cards.
struct RoomsView: View {
    let openRoom: (HallStore.Target) -> Void

    @Environment(AppModel.self) private var app
    @State private var sheet: Sheet?
    /// Opened once the sheet has finished dismissing, so two presentations never overlap.
    @State private var pendingRoom: HallStore.Target?

    private enum Sheet: String, Identifiable {
        case create, joinByCode
        var id: String { rawValue }
    }

    @State private var roomToDelete: RoomSummary?

    var body: some View {
        @Bindable var rooms = app.rooms

        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    NavigationLink {
                        DiscoverRoomsView(openRoom: openRoom, onCreate: { sheet = .create })
                    } label: {
                        DiscoverBanner(focusingNow: app.rooms.overview?.focusingNow)
                    }
                    .buttonStyle(.plain)

                    SectionTitle("Odalarım")
                        .padding(.top, 12)

                    if let overview = app.rooms.overview {
                        if overview.myRooms.isEmpty {
                            emptyState
                        }
                        ForEach(overview.myRooms) { room in
                            Button { openRoom(.room(id: room.id)) } label: {
                                RoomCard(room: room, layout: overview.layout, isSeatedHere: room.id == overview.seatedRoomId)
                            }
                            .buttonStyle(.plain)
                            .contextMenu { menu(for: room) }
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .padding(.top, 60)
                    }
                }
                .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Odalar")
            .navigationSubtitle(app.user.map { "Merhaba, \($0.displayName)" } ?? "")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Menu("Oda", systemImage: "plus") {
                        Button("Oda Oluştur", systemImage: "plus.rectangle.on.rectangle") { sheet = .create }
                        Button("Kodla Katıl", systemImage: "number") { sheet = .joinByCode }
                    }
                }
            }
            .refreshable { await app.rooms.refresh() }
            .task(id: app.connection) {
                // Live counts change while the tab is visible; poll gently instead of streaming every room.
                guard app.connection == .online else { return }
                while !Task.isCancelled {
                    await app.rooms.refresh()
                    try? await Task.sleep(for: .seconds(20))
                }
            }
            .sheet(item: $sheet, onDismiss: openPendingRoom) { sheet in
                switch sheet {
                case .create:
                    RoomEditorSheet { draft in
                        pendingRoom = .room(id: try await createRoom(draft))
                    }
                case .joinByCode:
                    JoinByCodeSheet { code in pendingRoom = .code(code) }
                        .presentationDetents([.height(280)])
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

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Henüz bir odan yok", systemImage: "door.left.hand.open")
        } description: {
            Text("Keşfet'ten bir odaya gidip masaya otur ya da arkadaşlarınla kendi odanı aç.")
        } actions: {
            Button("Oda Oluştur") { sheet = .create }
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
        guard let pendingRoom else { return }
        self.pendingRoom = nil
        openRoom(pendingRoom)
    }

    /// Creating a room also enters it on the server; the room screen re-joins by id.
    private func createRoom(_ draft: RoomEditorSheet.Draft) async throws -> String {
        try await app.hall.create(name: draft.name, symbol: draft.symbol, color: draft.color, visibility: draft.visibility, theme: draft.theme)
        return app.hall.room?.id ?? ""
    }
}

/// The way into public rooms, with how many people are focusing in them right now.
private struct DiscoverBanner: View {
    let focusingNow: Int?

    var body: some View {
        HStack(spacing: 14) {
            GlyphIcon(symbol: "globe.europe.africa.fill", color: .indigo, size: 44)
            VStack(alignment: .leading, spacing: 2) {
                Text("Keşfet")
                    .font(.headline)
                Text(focusingNow.map { $0 > 0 ? "Şu an \($0) kişi odaklanıyor" : "Herkese açık odalara göz at" } ?? " ")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .contentTransition(.numericText())
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
    }
}
