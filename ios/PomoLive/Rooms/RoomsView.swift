import SwiftUI

/// The home tab: a greeting with today's focus, then halls, public rooms and the reader's rooms.
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

    var body: some View {
        @Bindable var rooms = app.rooms

        NavigationStack {
            List {
                Section {
                    TodaySummary(summary: app.stats.summary)
                }

                if let overview = app.rooms.overview {
                    section("Genel Salonlar", rooms: overview.halls, seatedRoomId: overview.seatedRoomId)
                    if !overview.myRooms.isEmpty {
                        section("Odalarım", rooms: overview.myRooms, seatedRoomId: overview.seatedRoomId)
                    }
                    Section {
                        ForEach(overview.publicRooms) { room in
                            roomButton(room, seatedRoomId: overview.seatedRoomId)
                        }
                        if overview.publicRooms.isEmpty {
                            Button("İlk odayı sen aç", systemImage: "plus.circle.fill") { sheet = .create }
                        }
                    } header: {
                        Text("Keşfet")
                    } footer: {
                        Text("Herkese açık odalar. Özel bir odaya katılmak için sağ üstteki + ile kodu gir.")
                    }
                } else {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
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
            .refreshable { await refresh() }
            .task(id: app.connection) {
                // Live counts change while the tab is visible; poll gently instead of streaming every room.
                guard app.connection == .online else { return }
                while !Task.isCancelled {
                    await refresh()
                    try? await Task.sleep(for: .seconds(20))
                }
            }
            .sheet(item: $sheet, onDismiss: openPendingRoom) { sheet in
                switch sheet {
                case .create:
                    CreateRoomSheet { name, emoji, visibility in
                        pendingRoom = .room(id: try await createRoom(name: name, emoji: emoji, visibility: visibility))
                    }
                case .joinByCode:
                    JoinByCodeSheet { code in pendingRoom = .code(code) }
                        .presentationDetents([.height(280)])
                }
            }
            .errorAlert($rooms.error)
        }
    }

    private func section(_ title: String, rooms: [RoomState], seatedRoomId: String?) -> some View {
        Section(title) {
            ForEach(rooms) { room in
                roomButton(room, seatedRoomId: seatedRoomId)
            }
        }
    }

    private func roomButton(_ room: RoomState, seatedRoomId: String?) -> some View {
        Button { openRoom(.room(id: room.id)) } label: {
            RoomRow(room: room, isSeatedHere: room.id == seatedRoomId)
        }
        .tint(.primary)
    }

    private func openPendingRoom() {
        guard let pendingRoom else { return }
        self.pendingRoom = nil
        openRoom(pendingRoom)
    }

    private func refresh() async {
        async let rooms: Void = app.rooms.refresh()
        async let stats: Void = app.stats.refresh()
        _ = await (rooms, stats)
    }

    /// Creating a room also enters it on the server; the room screen re-joins by id.
    private func createRoom(name: String, emoji: String, visibility: RoomKind) async throws -> String {
        try await app.hall.create(name: name, emoji: emoji, visibility: visibility)
        return app.hall.room?.id ?? ""
    }
}

/// Today's focus at a glance, in the spirit of Fitness: one big number, two quiet companions.
private struct TodaySummary: View {
    let summary: StatsSummary?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Bugün")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(summary.map { formattedFocus($0.todayMs) } ?? "–")
                    .font(.system(.largeTitle, design: .rounded, weight: .semibold))
                    .contentTransition(.numericText())
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 6) {
                Label("\(summary?.streakDays ?? 0) gün seri", systemImage: "flame.fill")
                    .foregroundStyle(.orange)
                Text("Bu hafta \(summary.map { formattedFocus($0.weekMs) } ?? "–")")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline.weight(.medium))
            .labelStyle(.titleAndIcon)
        }
        .padding(.vertical, 6)
        .accessibilityElement(children: .combine)
    }
}

struct RoomRow: View {
    let room: RoomState
    let isSeatedHere: Bool

    var body: some View {
        HStack(spacing: 12) {
            EmojiTile(emoji: room.emoji)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(room.name)
                        .lineLimit(1)
                    if room.kind == .private {
                        Image(systemName: "lock.fill")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .accessibilityLabel("Özel")
                    }
                }
                Group {
                    if isSeatedHere {
                        let seated = Text("Masan burada").foregroundStyle(Color.accentColor).fontWeight(.medium)
                        Text("\(seated) · \(room.presenceCount) kişi")
                    } else {
                        Text("\(room.presenceCount) kişi · \(room.occupiedCount)/\(room.capacity) masa")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .monospacedDigit()
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.forward")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
