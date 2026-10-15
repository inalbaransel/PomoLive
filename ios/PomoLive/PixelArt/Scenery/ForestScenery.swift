import Foundation

/// A clearing in the woods: a dense treeline at the back, grass underfoot, a dirt path down the
/// middle, trees along the sides, a campfire and a pond.
enum ForestScenery: Scenery {
    private enum Palette {
        static let sky = PixelColor(0xA8DCEFFF)
        static let grass = PixelColor(0x5A9E4BFF)
        static let grassAlt = PixelColor(0x529444FF)
        static let grassLight = PixelColor(0x7BC060FF)
        static let grassDark = PixelColor(0x3E7A36FF)
        static let shadow = PixelColor(0x1F3A1F55)

        static let dirt = PixelColor(0xA47A4CFF)
        static let dirtLight = PixelColor(0xBC9262FF)
        static let dirtDark = PixelColor(0x82603AFF)

        static let trunk = PixelColor(0x7A5332FF)
        static let trunkDark = PixelColor(0x553820FF)
        static let ring = PixelColor(0xD2A872FF)
        static let canopyDeep = PixelColor(0x1E4A2AFF)
        static let canopyDark = PixelColor(0x2B6337FF)
        static let canopy = PixelColor(0x3C8445FF)
        static let canopyLight = PixelColor(0x5DAA5CFF)

        static let petals: [PixelColor] = [
            PixelColor(0xF2F0E6FF), PixelColor(0xF6D44AFF), PixelColor(0xE86A8AFF), PixelColor(0xA98BE8FF),
        ]
        static let petalCenter = PixelColor(0xF29F3AFF)

        static let cap = PixelColor(0xD0433AFF)
        static let capShade = PixelColor(0x9A2C26FF)
        static let spot = PixelColor(0xFAF3E6FF)
        static let stem = PixelColor(0xEDE3CFFF)

        static let stone = PixelColor(0x8D939BFF)
        static let stoneDark = PixelColor(0x60656DFF)
        static let log = PixelColor(0x8A5A34FF)
        static let flame = PixelColor(0xF2862EFF)
        static let flameCore = PixelColor(0xFFD45AFF)
        static let glow = PixelColor(0xFFB04A30)

        static let water = PixelColor(0x3E86C2FF)
        static let waterDeep = PixelColor(0x2E6AA0FF)
        static let waterLight = PixelColor(0x8CC8EEFF)
        static let lily = PixelColor(0x4FA34EFF)
        static let lilyFlower = PixelColor(0xF4A6C0FF)
    }

    static let edge = Palette.canopyDeep

    // MARK: Backdrop & ground

    /// A wall of trees: trunks in the shade, overlapping crowns, bushes along the bottom.
    static func drawBackdrop(_ canvas: inout PixelCanvas, width: Int, height: Int) {
        canvas.fill(x: 0, y: 0, width: width, height: height, Palette.canopyDeep)
        canvas.fill(x: 0, y: 0, width: width, height: 6, Palette.sky)
        for trunkX in stride(from: 4, to: width, by: 18) {
            canvas.fill(x: trunkX + pixelHash(trunkX, 1) % 6, y: 18, width: 5, height: height - 18, Palette.trunkDark)
        }
        for (row, centerY) in [(0, 12), (1, 22)] {
            for crownX in stride(from: -6, to: width + 12, by: 13) {
                let jitter = pixelHash(crownX, row) % 7 - 3
                let x = Double(crownX + jitter + row * 6)
                let y = Double(centerY + jitter / 2)
                canvas.disc(centerX: x, centerY: y, radius: 11, Palette.canopyDark)
                canvas.disc(centerX: x - 1, centerY: y - 1, radius: 9, row == 0 ? Palette.canopyDark : Palette.canopy)
                canvas.disc(centerX: x - 3, centerY: y - 4, radius: 3.5, Palette.canopyLight)
            }
        }
        canvas.fill(x: 0, y: height - 8, width: width, height: 8, Palette.grassDark)
        for bushX in stride(from: 0, to: width, by: 10) {
            canvas.disc(centerX: Double(bushX + pixelHash(bushX, 7) % 5), centerY: Double(height - 7), radius: 5.5, Palette.canopy)
            canvas.disc(centerX: Double(bushX + 2), centerY: Double(height - 9), radius: 2, Palette.canopyLight)
        }
    }

    static func drawGround(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isFirstRow: Bool) {
        let tile = HallRenderer.tilePixels
        let x = tileX * tile
        let y = tileY * tile
        canvas.fill(x: x, y: y, width: tile, height: tile, (tileX + tileY) % 2 == 0 ? Palette.grass : Palette.grassAlt)
        for tuft in 0..<3 {
            let hash = pixelHash(tileX, tileY, tuft)
            let tuftX = x + hash % (tile - 3)
            let tuftY = y + (hash / 16) % (tile - 3) + 2
            let color = tuft == 0 ? Palette.grassDark : Palette.grassLight
            canvas.set(tuftX, tuftY, color)
            canvas.set(tuftX + 2, tuftY, color)
            canvas.set(tuftX + 1, tuftY - 1, color)
        }
        if isFirstRow { canvas.fill(x: x, y: y, width: tile, height: 3, Palette.shadow) }
    }

