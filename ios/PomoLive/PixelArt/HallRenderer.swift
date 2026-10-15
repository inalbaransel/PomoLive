import CoreGraphics

/// Bakes the static part of a hall (ground, backdrop, furniture) into one bitmap at 16 art pixels per tile.
/// Each room theme supplies its own `Scenery`; desks are drawn separately because they animate.
enum HallRenderer {
    static let tilePixels = 16

    static func render(_ layout: LibraryLayout) -> CGImage {
        let scenery = scenery(for: layout.roomTheme)
        let tile = tilePixels
        var canvas = PixelCanvas(width: layout.width * tile, height: layout.height * tile, fill: HallPalette.void)

        scenery.drawBackdrop(&canvas, width: layout.width * tile, height: layout.wallHeight * tile)
        for tileY in layout.wallHeight..<layout.height {
            for tileX in 0..<layout.width {
                scenery.drawGround(&canvas, tileX: tileX, tileY: tileY, isFirstRow: tileY == layout.wallHeight)
            }
        }
        for tileY in 0..<layout.height {
            for tileX in [0, layout.width - 1] {
                canvas.fill(x: tileX * tile, y: tileY * tile, width: tile, height: tile, scenery.edge)
            }
        }
        canvas.fill(x: 0, y: (layout.height - 1) * tile, width: layout.width * tile, height: tile, scenery.edge)

        let props = layout.props.sorted { ($0.kind.isGroundCover ? 0 : 1, $0.tileY) < ($1.kind.isGroundCover ? 0 : 1, $1.tileY) }
        for prop in props {
            let rect = PixelRect(x: prop.tileX * tile, y: prop.tileY * tile, width: prop.width * tile, height: prop.height * tile)
            let seed = prop.tileX * 31 + prop.tileY
            if !scenery.drawProp(prop.kind, on: &canvas, in: rect, seed: seed) {
                _ = LibraryScenery.drawProp(prop.kind, on: &canvas, in: rect, seed: seed)
            }
        }
        return canvas.makeImage()
    }

    private static func scenery(for theme: RoomTheme) -> any Scenery.Type {
        switch theme {
        case .classic: LibraryScenery.self
        case .coffeeShop: CafeScenery.self
        case .forest: ForestScenery.self
        case .space: SpaceScenery.self
        case .beach: BeachScenery.self
        }
    }
}
