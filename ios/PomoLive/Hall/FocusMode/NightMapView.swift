import SwiftUI

/// The room after lights-out: pure black, every desk a faint outline, and only the desks with
/// someone at them lit by their lamp. The reader's own desk glows in the clock's tint.
/// Mostly-black pixels keep an OLED panel nearly off, so this is the battery-friendly mode.
struct NightMapView: View {
    let layout: LibraryLayout
    let desks: [String: DeskRecord]
    let myUserId: String?
    let tint: Color

    var body: some View {
        // The glow breathes slowly; a low frame rate is plenty and spares the battery.
        TimelineView(.periodic(from: .now, by: 1.0 / 8)) { timeline in
            let breath = (sin(timeline.date.timeIntervalSinceReferenceDate * 0.8) + 1) / 2
            Canvas { context, size in
                let tile = min(size.width / CGFloat(layout.width), size.height / CGFloat(layout.height))
                let origin = CGPoint(
                    x: (size.width - tile * CGFloat(layout.width)) / 2,
                    y: (size.height - tile * CGFloat(layout.height)) / 2
                )
                func rect(_ desk: LayoutDesk) -> CGRect {
                    CGRect(x: origin.x + CGFloat(desk.tileX) * tile, y: origin.y + CGFloat(desk.tileY) * tile,
                           width: tile * 2, height: tile * 2)
                }

                for desk in layout.desks where desks[desk.deskId] == nil {
                    context.stroke(Path(roundedRect: rect(desk).insetBy(dx: tile * 0.3, dy: tile * 0.5), cornerRadius: 2),
                                   with: .color(.white.opacity(0.06)), lineWidth: 1)
                }

                for desk in layout.desks {
                    guard let occupant = desks[desk.deskId] else { continue }
                    let frame = rect(desk)
                    let isMine = occupant.userId == myUserId
                    let resting = occupant.timer.reading(at: ServerClock.deviceNow()).phase == .rest
                    let glow = isMine ? tint : Color(red: 1, green: 0.74, blue: 0.4)
                    let strength = (resting ? 0.18 : 0.38) * (0.8 + 0.2 * breath) * (isMine ? 1.4 : 1)
                    let radius = tile * (isMine ? 3.4 : 2.6)
                    let center = CGPoint(x: frame.midX, y: frame.midY)
                    context.fill(
                        Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                        with: .radialGradient(Gradient(colors: [glow.opacity(strength), .clear]),
                                              center: center, startRadius: 0, endRadius: radius)
                    )
                    let sprite = SpriteCache.shared.desk(DeskSprite.Key(
                        theme: layout.roomTheme,
                        avatar: AvatarSprite(id: occupant.avatarSpriteId),
                        phase: resting ? .rest : .focus,
                        frame: 0
                    ))
                    var lit = context
                    lit.opacity = resting ? 0.45 : 0.8
                    lit.draw(Image(decorative: sprite, scale: 1).interpolation(.none), in: frame)
                }
            }
        }
        .accessibilityHidden(true)
    }
}
