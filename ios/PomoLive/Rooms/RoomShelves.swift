import SwiftUI

/// Public rooms sorted onto the shelves of the Odalar tab: busiest right now, most focused this
/// week and newly opened. A room appears on one shelf only.
struct DiscoverShelves {
    let live: [DiscoverRoom]
    let popular: [DiscoverRoom]
    let fresh: [DiscoverRoom]

    static let newRoomWindowMs: Int64 = 72 * 3_600_000
    private static let limit = 8

    init(_ rooms: [DiscoverRoom], now: Int64) {
        let live = rooms
            .filter { $0.occupiedCount + $0.presenceCount > 0 }
            .sorted { ($0.occupiedCount, $0.presenceCount) > ($1.occupiedCount, $1.presenceCount) }
            .prefix(Self.limit)
        var shown = Set(live.map(\.id))
        let popular = rooms
            .filter { !shown.contains($0.id) && $0.weeklyFocusMs > 0 }
            .sorted { $0.weeklyFocusMs > $1.weeklyFocusMs }
            .prefix(Self.limit)
        shown.formUnion(popular.map(\.id))
        let fresh = rooms
            .filter { !shown.contains($0.id) && now - $0.createdAt < Self.newRoomWindowMs }
            .sorted { $0.createdAt > $1.createdAt }
            .prefix(Self.limit)
        self.live = Array(live)
        self.popular = Array(popular)
        self.fresh = Array(fresh)
    }
}

/// The categories public rooms are mostly about, most common first, for filter chips.
func discoverTopics(_ rooms: [DiscoverRoom]) -> [FocusCategory] {
    var counts: [String: (category: FocusCategory, count: Int)] = [:]
    for topic in rooms.compactMap(\.topic) {
        counts[topic.key, default: (topic, 0)].count += 1
    }
    return counts.values.sorted { $0.count > $1.count }.map(\.category)
}

/// A softly pulsing green dot: something is happening right now.
struct LiveDot: View {
    var size: CGFloat = 8

    var body: some View {
        Image(systemName: "circle.fill")
            .font(.system(size: size))
            .foregroundStyle(.green)
            .symbolEffect(.pulse, options: .repeat(.continuous))
            .accessibilityHidden(true)
    }
}

/// "● 23 kişi şu an odaklanıyor", counting live.
struct LiveCount: View {
    let count: Int

    var body: some View {
        Label {
            Text(count > 0 ? "\(count) kişi şu an odaklanıyor" : "Salonlar seni bekliyor")
                .contentTransition(.numericText(value: Double(count)))
                .animation(.smooth, value: count)
        } icon: {
            if count > 0 { LiveDot() }
        }
        .font(.subheadline.weight(.medium))
        .foregroundStyle(.secondary)
    }
}

/// A horizontal shelf of room cards that snap into place and settle in as they scroll.
struct RoomShelf<Item: Identifiable, Card: View>: View {
    let title: LocalizedStringKey
    let detail: LocalizedStringKey?
    let items: [Item]
    @ViewBuilder let card: (Item) -> Card

    init(_ title: LocalizedStringKey, detail: LocalizedStringKey? = nil, items: [Item], @ViewBuilder card: @escaping (Item) -> Card) {
        self.title = title
        self.detail = detail
        self.items = items
        self.card = card
    }

    var body: some View {
        if !items.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                SectionTitle(title, detail: detail)
                    .padding(.horizontal, 16)
                ScrollView(.horizontal) {
                    LazyHStack(spacing: 12) {
                        ForEach(items) { item in
                            card(item)
                                .containerRelativeFrame(.horizontal) { width, _ in min(width * 0.72, 300) }
                                .scrollTransition(.interactive, axis: .horizontal) { content, phase in
                                    content
                                        .scaleEffect(phase.isIdentity ? 1 : 0.94)
                                        .opacity(phase.isIdentity ? 1 : 0.75)
                                }
                        }
                    }
                    .scrollTargetLayout()
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollTargetBehavior(.viewAligned)
                .scrollIndicators(.hidden)
            }
        }
    }
}

