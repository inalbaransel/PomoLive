import SwiftUI

/// Every room anyone can walk into: the system halls and readers' public rooms, searchable by name.
struct DiscoverRoomsView: View {
    let openRoom: (HallStore.Target) -> Void
    let onCreate: () -> Void

    @Environment(AppModel.self) private var app
    @State private var query = ""

    private var publicRooms: [RoomSummary] {
        let rooms = app.rooms.overview?.publicRooms ?? []
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return rooms }
        return rooms.filter { $0.name.localizedStandardContains(trimmed) }
    }

    var body: some View {
        ScrollView {
            if let overview = app.rooms.overview {
                LazyVStack(alignment: .leading, spacing: 14) {
                    if query.isEmpty {
                        SectionTitle("Genel Salonlar", detail: "Herkesin oturabildiği salonlar. Dolunca yenisi açılır.")
                        ForEach(overview.halls) { room in
                            card(room, overview: overview)
                        }
                    }

                    SectionTitle("Herkese Açık Odalar", detail: query.isEmpty ? "Okurların açtığı odalar." : nil)
                        .padding(.top, query.isEmpty ? 12 : 0)
                    if publicRooms.isEmpty {
                        ContentUnavailableView {
                            Label(query.isEmpty ? "Henüz açık oda yok" : "Sonuç yok", systemImage: "magnifyingglass")
                        } description: {
                            Text(query.isEmpty ? "İlk herkese açık odayı sen aç." : "\"\(query)\" adında bir oda bulunamadı.")
                        } actions: {
                            if query.isEmpty {
                                Button("Oda Oluştur", action: onCreate)
                                    .buttonStyle(.borderedProminent)
                            }
                        }
                    }
                    ForEach(publicRooms) { room in
                        card(room, overview: overview)
                    }
                }
                .padding(16)
            } else {
                ProgressView()
                    .padding(.top, 120)
            }
        }
        .background(Color(.systemGroupedBackground))
        .navigationTitle("Keşfet")
        .navigationBarTitleDisplayMode(.large)
        .searchable(text: $query, prompt: "Oda ara")
        .refreshable { await app.rooms.refresh() }
    }

    private func card(_ room: RoomSummary, overview: RoomsOverview) -> some View {
        Button { openRoom(.room(id: room.id)) } label: {
            RoomCard(room: room, layout: overview.layout, isSeatedHere: room.id == overview.seatedRoomId)
        }
        .buttonStyle(.plain)
    }
}

/// A grouped-style section heading for card lists.
struct SectionTitle: View {
    let title: String
    let detail: String?

    init(_ title: String, detail: String? = nil) {
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
