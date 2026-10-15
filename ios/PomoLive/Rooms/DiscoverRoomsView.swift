import SwiftUI

/// Public rooms, ranked by the server's discover score: a one-tap start in a system hall, then
/// rooms with people in them now, the week's most popular rooms and new ones, filterable by topic.
struct DiscoverRoomsView: View {
    let openRoom: (HallStore.Target) -> Void
    let onCreate: () -> Void

    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var topicKey: String?

    private static let newRoomWindowMs: Int64 = 72 * 3_600_000
    private static let sectionLimit = 6

    var body: some View {
        ScrollView {
            if let result = app.rooms.discover {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if !isFiltering {
                        QuickStartCard(halls: result.halls) { openRoom(.automatic) }
                    }
                    if !topics(in: result).isEmpty {
                        topicFilter(result)
                    }
                    if isFiltering {
                        section("Sonuçlar", rooms: filtered(result), result: result)
                    } else {
                        let live = result.rooms.filter { $0.occupiedCount + $0.presenceCount > 0 }
                        let liveIds = Set(live.prefix(Self.sectionLimit).map(\.id))
                        let popular = result.rooms
                            .filter { !liveIds.contains($0.id) && $0.weeklyFocusMs > 0 }
                            .sorted { $0.weeklyFocusMs > $1.weeklyFocusMs }
                        let shownIds = liveIds.union(popular.prefix(Self.sectionLimit).map(\.id))
                        let fresh = result.rooms
                            .filter { !shownIds.contains($0.id) && isNew($0) }
                            .sorted { $0.createdAt > $1.createdAt }
                        let rest = result.rooms.filter { !shownIds.contains($0.id) && !isNew($0) }

                        section("Şu An Canlı", rooms: Array(live.prefix(Self.sectionLimit)), result: result)
                        section("Bu Hafta Popüler", rooms: Array(popular.prefix(Self.sectionLimit)), result: result)
                        section("Yeni Açılanlar", rooms: Array(fresh.prefix(Self.sectionLimit)), result: result)
                        section("Tüm Odalar", rooms: rest, result: result)
                        if result.rooms.isEmpty { emptyState }
                    }
                }
                .padding(16)
                .animation(.snappy, value: topicKey)
            } else {
                ProgressView()
                    .padding(.top, 120)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Keşfet")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Oda ara")
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
        topicKey != nil || !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func filtered(_ result: DiscoverResult) -> [DiscoverRoom] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        return result.rooms.filter { room in
            (topicKey == nil || room.topic?.key == topicKey)
                && (trimmed.isEmpty || room.displayName.localizedStandardContains(trimmed))
        }
    }

    /// Topics that at least one room has, most common first.
    private func topics(in result: DiscoverResult) -> [FocusCategory] {
        let counts = Dictionary(grouping: result.rooms.compactMap(\.topic), by: \.key)
        return counts.values.sorted { $0.count > $1.count }.compactMap(\.first)
    }

    private func isNew(_ room: DiscoverRoom) -> Bool {
        ServerClock.deviceNow() - room.createdAt < Self.newRoomWindowMs
    }

    private func topicFilter(_ result: DiscoverResult) -> some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(Text("Tümü"), symbol: nil, color: nil, isSelected: topicKey == nil) { topicKey = nil }
                ForEach(topics(in: result)) { topic in
                    chip(Text(topic.displayName), symbol: topic.symbol, color: topic.color, isSelected: topicKey == topic.key) {
                        topicKey = topicKey == topic.key ? nil : topic.key
                    }
                }
            }
            .padding(.horizontal, 16)
        }
        .scrollIndicators(.hidden)
        .padding(.horizontal, -16)
    }

    private func chip(_ title: Text, symbol: String?, color: GlyphColor?, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let symbol, let color {
                    Image(systemName: symbol)
                        .foregroundStyle(isSelected ? .white : color.color)
                }
                title
            }
            .font(.subheadline.weight(.medium))
            .foregroundStyle(isSelected ? .white : .primary)
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func section(_ title: LocalizedStringKey, rooms: [DiscoverRoom], result: DiscoverResult) -> some View {
        if !rooms.isEmpty {
            SectionTitle(title)
                .padding(.top, 10)
            ForEach(rooms) { room in
                Button { openRoom(.room(id: room.id)) } label: {
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

    /// "Yazılım ağırlıklı · bu hafta 12 sa · 8 üye"
    private func detail(for room: DiscoverRoom) -> String? {
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
