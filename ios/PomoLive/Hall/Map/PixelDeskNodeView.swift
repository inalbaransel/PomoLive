import SwiftUI

/// One desk on the map. Occupied desks loop a two-frame typing or sipping animation.
struct PixelDeskNodeView: View {
    let desk: LayoutDesk
    let occupant: DeskRecord?

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

    private func spriteKey(at date: Date) -> DeskSprite.Key {
        guard let occupant else { return DeskSprite.Key(avatar: nil, status: .focus, frame: 0) }
        let speed = occupant.status == .focus ? 0.45 : 1.35
        let frame = Int(date.timeIntervalSinceReferenceDate / speed) % 2
        return DeskSprite.Key(avatar: AvatarSprite(id: occupant.avatarSpriteId), status: occupant.status, frame: frame)
    }

    private var accessibilityLabel: String {
        guard let occupant else { return "Masa \(desk.number), boş" }
        let state = occupant.status == .focus ? "odaklanıyor" : "molada"
        return "Masa \(desk.number), \(occupant.userName) \(state), \(occupant.taskLabel)"
    }
}
