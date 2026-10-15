import SwiftUI

/// Public rooms, ranked by the server's discover score: a one-tap start in a system hall, then the
/// most active rooms right now, the week's most popular, new ones and everything else, searchable
/// by name and description. Tapping a room shows its details before joining.
struct DiscoverRoomsView: View {
    let openRoom: (HallStore.Target) -> Void
    let onCreate: () -> Void

    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var previewRoom: PreviewTarget?

    private struct PreviewTarget: Identifiable {
        let id: String
    }

    private static let newRoomWindowMs: Int64 = 72 * 3_600_000
    private static let sectionLimit = 6

    var body: some View {
        ScrollView {
            if let result = app.rooms.discover {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if isFiltering {
                        let matches = filtered(result)
                        section("Sonuçlar", rooms: matches, result: result)
                        if matches.isEmpty {
                            ContentUnavailableView.search(text: query)
                                .padding(.top, 40)
                        }
                    } else {
                        QuickStartCard(halls: result.halls) { openRoom(.automatic) }
                        let live = result.rooms
                            .filter { $0.occupiedCount + $0.presenceCount > 0 }
                            .sorted { ($0.occupiedCount, $0.presenceCount) > ($1.occupiedCount, $1.presenceCount) }
                        let liveIds = Set(live.prefix(Self.sectionLimit).map(\.id))
                        let popular = result.rooms
                            .filter { !liveIds.contains($0.id) && $0.weeklyFocusMs > 0 }
                            .sorted { $0.weeklyFocusMs > $1.weeklyFocusMs }
                        let shownIds = liveIds.union(popular.prefix(Self.sectionLimit).map(\.id))
                        let fresh = result.rooms
                            .filter { !shownIds.contains($0.id) && isNew($0) }
                            .sorted { $0.createdAt > $1.createdAt }
                        let rest = result.rooms.filter { !shownIds.contains($0.id) && !isNew($0) }

                        section("Şu An En Aktif", rooms: Array(live.prefix(Self.sectionLimit)), result: result)
                        section("Bu Hafta Popüler", rooms: Array(popular.prefix(Self.sectionLimit)), result: result)
                        section("Yeni Açılanlar", rooms: Array(fresh.prefix(Self.sectionLimit)), result: result)
                        section("Tüm Odalar", rooms: rest, result: result)
                        if result.rooms.isEmpty { emptyState }
                    }
                }
                .padding(16)
                .animation(.snappy, value: isFiltering)
            } else {
                ProgressView()
                    .padding(.top, 120)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Keşfet")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Oda adı veya açıklama ara")
        .sheet(item: $previewRoom) { target in
            RoomDetailSheet(roomId: target.id) { openRoom(.room(id: target.id)) }
                .presentationDetents([.large])
        }
        .refreshable { await app.rooms.refreshDiscover() }
        .task(id: app.connection) {
            guard app.connection == .online else { return }
            while !Task.isCancelled {
                await app.rooms.refreshDiscover()
                try? await Task.sleep(for: .seconds(20))
            }
        }
    }

    private var isFiltering: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func filtered(_ result: DiscoverResult) -> [DiscoverRoom] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return result.rooms.filter { room in
            room.displayName.localizedStandardContains(trimmed)
                || (room.description?.localizedStandardContains(trimmed) ?? false)
        }
    }

    private func isNew(_ room: DiscoverRoom) -> Bool {
        ServerClock.deviceNow() - room.createdAt < Self.newRoomWindowMs
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, rooms: [DiscoverRoom], result: DiscoverResult) -> some View {
        if !rooms.isEmpty {
            SectionTitle(title)
                .padding(.top, 10)
            ForEach(rooms) { room in
                Button { previewRoom = PreviewTarget(id: room.id) } label: {
                    RoomCard(
                        room: room.summary,
                        layout: .forTheme(room.theme, in: result.layouts, fallback: result.layout),
                        isSeatedHere: room.id == result.seatedRoomId,
                        detail: detail(for: room)
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    /// The room's own description if it has one, otherwise "Yazılım ağırlıklı · bu hafta 12 sa · 8 üye".
    private func detail(for room: DiscoverRoom) -> String? {
        if let description = room.description {
            return description.replacingOccurrences(of: "\n", with: " ")
        }
        var parts: [String] = []
        if let topic = room.topic { parts.append(String(localized: "\(topic.displayName) ağırlıklı")) }
        if room.weeklyFocusMs >= 60 * 60_000 { parts.append(String(localized: "bu hafta \(formattedFocus(room.weeklyFocusMs))")) }
        if room.memberCount > 1 { parts.append(String(localized: "\(room.memberCount) üye")) }
        if parts.isEmpty, isNew(room) { parts.append(String(localized: "Yeni açıldı")) }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Henüz açık oda yok", systemImage: "globe.europe.africa")
        } description: {
            Text("İlk herkese açık odayı sen aç; Keşfet'te herkes görsün.")
        } actions: {
            Button("Oda Oluştur", action: onCreate)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
    }
}

/// One tap to a desk in whichever system hall has space.
private struct QuickStartCard: View {
    let halls: DiscoverResult.Halls
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                GlyphIcon(symbol: "bolt.fill", color: .indigo, size: 44)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Hemen Başla")
                        .font(.headline)
                    Text(halls.occupiedCount > 0
                        ? "Genel salonda \(halls.occupiedCount) kişi çalışıyor"
                        : "Boş yeri olan genel salona otur")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
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
        .buttonStyle(.plain)
    }
}

/// A grouped-style section heading for card lists.
struct SectionTitle: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil) {
        self.title = title
        self.detail = detail
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.title3.weight(.bold))
            if let detail {
                Text(detail)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 4)
        .accessibilityAddTraits(.isHeader)
    }
}
