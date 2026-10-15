/// The classic reading room: green striped wallpaper, wooden parquet, bookshelves and a red runner.
/// Its furniture is also the fallback for props other themes reuse (plants, clocks, doors…).
enum LibraryScenery: Scenery {
    static let edge = HallPalette.wallTop

    static func drawBackdrop(_ canvas: inout PixelCanvas, width: Int, height: Int) {
        let tile = HallRenderer.tilePixels
        for tileY in 0..<(height / tile) {
            for tileX in 0..<(width / tile) {
                let x = tileX * tile
                let y = tileY * tile
                canvas.fill(x: x, y: y, width: tile, height: tile, HallPalette.wallpaper)
                for stripe in stride(from: 2, to: tile, by: 6) {
                    canvas.vLine(x: x + stripe, y: y, length: tile, HallPalette.wallpaperStripe)
                }
                if tileY == 0 { canvas.fill(x: x, y: y, width: tile, height: 3, HallPalette.wallTop) }
                if tileY == height / tile - 1 {
                    canvas.fill(x: x, y: y + 8, width: tile, height: 8, HallPalette.wainscot)
                    canvas.hLine(x: x, y: y + 8, length: tile, HallPalette.wainscotHighlight)
                    canvas.hLine(x: x, y: y + 15, length: tile, HallPalette.outline)
                }
            }
        }
    }

    static func drawGround(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isFirstRow: Bool) {
        drawPlanks(&canvas, tileX: tileX, tileY: tileY, tones: [HallPalette.floorLight, HallPalette.floorMid, HallPalette.floorDark], seam: HallPalette.floorSeam)
    }

    /// Staggered floorboards, shared with the café's darker floor.
    static func drawPlanks(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, tones: [PixelColor], seam: PixelColor) {
        let tile = HallRenderer.tilePixels
        for plank in 0..<4 {
            let y = tileY * tile + plank * 4
            canvas.fill(x: tileX * tile, y: y, width: tile, height: 4, tones[(tileY * 4 + plank + tileX) % tones.count])
            canvas.hLine(x: tileX * tile, y: y + 3, length: tile, seam)
            canvas.vLine(x: tileX * tile + (tileX * 7 + (tileY * 4 + plank) * 5) % tile, y: y, length: 3, seam)
        }
    }

    static func drawProp(_ kind: LayoutProp.Kind, on canvas: inout PixelCanvas, in rect: PixelRect, seed: Int) -> Bool {
        switch kind {
        case .rug: drawRug(&canvas, rect, base: HallPalette.rug, border: HallPalette.rugBorder, pattern: HallPalette.rugPattern)
        case .window: drawWindow(&canvas, rect)
        case .clock: drawClock(&canvas, rect)
        case .bookshelf: drawBookshelf(&canvas, rect, seed: seed)
        case .plant: drawPlant(&canvas, rect)
        case .coffeeMachine: drawCoffeeMachine(&canvas, rect)
        case .door: drawDoor(&canvas, rect)
        default: return false
        }
        return true
    }

    /// A bordered runner with diamonds down the middle, shared with the café's warmer one.
    static func drawRug(_ canvas: inout PixelCanvas, _ rect: PixelRect, base: PixelColor, border: PixelColor, pattern: PixelColor) {
        canvas.fill(x: rect.x, y: rect.y, width: rect.width, height: rect.height, base)
        canvas.stroke(x: rect.x + 2, y: rect.y + 2, width: rect.width - 4, height: rect.height - 4, border)
        canvas.stroke(x: rect.x + 4, y: rect.y + 4, width: rect.width - 8, height: rect.height - 8, pattern)
        for diamondY in stride(from: rect.y + 12, to: rect.maxY - 12, by: 16) {
            for offset in 0..<4 {
                canvas.hLine(x: rect.midX - offset, y: diamondY + offset, length: offset * 2 + 1, pattern)
                canvas.hLine(x: rect.midX - offset, y: diamondY + 6 - offset, length: offset * 2 + 1, pattern)
            }
        }
    }

    private static func drawWindow(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let (x, y, width, height) = (rect.x, rect.y, rect.width, rect.height)
        canvas.fill(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.windowFrame)
        canvas.fill(x: x + 4, y: y + 6, width: width - 8, height: height - 10, HallPalette.glass)
        for step in 0..<6 { canvas.set(x + 7 + step, y + 13 - step, HallPalette.glassShine) }
        canvas.vLine(x: rect.midX, y: y + 6, length: height - 10, HallPalette.windowFrame)
        canvas.hLine(x: x + 4, y: rect.midY + 1, length: width - 8, HallPalette.windowFrame)
        canvas.stroke(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.outline)
    }

