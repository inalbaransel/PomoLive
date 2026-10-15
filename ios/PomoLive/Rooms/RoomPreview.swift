import SwiftUI

/// A look inside a room: a crop of the pixel floor plan framed around the people sitting there,
/// so their characters read clearly at card size. An empty room shows its middle.
struct RoomPreview: View {
    let layout: LibraryLayout
    let occupants: [RoomOccupant]

    /// The crop, in tiles: wide like a photo header.
    private static let window = CGSize(width: 18, height: 8)

    var body: some View {
        let floor = SpriteCache.shared.hall(layout)
        let seated = Dictionary(occupants.map { ($0.deskId, $0) }, uniquingKeysWith: { first, _ in first })
        let desks = layout.desks.map { desk in
            let occupant = seated[desk.deskId]
            let key = DeskSprite.Key(
                theme: layout.roomTheme,
                avatar: occupant.map { AvatarSprite(id: $0.avatarSpriteId) },
                phase: occupant?.resting == true ? .rest : .focus,
                frame: 0
            )
            return (desk: desk, image: SpriteCache.shared.desk(key))
        }
        let origin = cropOrigin(seated: seated)

        Canvas { context, size in
            let tile = size.width / Self.window.width
            context.translateBy(x: -origin.x * tile, y: -origin.y * tile)
            context.draw(
                Image(decorative: floor, scale: 1).interpolation(.none),
                in: CGRect(x: 0, y: 0, width: CGFloat(layout.width) * tile, height: CGFloat(layout.height) * tile)
            )
            for (desk, image) in desks {
                context.draw(
                    Image(decorative: image, scale: 1).interpolation(.none),
                    in: CGRect(x: CGFloat(desk.tileX) * tile, y: CGFloat(desk.tileY) * tile, width: tile * 2, height: tile * 2)
                )
            }
        }
        .aspectRatio(Self.window.width / Self.window.height, contentMode: .fit)
        .accessibilityHidden(true)
    }

    /// Top-left tile of the crop: centred on the seated readers, kept inside the floor.
    /// An empty room shows its back wall instead: windows, clock and shelves above the first desks.
    private func cropOrigin(seated: [String: RoomOccupant]) -> CGPoint {
        let maxX = CGFloat(layout.width) - Self.window.width
        let maxY = CGFloat(layout.height) - Self.window.height
        let occupied = layout.desks.filter { seated[$0.deskId] != nil }
        guard !occupied.isEmpty else { return CGPoint(x: (maxX / 2).rounded(), y: 0) }

        let centerX = occupied.map { CGFloat($0.tileX) + 1 }.reduce(0, +) / CGFloat(occupied.count)
        let centerY = occupied.map { CGFloat($0.tileY) + 1 }.reduce(0, +) / CGFloat(occupied.count)
        return CGPoint(
            x: min(max(centerX - Self.window.width / 2, 0), maxX).rounded(),
            y: min(max(centerY - Self.window.height / 2, 0), maxY).rounded()
        )
    }
}
