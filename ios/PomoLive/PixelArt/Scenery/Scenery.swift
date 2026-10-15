/// A tile-aligned rectangle in art pixels.
struct PixelRect {
    var x: Int
    var y: Int
    var width: Int
    var height: Int

    var midX: Int { x + width / 2 }
    var midY: Int { y + height / 2 }
    var maxX: Int { x + width }
    var maxY: Int { y + height }
}

/// The art of one room theme: the band along the top (wall, sky or treeline), the ground tiles,
/// the map's border and the props that only this theme has.
protocol Scenery {
    /// The colour of the map's outer border (left, right and bottom edge tiles).
    static var edge: PixelColor { get }

    /// Paints rows `0..<wallHeight` across the whole width in one go, so art may span tiles.
    static func drawBackdrop(_ canvas: inout PixelCanvas, width: Int, height: Int)

    static func drawGround(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isFirstRow: Bool)

    /// Draws `kind` if this theme has its own art for it; returns `false` to fall back to `LibraryScenery`.
    static func drawProp(_ kind: LayoutProp.Kind, on canvas: inout PixelCanvas, in rect: PixelRect, seed: Int) -> Bool
}

/// Cheap deterministic noise so scattered details (grass tufts, stars, pebbles) stay put between renders.
func pixelHash(_ x: Int, _ y: Int, _ salt: Int = 0) -> Int {
    var value = UInt32(truncatingIfNeeded: x &* 73_856_093 ^ y &* 19_349_663 ^ salt &* 83_492_791)
    value ^= value >> 13
    value = value &* 0x5BD1_E995
    value ^= value >> 15
    return Int(value & 0x7FFF_FFFF)
}