    private static func drawClock(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let size = min(rect.width, rect.height)
        let center = Double(size) / 2
        let centerX = Double(rect.x) + center
        let centerY = Double(rect.y) + center + 2
        canvas.disc(centerX: centerX, centerY: centerY, radius: center - 3, HallPalette.outline)
        canvas.disc(centerX: centerX, centerY: centerY, radius: center - 4, HallPalette.woodDark)
        canvas.disc(centerX: centerX, centerY: centerY, radius: center - 6, HallPalette.paper)
        let middleX = rect.x + size / 2
        let middleY = rect.y + size / 2 + 2
        canvas.vLine(x: middleX, y: middleY - 7, length: 7, HallPalette.outline)
        canvas.hLine(x: middleX, y: middleY, length: 5, HallPalette.outline)
        canvas.set(middleX, middleY, HallPalette.rug)
    }

    private static func drawBookshelf(_ canvas: inout PixelCanvas, _ rect: PixelRect, seed: Int) {
        let (x, y, width, height) = (rect.x, rect.y, rect.width, rect.height)
        canvas.fill(x: x, y: y, width: width, height: height, HallPalette.woodDark)
        canvas.stroke(x: x, y: y, width: width, height: height, HallPalette.outline)
        let shelfHeight = (height - 4) / 3
        var random = UInt32(truncatingIfNeeded: seed &* 2_654_435_761)
        for shelf in 0..<3 {
            let shelfY = y + 2 + shelf * shelfHeight
            canvas.fill(x: x + 2, y: shelfY, width: width - 4, height: shelfHeight - 1, HallPalette.void)
            var bookX = x + 2
            while bookX < x + width - 3 {
                random = random &* 1_103_515_245 &+ 12345
                let bookWidth = 2 + Int(random >> 28) % 2
                let bookHeight = shelfHeight - 2 - Int(random >> 24) % 3
                let color = HallPalette.bookSpines[Int(random >> 16) % HallPalette.bookSpines.count]
                canvas.fill(x: bookX, y: shelfY + shelfHeight - 1 - bookHeight, width: bookWidth, height: bookHeight, color)
                bookX += bookWidth
            }
            canvas.hLine(x: x + 1, y: shelfY + shelfHeight - 1, length: width - 2, HallPalette.wood)
        }
    }

    private static func drawPlant(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let (x, y) = (rect.x, rect.y)
        canvas.fill(x: x + 4, y: y + 10, width: 8, height: 6, HallPalette.pot)
        canvas.hLine(x: x + 3, y: y + 10, length: 10, HallPalette.outline)
        canvas.disc(centerX: Double(x) + 8, centerY: Double(y) + 6, radius: 5.5, HallPalette.leaf)
        canvas.disc(centerX: Double(x) + 6, centerY: Double(y) + 4, radius: 2.5, HallPalette.leafLight)
        canvas.disc(centerX: Double(x) + 11, centerY: Double(y) + 7, radius: 2, HallPalette.leafLight)
    }

    private static func drawCoffeeMachine(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let (x, y) = (rect.x, rect.y)
        canvas.fill(x: x + 1, y: y + 2, width: 14, height: 28, HallPalette.metal)
        canvas.stroke(x: x + 1, y: y + 2, width: 14, height: 28, HallPalette.outline)
        canvas.fill(x: x + 3, y: y + 4, width: 10, height: 5, HallPalette.rug)
        canvas.hLine(x: x + 4, y: y + 6, length: 8, HallPalette.lampGold)
        canvas.fill(x: x + 4, y: y + 12, width: 8, height: 10, HallPalette.void)
        canvas.fill(x: x + 6, y: y + 17, width: 4, height: 4, HallPalette.paper)
        canvas.fill(x: x + 3, y: y + 24, width: 10, height: 2, HallPalette.metalLight)
    }

    private static func drawDoor(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.fill(x: rect.x, y: rect.y, width: rect.width, height: rect.height, HallPalette.wood)
        canvas.vLine(x: rect.midX, y: rect.y, length: rect.height, HallPalette.outline)
        canvas.stroke(x: rect.x, y: rect.y, width: rect.width, height: rect.height, HallPalette.outline)
        canvas.set(rect.midX - 2, rect.midY, HallPalette.lampGold)
        canvas.set(rect.midX + 1, rect.midY, HallPalette.lampGold)
    }
}
