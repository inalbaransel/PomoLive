import SwiftUI

/// Retro radar: the whole hall in miniature, readers as dots and the visible area as a frame. Tap to jump.
struct MiniMapView: View {
    let layout: LibraryLayout
    let desks: [String: DeskRecord]
    let myUserId: String?
    let camera: MapCamera

    private let width: CGFloat = 104

    var body: some View {
        let scale = width / CGFloat(layout.width)
        let height = CGFloat(layout.height) * scale

        Canvas { context, size in
            context.draw(Image(decorative: SpriteCache.shared.hall(layout), scale: 1).interpolation(.none), in: CGRect(origin: .zero, size: size))
            for desk in desks.values {
                let dot = CGRect(x: (CGFloat(desk.tileX) + 0.5) * scale, y: CGFloat(desk.tileY) * scale, width: scale * 1.6, height: scale * 1.6)
                let color: Color = desk.userId == myUserId ? .accentColor : desk.status == .focus ? .green : .orange
                context.fill(Path(dot), with: .color(color))
            }
            let visible = camera.visibleTiles
            let frame = CGRect(x: visible.minX * scale, y: visible.minY * scale, width: visible.width * scale, height: visible.height * scale)
            context.stroke(Path(frame), with: .color(.white), lineWidth: 1.5)
        }
        .frame(width: width, height: height)
            .clipShape(.rect(cornerRadius: 8))
            .padding(6)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 14))
            .contentShape(.rect)
            .onTapGesture { location in
                withAnimation(.spring(duration: 0.55, bounce: 0.2)) {
                    camera.focus(onTile: CGPoint(x: (location.x - 6) / scale, y: (location.y - 6) / scale))
                }
            }
            .accessibilityLabel("Salon haritası")
            .accessibilityHint("Dokunduğun bölgeye gider")
    }
}