/// A public room on a shelf: the live look inside, its name and who is there.
struct CompactRoomCard: View {
    let room: DiscoverRoom
    let layout: LibraryLayout
    let isSeatedHere: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoomPreview(layout: layout, occupants: room.occupants)
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 8) {
                    GlyphIcon(symbol: room.symbol, color: room.color, size: 28)
                    Text(room.displayName)
                        .font(.headline)
                        .lineLimit(1)
                }
                HStack(spacing: 6) {
                    status
                        .font(.subheadline)
                        .lineLimit(1)
                    Spacer(minLength: 4)
                    AvatarStack(occupants: room.occupants)
                        .scaleEffect(0.8, anchor: .trailing)
                }
                .frame(height: 26)
            }
            .padding(12)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 20))
        .contentShape(.rect(cornerRadius: 20))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var status: some View {
        if isSeatedHere {
            Label("Masan burada", systemImage: "chair.lounge.fill")
                .foregroundStyle(Color.accentColor)
                .fontWeight(.medium)
        } else if room.occupiedCount > 0 {
            Label {
                Text("\(room.occupiedCount) kişi çalışıyor")
                    .contentTransition(.numericText(value: Double(room.occupiedCount)))
            } icon: {
                LiveDot(size: 7)
            }
            .foregroundStyle(.secondary)
        } else if let topic = room.topic {
            Label(topic.displayName, systemImage: topic.symbol)
                .foregroundStyle(.secondary)
        } else {
            Text("\(room.memberCount) üye")
                .foregroundStyle(.secondary)
        }
    }
}

/// One tap to a desk in whichever system hall has space, with the hall itself as the picture.
struct QuickStartCard: View {
    let layout: LibraryLayout
    let halls: DiscoverResult.Halls?
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 0) {
                RoomPreview(layout: layout, occupants: [])
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hemen Başla")
                            .font(.title3.weight(.bold))
                        Group {
                            if let halls, halls.occupiedCount > 0 {
                                Label {
                                    Text("Genel salonda \(halls.occupiedCount) kişi çalışıyor")
                                        .contentTransition(.numericText(value: Double(halls.occupiedCount)))
                                } icon: {
                                    LiveDot(size: 7)
                                }
                            } else {
                                Text("Boş yeri olan genel salona otur")
                            }
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Image(systemName: "arrow.right")
                        .font(.headline)
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(Color.accentColor, in: .circle)
                }
                .padding(14)
            }
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(.rect(cornerRadius: 22))
            .contentShape(.rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

/// Friends focusing right now, as faces with live timers; or an invitation to find some.
struct FriendsStrip: View {
    let friends: [Friend]
    let hasFriends: Bool
    let showAll: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                SectionTitle("Arkadaşlar")
                Spacer()
                Button(hasFriends ? "Tümü" : "Bul", action: showAll)
                    .font(.subheadline.weight(.semibold))
            }
            .padding(.horizontal, 16)

            if friends.isEmpty {
                Button(action: showAll) {
                    HStack(spacing: 14) {
                        GlyphIcon(symbol: "person.2.fill", color: .teal, size: 40)
                        Text(hasFriends ? "Şu an kimse çalışmıyor. İlk sen başla!" : "Arkadaşlarını bul, birlikte çalış")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.leading)
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
            } else {
                ScrollView(.horizontal) {
                    HStack(spacing: 16) {
                        ForEach(friends) { friend in
                            Button(action: showAll) { FriendBubble(friend: friend) }
                                .buttonStyle(.plain)
                        }
                    }
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollIndicators(.hidden)
            }
        }
    }
}

private struct FriendBubble: View {
    let friend: Friend

