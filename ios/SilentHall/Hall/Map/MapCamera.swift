import CoreGraphics
import Observation

/// Where the reader is looking: a zoom level and the screen position of the world's top-left corner.
@MainActor
@Observable
final class MapCamera {
    static let baseTile: CGFloat = 16
    static let zoomRange: ClosedRange<CGFloat> = 0.8...5
    private static let edgeMargin: CGFloat = 96

    var zoom: CGFloat = 1.4
    var offset: CGSize = .zero
    private(set) var viewport: CGSize = .zero
    private(set) var worldTiles: CGSize = .zero
    @ObservationIgnored private var hasFramedHall = false

    var tileSize: CGFloat { Self.baseTile * zoom }

    func configure(viewport: CGSize, worldTiles: CGSize) {
        self.viewport = viewport
        self.worldTiles = worldTiles
        if !hasFramedHall, viewport.width > 0, viewport.height > 0, worldTiles.width > 0 {
            hasFramedHall = true
            focus(onTile: CGPoint(x: worldTiles.width / 2, y: worldTiles.height / 2))
        } else {
            offset = clamped(offset, zoom: zoom)
        }
    }

    func pan(from start: CGSize, by translation: CGSize) {
        offset = clamped(CGSize(width: start.width + translation.width, height: start.height + translation.height), zoom: zoom)
    }

    /// Zooms around `anchor` (in screen points) so the spot under the fingers stays put.
    func zoom(from start: (zoom: CGFloat, offset: CGSize), by magnification: CGFloat, anchor: CGPoint) {
        let newZoom = min(max(start.zoom * magnification, Self.zoomRange.lowerBound), Self.zoomRange.upperBound)
        let ratio = newZoom / start.zoom
        let newOffset = CGSize(
            width: anchor.x - (anchor.x - start.offset.width) * ratio,
            height: anchor.y - (anchor.y - start.offset.height) * ratio
        )
        zoom = newZoom
        offset = clamped(newOffset, zoom: newZoom)
    }

    /// Centres a tile slightly above the middle of the screen, leaving room for the focus deck.
    func focus(onTile tile: CGPoint, zoom targetZoom: CGFloat? = nil) {
        let newZoom = targetZoom ?? zoom
        let tileSize = Self.baseTile * newZoom
        zoom = newZoom
        offset = clamped(
            CGSize(width: viewport.width / 2 - tile.x * tileSize, height: viewport.height * 0.42 - tile.y * tileSize),
            zoom: newZoom
        )
    }

    /// The visible part of the world, in tiles. Drives the mini-map viewport frame.
    var visibleTiles: CGRect {
        CGRect(
            x: -offset.width / tileSize,
            y: -offset.height / tileSize,
            width: viewport.width / tileSize,
            height: viewport.height / tileSize
        )
    }

    func clamped(_ offset: CGSize, zoom: CGFloat) -> CGSize {
        let world = CGSize(width: worldTiles.width * Self.baseTile * zoom, height: worldTiles.height * Self.baseTile * zoom)
        func axis(_ value: CGFloat, world: CGFloat, viewport: CGFloat) -> CGFloat {
            guard world + Self.edgeMargin * 2 > viewport else { return (viewport - world) / 2 }
            return min(max(value, viewport - world - Self.edgeMargin), Self.edgeMargin)
        }
        return CGSize(
            width: axis(offset.width, world: world.width, viewport: viewport.width),
            height: axis(offset.height, world: world.height, viewport: viewport.height)
        )
    }
}