    // MARK: Props

    static func drawProp(_ kind: LayoutProp.Kind, on canvas: inout PixelCanvas, in rect: PixelRect, seed: Int) -> Bool {
        switch kind {
        case .path: drawPath(&canvas, rect)
        case .tree: drawTree(&canvas, rect)
        case .bush: drawBush(&canvas, rect)
        case .flowers: drawFlowers(&canvas, rect, seed: seed)
        case .mushroom: drawMushroom(&canvas, rect)
        case .campfire: drawCampfire(&canvas, rect)
        case .stump: drawStump(&canvas, rect)
        case .pond: drawPond(&canvas, rect)
        default: return false
        }
        return true
    }

    /// Packed earth with ragged grassy edges and a few pebbles.
    private static func drawPath(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        for row in rect.y..<rect.maxY {
            let left = rect.x + 4 + pixelHash(row / 3, 11) % 4
            let right = rect.maxX - 4 - pixelHash(row / 3, 12) % 4
            canvas.hLine(x: left, y: row, length: right - left, Palette.dirt)
            canvas.set(left, row, Palette.dirtDark)
            canvas.set(right - 1, row, Palette.dirtDark)
        }
        for pebble in 0..<(rect.height / 6) {
            let hash = pixelHash(rect.x, pebble, 3)
            let pebbleX = rect.x + 10 + hash % max(1, rect.width - 20)
            let pebbleY = rect.y + pebble * 6 + hash % 5
            canvas.set(pebbleX, pebbleY, hash % 3 == 0 ? Palette.dirtDark : Palette.dirtLight)
            canvas.set(pebbleX + 1, pebbleY, Palette.dirtLight)
        }
    }

    /// A round crown on a short trunk, with its shadow on the grass.
    private static func drawTree(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let centerX = Double(rect.midX)
        canvas.ellipse(centerX: centerX + 2, centerY: Double(rect.maxY - 4), radiusX: 13, radiusY: 4, Palette.shadow)
        canvas.fill(x: rect.midX - 3, y: rect.maxY - 20, width: 6, height: 17, Palette.trunk)
        canvas.vLine(x: rect.midX - 3, y: rect.maxY - 20, length: 17, Palette.trunkDark)
        canvas.hLine(x: rect.midX - 4, y: rect.maxY - 4, length: 8, Palette.trunkDark)
        let crownY = Double(rect.y) + 16
        canvas.disc(centerX: centerX, centerY: crownY, radius: 15, Palette.canopyDeep)
        canvas.disc(centerX: centerX - 1, centerY: crownY - 1, radius: 13.5, Palette.canopyDark)
        canvas.disc(centerX: centerX - 2, centerY: crownY - 2, radius: 10.5, Palette.canopy)
        canvas.disc(centerX: centerX - 6, centerY: crownY - 6, radius: 4, Palette.canopyLight)
        canvas.disc(centerX: centerX + 5, centerY: crownY - 1, radius: 2.5, Palette.canopyLight)
    }

    private static func drawBush(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let baseY = Double(rect.maxY - 9)
        canvas.ellipse(centerX: Double(rect.midX), centerY: Double(rect.maxY - 3), radiusX: 14, radiusY: 3, Palette.shadow)
        for (offsetX, offsetY, radius) in [(-7.0, 0.0, 8.0), (7.0, 0.0, 8.0), (0.0, -5.0, 9.0)] {
            canvas.disc(centerX: Double(rect.midX) + offsetX, centerY: baseY + offsetY, radius: radius, Palette.canopyDark)
            canvas.disc(centerX: Double(rect.midX) + offsetX - 1, centerY: baseY + offsetY - 1, radius: radius - 2, Palette.canopy)
        }
        canvas.disc(centerX: Double(rect.midX) - 3, centerY: baseY - 9, radius: 3, Palette.canopyLight)
        for berry in [(-6, -2), (5, -6), (8, 2)] {
            canvas.set(rect.midX + berry.0, Int(baseY) + berry.1, Palette.cap)
        }
    }

    private static func drawFlowers(_ canvas: inout PixelCanvas, _ rect: PixelRect, seed: Int) {
        for flower in 0..<3 {
            let hash = pixelHash(seed, flower, 5)
            let x = rect.x + 3 + hash % 10
            let y = rect.y + 4 + (hash / 16) % 8
            let petal = Palette.petals[(hash / 256) % Palette.petals.count]
            canvas.vLine(x: x, y: y + 1, length: 3, Palette.grassDark)
            canvas.set(x - 1, y, petal)
            canvas.set(x + 1, y, petal)
            canvas.set(x, y - 1, petal)
            canvas.set(x, y + 1, petal)
            canvas.set(x, y, Palette.petalCenter)
        }
    }

