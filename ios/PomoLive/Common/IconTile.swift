import SwiftUI

/// An emoji on a soft rounded square, like the list icons in Reminders and Shortcuts.
struct EmojiTile: View {
    let emoji: String
    var size: CGFloat = 40

    var body: some View {
        Text(emoji)
            .font(.system(size: size * 0.55))
            .frame(width: size, height: size)
            .background(.fill.tertiary, in: .rect(cornerRadius: size * 0.27))
            .accessibilityHidden(true)
    }
}

/// A white symbol on a colored rounded square, like the rows in Settings.
struct SettingsIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.system(size: 15, weight: .semibold))
            .foregroundStyle(.white)
            .frame(width: 29, height: 29)
            .background(color.gradient, in: .rect(cornerRadius: 7))
            .accessibilityHidden(true)
    }
}

/// A settings row: colored icon, title, and optional trailing content.
struct SettingsLabel: View {
    let title: String
    let systemName: String
    let color: Color

    var body: some View {
        Label {
            Text(title)
        } icon: {
            SettingsIcon(systemName: systemName, color: color)
        }
    }
}

extension View {
    /// Selection look for pickable tiles and chips: a quiet fill, or an accent ring when chosen.
    func selectableBackground<S: InsettableShape>(_ isSelected: Bool, in shape: S) -> some View {
        background {
            if isSelected {
                shape.fill(Color.accentColor.opacity(0.18))
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            } else {
                shape.fill(.fill.tertiary)
            }
        }
    }
}
