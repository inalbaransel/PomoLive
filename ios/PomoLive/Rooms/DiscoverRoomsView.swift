import SwiftUI

/// Every public room, best first by the server's discover score, searchable by name and
/// description and narrowed by topic. Tapping a room shows its details before joining.
struct DiscoverRoomsView: View {
    let onPreview: (String) -> Void
    let onCreate: () -> Void

    @Environment(AppModel.self) private var app
    @State private var query = ""
    @State private var topic: String?

    var body: some View {
        ScrollView {
            if let result = app.rooms.discover {
                let rooms = filtered(result.rooms)
                VStack(alignment: .leading, spacing: 14) {
                    let topics = discoverTopics(result.rooms)
                    if topics.count > 1 {
                        TopicChips(topics: topics, selection: $topic)
                            .padding(.horizontal, -16)
                    }
                    ForEach(rooms) { room in
                        Button { onPreview(room.id) } label: {
                            RoomCard(
                                room: room.summary,
                                layout: .forTheme(room.theme, in: result.layouts, fallback: result.layout),
                                isSeatedHere: room.id == result.seatedRoomId,
                                detail: detail(for: room)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                    if result.rooms.isEmpty {
                        emptyState
                    } else if rooms.isEmpty {
                        ContentUnavailableView.search(text: query)
                            .padding(.top, 40)
                    }
                }
                .padding(16)
                .animation(.smooth, value: rooms.map(\.id))
            } else {
                ProgressView()
                    .padding(.top, 120)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Tüm Odalar")
        .searchable(text: $query, placement: .navigationBarDrawer(displayMode: .always), prompt: "Oda adı veya açıklama ara")
        .refreshable { await app.rooms.refreshDiscover() }
    }

    private func filtered(_ rooms: [DiscoverRoom]) -> [DiscoverRoom] {
        let text = query.trimmingCharacters(in: .whitespaces)
        return rooms.filter { room in
            (topic == nil || room.topic?.key == topic)
                && (text.isEmpty
                    || room.displayName.localizedStandardContains(text)
                    || (room.description?.localizedStandardContains(text) ?? false))
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
        if parts.isEmpty, ServerClock.deviceNow() - room.createdAt < DiscoverShelves.newRoomWindowMs {
            parts.append(String(localized: "Yeni açıldı"))
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("Henüz açık oda yok", systemImage: "globe.europe.africa")
        } description: {
            Text("İlk herkese açık odayı sen aç; herkes görsün.")
        } actions: {
            Button("Oda Oluştur", action: onCreate)
                .buttonStyle(.borderedProminent)
        }
        .padding(.vertical, 24)
        .frame(maxWidth: .infinity)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 22))
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
