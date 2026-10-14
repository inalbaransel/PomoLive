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
                    TodayCard(summary: app.stats.summary, userName: app.user?.displayName)
                        .listRowInsets(EdgeInsets())
                        .listRowBackground(Color.clear)
                }

                if let overview = app.rooms.overview {
                    section("Genel Salonlar", rooms: overview.halls, seatedRoomId: overview.seatedRoomId)
                    if !overview.myRooms.isEmpty {
                        section("Odalarım", rooms: overview.myRooms, seatedRoomId: overview.seatedRoomId)
                    }
                    section("Herkese Açık Odalar", rooms: overview.publicRooms, seatedRoomId: overview.seatedRoomId,
                            empty: "Henüz kimse oda açmadı. İlk odayı sen aç!")
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                        .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Odalar")
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

    @ViewBuilder
    private func section(_ title: String, rooms: [RoomState], seatedRoomId: String?, empty: String? = nil) -> some View {
        Section(title) {
            if rooms.isEmpty, let empty {
                Text(empty)
                    .foregroundStyle(.secondary)
            }
            ForEach(rooms) { room in
                Button { openRoom(.room(id: room.id)) } label: {
                    RoomRow(room: room, isSeatedHere: room.id == seatedRoomId)
                }
                .buttonStyle(.plain)
            }
        }
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

private struct TodayCard: View {
    let summary: StatsSummary?
    let userName: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Merhaba, \(userName ?? "okur")")
                .font(.title2.weight(.bold))
            HStack(spacing: 12) {
                metric("Bugün", value: summary.map { formattedFocus($0.todayMs) } ?? "—", symbol: "sun.max.fill")
                metric("Seri", value: summary.map { "\($0.streakDays) gün" } ?? "—", symbol: "flame.fill")
                metric("Bu hafta", value: summary.map { formattedFocus($0.weekMs) } ?? "—", symbol: "calendar")
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.accentColor.opacity(0.18)), in: .rect(cornerRadius: 28))
    }

    private func metric(_ title: String, value: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(title, systemImage: symbol)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text(value)
                .font(.system(.headline, design: .monospaced))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct RoomRow: View {
    let room: RoomState
    let isSeatedHere: Bool

    var body: some View {
        HStack(spacing: 14) {
            Text(room.emoji)
                .font(.title2)
                .frame(width: 48, height: 48)
                .glassEffect(.regular, in: .rect(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(room.name)
                        .font(.headline)
                        .lineLimit(1)
                    if room.kind == .private {
                        Image(systemName: "lock.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Text("\(room.presenceCount) kişi · \(room.occupiedCount)/\(room.capacity) masa")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .monospacedDigit()
            }
            Spacer(minLength: 0)
            if isSeatedHere {
                Image(systemName: "chair.lounge.fill")
                    .font(.footnote.weight(.semibold))
                    .frame(width: 32, height: 32)
                    .glassEffect(.regular.tint(.accentColor.opacity(0.5)), in: .circle)
                    .accessibilityLabel("Masan bu odada")
            }
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.tertiary)
        }
        .contentShape(.rect)
        .accessibilityElement(children: .combine)
    }
}
