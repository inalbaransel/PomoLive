import SwiftUI

/// A public room before joining: a look inside, what it is for, who runs it, who is there now and
/// how active it has been, with the join button pinned at the bottom.
struct RoomDetailSheet: View {
    let roomId: String
    let onJoin: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State private var preview: RoomPreviewResult?
    @State private var error: LibraryError?
    @State private var profileUserId: String?

    var body: some View {
        NavigationStack {
            Group {
                if let preview {
                    content(preview)
                } else if let error {
                    ContentUnavailableView(
                        "Oda açılamadı",
                        systemImage: "door.left.hand.closed",
                        description: Text(error.errorDescription ?? "")
                    )
                } else {
                    ProgressView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Kapat", systemImage: "xmark", role: .close) { dismiss() }
                }
            }
            .navigationDestination(item: $profileUserId) { UserProfileView(userId: $0) }
        }
        .task { await load() }
    }

    private func content(_ preview: RoomPreviewResult) -> some View {
        let room = preview.room
        return ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                RoomPreview(layout: preview.layout, occupants: room.occupants)
                    .clipShape(.rect(cornerRadius: 20))

                HStack(alignment: .top, spacing: 14) {
                    GlyphIcon(symbol: room.symbol, color: room.color, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(room.displayName)
                            .font(.title2.weight(.bold))
                        if let owner = preview.owner {
                            Button { profileUserId = owner.id } label: {
                                Text("Kuran: \(owner.displayName)")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                if let description = room.description {
                    Text(description)
                        .font(.body)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(16)
                        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
                }

                stats(room)

                people(room)
            }
            .padding(16)
        }
        .background(Color(.systemGroupedBackground))
        .safeAreaBar(edge: .bottom) {
            Button {
                dismiss()
                onJoin()
            } label: {
                Label(preview.isSeatedHere ? "Masana Dön" : "Odaya Katıl",
                      systemImage: preview.isSeatedHere ? "chair.lounge.fill" : "arrow.right.circle.fill")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .controlSize(.extraLarge)
            .fontWeight(.semibold)
            .padding(.horizontal, 16)
            .padding(.bottom, 8)
        }
    }

    private func stats(_ room: DiscoverRoom) -> some View {
        HStack(spacing: 0) {
            stat(value: "\(room.occupiedCount)", title: "Şu an çalışan", symbol: "circle.fill", tint: .green)
            Divider().frame(height: 36)
            stat(value: "\(room.memberCount)", title: "Üye", symbol: "person.2.fill", tint: .blue)
            Divider().frame(height: 36)
            stat(value: formattedFocus(room.weeklyFocusMs), title: "Bu hafta", symbol: "clock.fill", tint: .orange)
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
    }

    private func stat(value: String, title: LocalizedStringKey, symbol: String, tint: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Label(title, systemImage: symbol)
                .font(.caption)
                .foregroundStyle(.secondary)
                .labelStyle(TintedIconLabelStyle(tint: tint))
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func people(_ room: DiscoverRoom) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionTitle("Şu An Odada")
            if room.occupants.isEmpty {
                Text("Şu an kimse masada değil. İlk oturan sen ol.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(room.occupants.enumerated()), id: \.element.deskId) { index, occupant in
                        Button {
                            profileUserId = occupant.userId
                        } label: {
                            HStack(spacing: 12) {
                                Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: occupant.avatarSpriteId)), scale: 1)
                                    .resizable()
                                    .interpolation(.none)
                                    .frame(width: 28, height: 28)
                                    .frame(width: 40, height: 40)
                                    .background(.fill.tertiary, in: .circle)
                                Text(occupant.userName)
                                    .font(.body.weight(.medium))
                                Spacer()
                                Label(occupant.resting ? "Molada" : "Çalışıyor",
                                      systemImage: occupant.resting ? "cup.and.saucer.fill" : "circle.fill")
                                    .font(.caption)
                                    .foregroundStyle(occupant.resting ? .mint : .green)
                                if occupant.userId != nil {
                                    Image(systemName: "chevron.forward")
                                        .font(.footnote.weight(.semibold))
                                        .foregroundStyle(.tertiary)
                                }
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .contentShape(.rect)
                        }
                        .buttonStyle(.plain)
                        .disabled(occupant.userId == nil)
                        if index < room.occupants.count - 1 {
                            Divider().padding(.leading, 66)
                        }
                    }
                }
                .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 18))
            }
        }
    }

    private func load() async {
        do {
            preview = try await app.hall.preview(roomId)
        } catch {
            self.error = LibraryError(error)
        }
    }
}

/// A label whose icon takes its own colour while the title stays secondary.
private struct TintedIconLabelStyle: LabelStyle {
    let tint: Color

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: 4) {
            configuration.icon
                .foregroundStyle(tint)
                .imageScale(.small)
            configuration.title
        }
    }
}