    var body: some View {
        VStack(spacing: 6) {
            Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: friend.user.avatarSpriteId)), scale: 1)
                .resizable()
                .interpolation(.none)
                .frame(width: 38, height: 38)
                .frame(width: 60, height: 60)
                .background(.fill.tertiary, in: .circle)
                .overlay {
                    Circle().strokeBorder(friend.activity?.resting == true ? Color.mint : Color.green, lineWidth: 2.5)
                }
            Text(friend.user.displayName)
                .font(.caption.weight(.medium))
                .lineLimit(1)
            if let activity = friend.activity {
                Text(Date(timeIntervalSince1970: Double(activity.since) / 1000), style: .timer)
                    .font(.caption2)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
        }
        .frame(width: 72)
        .accessibilityElement(children: .combine)
    }
}

/// "Tümü · Yazılım · Ders Çalışma…": narrows public rooms to one topic.
struct TopicChips: View {
    let topics: [FocusCategory]
    @Binding var selection: String?

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 8) {
                chip(title: Text("Tümü"), symbol: nil, key: nil)
                ForEach(topics, id: \.key) { topic in
                    chip(title: Text(topic.displayName), symbol: topic.symbol, key: topic.key)
                }
            }
        }
        .contentMargins(.horizontal, 16, for: .scrollContent)
        .scrollIndicators(.hidden)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func chip(title: Text, symbol: String?, key: String?) -> some View {
        let isSelected = selection == key
        return Button {
            withAnimation(.smooth) { selection = key }
        } label: {
            HStack(spacing: 5) {
                if let symbol { Image(systemName: symbol) }
                title
            }
            .font(.subheadline.weight(.medium))
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
            .background(isSelected ? AnyShapeStyle(Color.accentColor) : AnyShapeStyle(Color(.secondarySystemGroupedBackground)), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// What just happened in the open library, one line at a time, rolling to the next every few
/// seconds: "Elif · Yazılım çalışmaya başladı", "Mert 50 dk odaklandı". Tap to go there.
struct ActivityTicker: View {
    let items: [FeedItem]
    let onOpen: (FeedItem) -> Void

    @State private var index = 0

    private static let interval = Duration.seconds(4)

    var body: some View {
        if let item = items.isEmpty ? nil : items[index % items.count] {
            Button { onOpen(item) } label: {
                // The card stays put; only the line inside rolls to the next item.
                HStack(spacing: 10) {
                    Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: item.user.avatarSpriteId)), scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 20, height: 20)
                        .frame(width: 30, height: 30)
                        .background(.fill.tertiary, in: .circle)
                    VStack(alignment: .leading, spacing: 1) {
                        line(for: item)
                            .font(.subheadline)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                        Text("\(item.roomDisplayName) · \(Date(timeIntervalSince1970: Double(item.at) / 1000), format: .relative(presentation: .named).locale(.app))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    Image(systemName: item.kind == .started ? item.category.symbol : "checkmark.seal.fill")
                        .foregroundStyle(item.kind == .started ? item.category.color.color : .green)
                }
                .id(item.id)
                .transition(.push(from: .bottom))
                .padding(.horizontal, 14)
                .frame(maxWidth: .infinity, minHeight: 56, maxHeight: 56, alignment: .leading)
                .background(Color(.secondarySystemGroupedBackground))
                .clipShape(.rect(cornerRadius: 18))
                .contentShape(.rect(cornerRadius: 18))
            }
            .buttonStyle(.plain)
            .animation(.smooth(duration: 0.5), value: item.id)
            .task(id: items.count) {
                while !Task.isCancelled, items.count > 1 {
                    try? await Task.sleep(for: Self.interval)
                    index += 1
                }
            }
        }
    }

    private func line(for item: FeedItem) -> Text {
        switch item.kind {
        case .started:
            Text("**\(item.user.displayName)** \(item.category.displayName) çalışmaya başladı")
        case .finished:
            Text("**\(item.user.displayName)** \(item.minutes ?? 0) dk \(item.category.displayName) odaklandı")
        }
    }
}

private extension FeedItem {
    var roomDisplayName: String { localizedRoomName(id: roomId, name: roomName) }
}
