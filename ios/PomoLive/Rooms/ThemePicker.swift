import SwiftUI

/// Picks a room's look from live previews of each map, swiped through like a carousel.
struct ThemePicker: View {
    @Binding var selection: RoomTheme
    /// Floor plans by theme raw value, as the server sends them with the room lists.
    let layouts: [String: LibraryLayout]
    /// A theme the room already has stays available even without Plus.
    var kept: RoomTheme?

    @Environment(AppModel.self) private var app
    @State private var showsPaywall = false

    private func isLocked(_ theme: RoomTheme) -> Bool {
        !app.plus.isActive && PlusCatalog.themes.contains(theme) && theme != kept
    }

    private static let cardWidth: CGFloat = 220

    var body: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(RoomTheme.allCases) { theme in
                    card(for: theme)
                        .id(theme)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned)
        .scrollIndicators(.hidden)
        .contentMargins(.horizontal, 20, for: .scrollContent)
        .scrollPosition(id: Binding(get: { selection }, set: { _ in }), anchor: .center)
        .sensoryFeedback(.selection, trigger: selection)
        .plusPaywall(isPresented: $showsPaywall)
    }

    private func card(for theme: RoomTheme) -> some View {
        let isSelected = theme == selection
        return Button {
            if isLocked(theme) { return showsPaywall = true }
            withAnimation(.snappy) { selection = theme }
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                preview(for: theme)
                    .clipShape(.rect(cornerRadius: 16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 16)
                            .strokeBorder(isSelected ? Color.accentColor : Color.primary.opacity(0.08), lineWidth: isSelected ? 3 : 1)
                    }
                    .overlay(alignment: .topLeading) {
                        if isLocked(theme) { PlusBadge().padding(8) }
                    }
                    .overlay(alignment: .topTrailing) {
                        if isSelected {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.title3)
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, Color.accentColor)
                                .padding(8)
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                VStack(alignment: .leading, spacing: 2) {
                    Text(theme.displayName)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(isSelected ? Color.accentColor : .primary)
                    Text(theme.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2, reservesSpace: true)
                }
                .padding(.horizontal, 4)
            }
            .frame(width: Self.cardWidth)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    @ViewBuilder
    private func preview(for theme: RoomTheme) -> some View {
        if let layout = layouts[theme.rawValue] {
            RoomPreview(layout: layout, occupants: [])
        } else {
            Rectangle()
                .fill(.fill.tertiary)
                .aspectRatio(18 / 8, contentMode: .fit)
                .overlay { ProgressView() }
        }
    }
}
