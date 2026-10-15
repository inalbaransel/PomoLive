import SwiftUI

/// The running session above the tab bar, like Music's mini player. Tap to return to the desk.
struct SeatAccessoryView: View {
    let onOpen: () -> Void

    @Environment(AppModel.self) private var app
    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    var body: some View {
        if let desk = app.seat.desk {
            Button(action: onOpen) {
                HStack(spacing: 10) {
                    GlyphIcon(symbol: desk.category.symbol, color: desk.category.color, size: 28)
                    if placement != .inline {
                        VStack(alignment: .leading, spacing: 0) {
                            Text(desk.category.displayName)
                                .font(.subheadline.weight(.semibold))
                            Text(app.seat.room?.displayName ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    TimerText(timer: desk.timer, clock: app.time.clock)
                        .font(.system(.headline, design: .rounded))
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Masana döner")
        }
    }
}
