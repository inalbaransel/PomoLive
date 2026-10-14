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
                    Image(decorative: SpriteCache.shared.avatar(AvatarSprite(id: desk.avatarSpriteId)), scale: 1)
                        .resizable()
                        .interpolation(.none)
                        .frame(width: 26, height: 26)
                    if placement != .inline {
                        VStack(alignment: .leading, spacing: 0) {
                            Text("\(desk.category.emoji) \(desk.category.name)")
                                .font(.subheadline.weight(.semibold))
                            Text(app.seat.room?.name ?? "")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .lineLimit(1)
                    }
                    Spacer(minLength: 0)
                    TimerText(timer: desk.timer, clock: app.time.clock)
                        .font(.system(.headline, design: .monospaced))
                }
                .padding(.horizontal, 16)
            }
            .buttonStyle(.plain)
            .accessibilityHint("Masana döner")
        }
    }
}
