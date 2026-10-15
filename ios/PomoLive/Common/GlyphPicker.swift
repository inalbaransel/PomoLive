import SwiftUI

/// Pick a color and a symbol for a room or category, as in Reminders' list editor.
struct GlyphPicker: View {
    @Binding var symbol: String
    @Binding var color: GlyphColor

    var body: some View {
        Section("Renk") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                ForEach(GlyphColor.allCases) { option in
                    Button { color = option } label: {
                        Circle()
                            .fill(option.color.gradient)
                            .frame(width: 36, height: 36)
                            .padding(4)
                            .background {
                                if option == color {
                                    Circle().strokeBorder(Color.secondary.opacity(0.5), lineWidth: 2.5)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.accessibilityName)
                    .accessibilityAddTraits(option == color ? .isSelected : [])
                }
            }
            .padding(.vertical, 6)
        }

        Section("Simge") {
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 6), spacing: 14) {
                ForEach(GlyphCatalog.symbols, id: \.self) { option in
                    Button { symbol = option } label: {
                        Image(systemName: option)
                            .font(.system(size: 17, weight: .medium))
                            .foregroundStyle(option == symbol ? color.color : .secondary)
                            .frame(width: 44, height: 44)
                            .selectableBackground(option == symbol, in: .circle)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option)
                    .accessibilityAddTraits(option == symbol ? .isSelected : [])
                }
            }
            .padding(.vertical, 6)
        }
        .animation(.snappy, value: symbol)
        .animation(.snappy, value: color)
    }
}
