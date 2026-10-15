import SwiftUI

/// A room as a card: a live look inside, then its name, what is happening and who is there.
struct RoomCard: View {
    let room: RoomSummary
    let layout: LibraryLayout
    let isSeatedHere: Bool
    /// An extra quiet line, e.g. the room's topic and last week's activity in Keşfet.
    var detail: String?

    var body: some View {
        VStack(spacing: 0) {
            RoomPreview(layout: layout, occupants: room.occupants)
            HStack(spacing: 12) {
                GlyphIcon(symbol: room.symbol, color: room.color, size: 40)
                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 5) {
                        Text(room.displayName)
                            .font(.headline)
                            .lineLimit(1)
                        if room.kind == .private {
                            Image(systemName: "lock.fill")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .accessibilityLabel("Özel")
                        }
                    }
                    status
                        .font(.subheadline)
                        .lineLimit(1)
                    if let detail {
                        Text(detail)
                            .font(.footnote)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 8)
                AvatarStack(occupants: room.occupants)
            }
            .padding(14)
        }
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(.rect(cornerRadius: 22))
        .contentShape(.rect(cornerRadius: 22))
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
            } icon: {
                Image(systemName: "circle.fill")
                    .font(.system(size: 7))
                    .foregroundStyle(.green)
            }
            .foregroundStyle(.secondary)
        } else if room.presenceCount > 0 {
            Text("\(room.presenceCount) kişi göz atıyor")
                .foregroundStyle(.secondary)
        } else {
            Text("Şu an sessiz")
                .foregroundStyle(.secondary)
        }
    }
}

/// Up to three pixel faces of the people inside, then "+N".
struct AvatarStack: View {
    let occupants: [RoomOccupant]

    private static let visible = 3

    var body: some View {
        HStack(spacing: -10) {
            ForEach(occupants.prefix(Self.visible), id: \.deskId) { occupant in
                Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: occupant.avatarSpriteId)), scale: 1)
                    .resizable()
                    .interpolation(.none)
                    .frame(width: 22, height: 22)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2)
                    }
            }
            if occupants.count > Self.visible {
                Text("+\(occupants.count - Self.visible)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(width: 32, height: 32)
                    .background {
                        Circle()
                            .fill(Color(.tertiarySystemGroupedBackground))
                            .strokeBorder(Color(.secondarySystemGroupedBackground), lineWidth: 2)
                    }
            }
        }
        .accessibilityHidden(true)
    }
}