    private static func drawMushroom(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.stamp([
            "................",
            "................",
            "................",
            "......RRRR......",
            "....RRWRRRRR....",
            "...RRRRRRWRRR...",
            "..RWRRRRRRRRWR..",
            "..RRRRWRRRRRRR..",
            "..DDDDDDDDDDDD..",
            "......SSSS......",
            "......SSSS......",
            "......SSSS......",
            ".....SSSSSS.....",
            "....GGGGGGGG....",
            "................",
            "................",
        ], x: rect.x, y: rect.y, palette: [
            "R": Palette.cap, "W": Palette.spot, "D": Palette.capShade, "S": Palette.stem, "G": Palette.shadow,
        ])
    }

    /// Crossed logs in a ring of stones, with a flame and its warm glow.
    private static func drawCampfire(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let centerX = Double(rect.midX)
        let centerY = Double(rect.midY + 4)
        canvas.disc(centerX: centerX, centerY: centerY - 2, radius: 15, Palette.glow)
        for step in 0..<10 {
            let angle = Double(step) / 10 * 2 * .pi
            let stoneX = centerX + cos(angle) * 10
            let stoneY = centerY + sin(angle) * 6
            canvas.disc(centerX: stoneX, centerY: stoneY, radius: 2.5, Palette.stoneDark)
            canvas.disc(centerX: stoneX - 0.5, centerY: stoneY - 0.5, radius: 1.6, Palette.stone)
        }
        for offset in 0..<10 {
            canvas.fill(x: rect.midX - 6 + offset, y: Int(centerY) - 1 + offset / 3, width: 2, height: 2, Palette.log)
            canvas.fill(x: rect.midX + 5 - offset, y: Int(centerY) - 1 + offset / 3, width: 2, height: 2, Palette.trunkDark)
        }
        canvas.ellipse(centerX: centerX, centerY: centerY - 4, radiusX: 4.5, radiusY: 7, Palette.flame)
        canvas.ellipse(centerX: centerX, centerY: centerY - 2, radiusX: 2.5, radiusY: 4, Palette.flameCore)
        canvas.set(rect.midX - 4, Int(centerY) - 10, Palette.flame)
        canvas.set(rect.midX + 3, Int(centerY) - 12, Palette.flameCore)
    }

    private static func drawStump(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.ellipse(centerX: Double(rect.midX), centerY: Double(rect.y + 13), radiusX: 7, radiusY: 2.5, Palette.shadow)
        canvas.fill(x: rect.x + 3, y: rect.y + 6, width: 10, height: 7, Palette.trunk)
        canvas.vLine(x: rect.x + 3, y: rect.y + 6, length: 7, Palette.trunkDark)
        canvas.vLine(x: rect.x + 12, y: rect.y + 6, length: 7, Palette.trunkDark)
        canvas.ellipse(centerX: Double(rect.midX), centerY: Double(rect.y + 6), radiusX: 5, radiusY: 2.5, Palette.ring)
        canvas.ellipse(centerX: Double(rect.midX), centerY: Double(rect.y + 6), radiusX: 2.5, radiusY: 1.2, Palette.trunk)
    }

    /// An oval pond with a stony rim, lily pads and a glint of sky.
    private static func drawPond(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let centerX = Double(rect.midX)
        let centerY = Double(rect.midY)
        let radiusX = Double(rect.width) / 2 - 2
        let radiusY = Double(rect.height) / 2 - 2
        canvas.ellipse(centerX: centerX, centerY: centerY, radiusX: radiusX + 2, radiusY: radiusY + 2, Palette.stoneDark)
        canvas.ellipse(centerX: centerX, centerY: centerY - 0.5, radiusX: radiusX + 1, radiusY: radiusY + 1, Palette.stone)
        canvas.ellipse(centerX: centerX, centerY: centerY, radiusX: radiusX, radiusY: radiusY, Palette.water)
        canvas.ellipse(centerX: centerX + 3, centerY: centerY + 3, radiusX: radiusX - 6, radiusY: radiusY - 6, Palette.waterDeep)
        for (x, y, length) in [(-12, -8, 6), (4, -10, 4), (-4, 6, 5)] {
            canvas.hLine(x: rect.midX + x, y: rect.midY + y, length: length, Palette.waterLight)
        }
        for (x, y) in [(-14.0, 2.0), (10.0, -4.0), (14.0, 8.0)] {
            canvas.disc(centerX: centerX + x, centerY: centerY + y, radius: 3, Palette.lily)
            canvas.set(rect.midX + Int(x), rect.midY + Int(y) - 1, Palette.lilyFlower)
        }
    }
}
