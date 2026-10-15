import SwiftUI

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

/// A settings row: colored icon and title.
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
                shape.fill(Color.accentColor.opacity(0.14))
                    .strokeBorder(Color.accentColor, lineWidth: 2)
            } else {
                shape.fill(.fill.tertiary)
            }
        }
    }
}
