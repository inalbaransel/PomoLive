import SwiftUI

/// The palette for room and category icons. Raw values match the server's `GLYPH_COLORS`.
enum GlyphColor: String, CaseIterable, Codable, Hashable, Sendable, Identifiable {
    case red, orange, yellow, green, mint, teal, blue, indigo, purple, pink, brown, gray

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .gray: .gray
        }
    }

    /// Unknown values from a newer server fall back to the brand color instead of failing to decode.
    init(from decoder: any Decoder) throws {
        self = GlyphColor(rawValue: try decoder.singleValueContainer().decode(String.self)) ?? .indigo
    }
}

/// SF Symbols readers can give rooms and categories. Matches the server's `GLYPH_SYMBOLS`.
enum GlyphCatalog {
    static let symbols = [
        "chevron.left.forwardslash.chevron.right", "laptopcomputer", "graduationcap.fill", "book.fill",
        "books.vertical.fill", "pencil.line", "paintpalette.fill", "character.bubble.fill",
        "briefcase.fill", "square.grid.2x2.fill", "brain.head.profile.fill", "lightbulb.fill",
        "function", "flask.fill", "atom", "globe.europe.africa.fill",
        "music.note", "guitars.fill", "pianokeys", "camera.fill",
        "headphones", "chart.bar.fill", "leaf.fill", "moon.stars.fill",
        "sun.max.fill", "cup.and.saucer.fill", "flame.fill", "bolt.fill",
        "target", "star.fill", "heart.fill", "figure.run",
        "dumbbell.fill", "building.columns.fill", "house.fill", "sparkles",
    ]
}

/// A white symbol on a colored circle, like the list icons in Reminders.
struct GlyphIcon: View {
    let symbol: String
    let color: GlyphColor
    var size: CGFloat = 36

    var body: some View {
        Image(systemName: symbol)
            .font(.system(size: size * 0.44, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: size, height: size)
            .background(color.color.gradient, in: .circle)
            .accessibilityHidden(true)
    }
}
