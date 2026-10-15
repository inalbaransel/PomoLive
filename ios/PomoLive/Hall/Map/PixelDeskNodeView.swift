import SwiftUI

/// One desk on the map. Occupied desks loop a two-frame typing (focus) or sipping (break) animation.
struct PixelDeskNodeView: View {
    let desk: LayoutDesk
    let occupant: DeskRecord?
    let clock: ServerClock

    var body: some View {
        TimelineView(.periodic(from: .now, by: 0.45)) { timeline in
            Image(decorative: SpriteCache.shared.desk(spriteKey(at: timeline.date)), scale: 1)
                .resizable()
                .interpolation(.none)
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(.isButton)
    }

    private var phase: TimerPhase {
        occupant?.timer.reading(at: clock.now).phase ?? .focus
    }

    private func spriteKey(at date: Date) -> DeskSprite.Key {
        guard let occupant else { return DeskSprite.Key(avatar: nil, phase: .focus, frame: 0) }
        let speed = phase == .focus ? 0.45 : 1.35
        let frame = Int(date.timeIntervalSinceReferenceDate / speed) % 2
        return DeskSprite.Key(avatar: AvatarSprite(id: occupant.avatarSpriteId), phase: phase, frame: frame)
    }

    private var accessibilityLabel: String {
        guard let occupant else { return String(localized: "Masa \(desk.number), boş") }
        return phase == .focus
            ? String(localized: "Masa \(desk.number), \(occupant.userName) odaklanıyor, \(occupant.category.displayName)")
            : String(localized: "Masa \(desk.number), \(occupant.userName) molada, \(occupant.category.displayName)")
    }
}
