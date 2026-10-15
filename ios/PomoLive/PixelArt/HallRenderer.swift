import CoreGraphics

/// Bakes the static part of a hall (floor, walls, furniture) into one bitmap at 16 art pixels per tile.
/// Desks are drawn separately because they animate.
enum HallRenderer {
    static let tilePixels = 16

    static func render(_ layout: LibraryLayout) -> CGImage {
        let tile = tilePixels
        let isCoffeeShop = layout.roomTheme == .coffeeShop
        var canvas = PixelCanvas(width: layout.width * tile, height: layout.height * tile, fill: HallPalette.void)

        for tileY in 0..<layout.height {
            for tileX in 0..<layout.width {
                let isEdge = tileX == 0 || tileX == layout.width - 1 || tileY == layout.height - 1
                if isEdge {
                    canvas.fill(x: tileX * tile, y: tileY * tile, width: tile, height: tile, isCoffeeShop ? HallPalette.cafeWallTop : HallPalette.wallTop)
                } else if tileY < layout.wallHeight {
                    if isCoffeeShop {
                        drawCoffeeWall(&canvas, tileX: tileX, tileY: tileY, isBaseRow: tileY == layout.wallHeight - 1)
                    } else {
                        drawWall(&canvas, tileX: tileX, tileY: tileY, isBaseRow: tileY == layout.wallHeight - 1)
                    }
                } else {
                    if isCoffeeShop {
                        drawCoffeeFloor(&canvas, tileX: tileX, tileY: tileY)
                    } else {
                        drawFloor(&canvas, tileX: tileX, tileY: tileY)
                    }
                }
            }
        }

        for prop in layout.props.sorted(by: { ($0.kind == .rug ? 0 : 1, $0.tileY) < ($1.kind == .rug ? 0 : 1, $1.tileY) }) {
            let x = prop.tileX * tile
            let y = prop.tileY * tile
            let width = prop.width * tile
            let height = prop.height * tile
            switch prop.kind {
            case .rug:
                if isCoffeeShop {
                    drawCoffeeRug(&canvas, x: x, y: y, width: width, height: height)
                } else {
                    drawRug(&canvas, x: x, y: y, width: width, height: height)
                }
            case .window:
                if isCoffeeShop {
                    drawCoffeeWindow(&canvas, x: x, y: y, width: width, height: height)
                } else {
                    drawWindow(&canvas, x: x, y: y, width: width, height: height)
                }
            case .clock:
                drawClock(&canvas, x: x, y: y, size: min(width, height))
            case .bookshelf:
                drawBookshelf(&canvas, x: x, y: y, width: width, height: height, seed: prop.tileX * 31 + prop.tileY)
            case .plant:
                drawPlant(&canvas, x: x, y: y)
            case .coffeeMachine:
                drawCoffeeMachine(&canvas, x: x, y: y)
            case .door:
                drawDoor(&canvas, x: x, y: y, width: width, height: height)
            case .neonSign:
                drawNeonSign(&canvas, x: x, y: y, width: width, height: height)
            case .chalkboard:
                drawChalkboard(&canvas, x: x, y: y, width: width, height: height)
            case .coffeeBar:
                drawCoffeeBar(&canvas, x: x, y: y, width: width, height: height)
            case .unknown:
                break
            }
        }
        return canvas.makeImage()
    }

    // MARK: - Library Tiles

    private static func drawFloor(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int) {
        let tile = tilePixels
        for plank in 0..<4 {
            let y = tileY * tile + plank * 4
            let tone = [HallPalette.floorLight, HallPalette.floorMid, HallPalette.floorDark][(tileY * 4 + plank + tileX) % 3]
            canvas.fill(x: tileX * tile, y: y, width: tile, height: 4, tone)
            canvas.hLine(x: tileX * tile, y: y + 3, length: tile, HallPalette.floorSeam)
            let seam = (tileX * 7 + (tileY * 4 + plank) * 5) % tile
            canvas.vLine(x: tileX * tile + seam, y: y, length: 3, HallPalette.floorSeam)
        }
    }

    private static func drawWall(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isBaseRow: Bool) {
        let tile = tilePixels
        let x = tileX * tile
        let y = tileY * tile
        canvas.fill(x: x, y: y, width: tile, height: tile, HallPalette.wallpaper)
        for stripe in stride(from: 2, to: tile, by: 6) {
            canvas.vLine(x: x + stripe, y: y, length: tile, HallPalette.wallpaperStripe)
        }
        if tileY == 0 { canvas.fill(x: x, y: y, width: tile, height: 3, HallPalette.wallTop) }
        if isBaseRow {
            canvas.fill(x: x, y: y + 8, width: tile, height: 8, HallPalette.wainscot)
            canvas.hLine(x: x, y: y + 8, length: tile, HallPalette.wainscotHighlight)
            canvas.hLine(x: x, y: y + 15, length: tile, HallPalette.outline)
        }
    }

    // MARK: - Coffee Shop Tiles

    private static func drawCoffeeFloor(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int) {
        let tile = tilePixels
        for plank in 0..<4 {
            let y = tileY * tile + plank * 4
            let tone = [HallPalette.cafeFloorLight, HallPalette.cafeFloorMid, HallPalette.cafeFloorDark][(tileY * 4 + plank + tileX) % 3]
            canvas.fill(x: tileX * tile, y: y, width: tile, height: 4, tone)
            canvas.hLine(x: tileX * tile, y: y + 3, length: tile, HallPalette.cafeFloorSeam)
            let seam = (tileX * 7 + (tileY * 4 + plank) * 5) % tile
            canvas.vLine(x: tileX * tile + seam, y: y, length: 3, HallPalette.cafeFloorSeam)
        }
    }

    private static func drawCoffeeWall(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isBaseRow: Bool) {
        let tile = tilePixels
        let x = tileX * tile
        let y = tileY * tile
        // Warm brick pattern with staggered courses
        canvas.fill(x: x, y: y, width: tile, height: tile, HallPalette.cafeBrickMain)

        for course in 0..<4 {
            let courseY = y + course * 4
            let isStaggered = (course % 2) == 1
            let offset = isStaggered ? 4 : 0

            // Horizontal mortar seam
            canvas.hLine(x: x, y: courseY + 3, length: tile, HallPalette.cafeBrickMortar)

            // Vertical mortar joints
            for bx in stride(from: offset, to: tile, by: 8) {
                canvas.vLine(x: x + bx, y: courseY, length: 3, HallPalette.cafeBrickMortar)
            }

            // Top highlight for brick depth
            for bx in stride(from: offset + 1, to: tile, by: 8) {
                let len = min(6, tile - bx)
                if len > 0 {
                    canvas.hLine(x: x + bx, y: courseY, length: len, HallPalette.cafeBrickLight)
                }
            }
        }

        if tileY == 0 { canvas.fill(x: x, y: y, width: tile, height: 3, HallPalette.cafeWallTop) }
        if isBaseRow {
            canvas.fill(x: x, y: y + 8, width: tile, height: 8, HallPalette.cafeWainscot)
            canvas.hLine(x: x, y: y + 8, length: tile, HallPalette.cafeWainscotHighlight)
            canvas.hLine(x: x, y: y + 15, length: tile, HallPalette.outline)
        }
    }

    // MARK: - Props

    private static func drawRug(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        canvas.fill(x: x, y: y, width: width, height: height, HallPalette.rug)
        canvas.stroke(x: x + 2, y: y + 2, width: width - 4, height: height - 4, HallPalette.rugBorder)
        canvas.stroke(x: x + 4, y: y + 4, width: width - 8, height: height - 8, HallPalette.rugPattern)
        for diamondY in stride(from: y + 12, to: y + height - 12, by: 16) {
            let centerX = x + width / 2
            for offset in 0..<4 {
                canvas.hLine(x: centerX - offset, y: diamondY + offset, length: offset * 2 + 1, HallPalette.rugPattern)
                canvas.hLine(x: centerX - offset, y: diamondY + 6 - offset, length: offset * 2 + 1, HallPalette.rugPattern)
            }
        }
    }

    private static func drawCoffeeRug(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        canvas.fill(x: x, y: y, width: width, height: height, HallPalette.cafeRug)
        canvas.stroke(x: x + 2, y: y + 2, width: width - 4, height: height - 4, HallPalette.cafeRugBorder)
        canvas.stroke(x: x + 4, y: y + 4, width: width - 8, height: height - 8, HallPalette.cafeRugPattern)
        for diamondY in stride(from: y + 12, to: y + height - 12, by: 16) {
            let centerX = x + width / 2
            for offset in 0..<4 {
                canvas.hLine(x: centerX - offset, y: diamondY + offset, length: offset * 2 + 1, HallPalette.cafeRugPattern)
                canvas.hLine(x: centerX - offset, y: diamondY + 6 - offset, length: offset * 2 + 1, HallPalette.cafeRugPattern)
            }
        }
    }

    private static func drawWindow(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        canvas.fill(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.windowFrame)
        canvas.fill(x: x + 4, y: y + 6, width: width - 8, height: height - 10, HallPalette.glass)
        for step in 0..<6 { canvas.set(x + 7 + step, y + 13 - step, HallPalette.glassShine) }
        canvas.vLine(x: x + width / 2, y: y + 6, length: height - 10, HallPalette.windowFrame)
        canvas.hLine(x: x + 4, y: y + height / 2 + 1, length: width - 8, HallPalette.windowFrame)
        canvas.stroke(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.outline)
    }

    private static func drawCoffeeWindow(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        canvas.fill(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.woodDark)
        canvas.fill(x: x + 4, y: y + 6, width: width - 8, height: height - 10, HallPalette.nightGlass)
        // Raindrops and cozy warm indoor light reflection
        for step in 0..<5 { canvas.set(x + 6 + step * 2, y + 8 + step, HallPalette.nightShine) }
        canvas.vLine(x: x + width / 2, y: y + 6, length: height - 10, HallPalette.woodDark)
        canvas.hLine(x: x + 4, y: y + height / 2 + 1, length: width - 8, HallPalette.woodDark)
        canvas.stroke(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.outline)
    }

    private static func drawClock(_ canvas: inout PixelCanvas, x: Int, y: Int, size: Int) {
        let center = Double(size) / 2
        canvas.disc(centerX: Double(x) + center, centerY: Double(y) + center + 2, radius: center - 3, HallPalette.outline)
        canvas.disc(centerX: Double(x) + center, centerY: Double(y) + center + 2, radius: center - 4, HallPalette.woodDark)
        canvas.disc(centerX: Double(x) + center, centerY: Double(y) + center + 2, radius: center - 6, HallPalette.paper)
        let middleX = x + size / 2
        let middleY = y + size / 2 + 2
        canvas.vLine(x: middleX, y: middleY - 7, length: 7, HallPalette.outline)
        canvas.hLine(x: middleX, y: middleY, length: 5, HallPalette.outline)
        canvas.set(middleX, middleY, HallPalette.rug)
    }

    private static func drawBookshelf(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int, seed: Int) {
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

    private static func drawPlant(_ canvas: inout PixelCanvas, x: Int, y: Int) {
        canvas.fill(x: x + 4, y: y + 10, width: 8, height: 6, HallPalette.pot)
        canvas.hLine(x: x + 3, y: y + 10, length: 10, HallPalette.outline)
        canvas.disc(centerX: Double(x) + 8, centerY: Double(y) + 6, radius: 5.5, HallPalette.leaf)
        canvas.disc(centerX: Double(x) + 6, centerY: Double(y) + 4, radius: 2.5, HallPalette.leafLight)
        canvas.disc(centerX: Double(x) + 11, centerY: Double(y) + 7, radius: 2, HallPalette.leafLight)
    }

    private static func drawCoffeeMachine(_ canvas: inout PixelCanvas, x: Int, y: Int) {
        canvas.fill(x: x + 1, y: y + 2, width: 14, height: 28, HallPalette.metal)
        canvas.stroke(x: x + 1, y: y + 2, width: 14, height: 28, HallPalette.outline)
        canvas.fill(x: x + 3, y: y + 4, width: 10, height: 5, HallPalette.rug)
        canvas.hLine(x: x + 4, y: y + 6, length: 8, HallPalette.lampGold)
        canvas.fill(x: x + 4, y: y + 12, width: 8, height: 10, HallPalette.void)
        canvas.fill(x: x + 6, y: y + 17, width: 4, height: 4, HallPalette.paper)
        canvas.fill(x: x + 3, y: y + 24, width: 10, height: 2, HallPalette.metalLight)
    }

    private static func drawDoor(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        canvas.fill(x: x, y: y, width: width, height: height, HallPalette.wood)
        canvas.vLine(x: x + width / 2, y: y, length: height, HallPalette.outline)
        canvas.stroke(x: x, y: y, width: width, height: height, HallPalette.outline)
        canvas.set(x + width / 2 - 2, y + height / 2, HallPalette.lampGold)
        canvas.set(x + width / 2 + 1, y + height / 2, HallPalette.lampGold)
    }

    // MARK: - Coffee Shop Special Props

    private static func drawNeonSign(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        let cx = x + width / 2
        let cy = y + height / 2

        // Soft ambient glow halo
        canvas.disc(centerX: Double(cx), centerY: Double(cy), radius: 14, HallPalette.neonGlow)
        canvas.disc(centerX: Double(cx), centerY: Double(cy - 6), radius: 10, HallPalette.neonWarmGlow)

        // Saucer
        canvas.hLine(x: cx - 12, y: cy + 8, length: 24, HallPalette.neonMain)
        canvas.hLine(x: cx - 10, y: cy + 8, length: 20, HallPalette.neonTube)

        // Coffee Cup body
        canvas.hLine(x: cx - 9, y: cy - 2, length: 18, HallPalette.neonMain)
        canvas.hLine(x: cx - 8, y: cy - 2, length: 16, HallPalette.neonTube)
        canvas.fill(x: cx - 8, y: cy - 1, width: 16, height: 6, HallPalette.neonMain)
        canvas.fill(x: cx - 6, y: cy + 5, width: 12, height: 2, HallPalette.neonMain)

        // Cup Handle
        canvas.vLine(x: cx + 10, y: cy, length: 4, HallPalette.neonMain)
        canvas.hLine(x: cx + 9, y: cy, length: 2, HallPalette.neonTube)
        canvas.hLine(x: cx + 9, y: cy + 3, length: 2, HallPalette.neonTube)

        // Rising Steam Curves (warm gold neon)
        for i in [-4, 0, 4] {
            canvas.set(cx + i, cy - 5, HallPalette.neonWarmGold)
            canvas.set(cx + i + 1, cy - 7, HallPalette.neonWarmGold)
            canvas.set(cx + i, cy - 9, HallPalette.neonWarmGold)
        }
    }

    private static func drawChalkboard(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        // Dark wood frame
        canvas.fill(x: x + 1, y: y + 2, width: width - 2, height: height - 4, HallPalette.chalkboardFrame)
        canvas.stroke(x: x + 1, y: y + 2, width: width - 2, height: height - 4, HallPalette.outline)

        // Slate surface
        canvas.fill(x: x + 3, y: y + 4, width: width - 6, height: height - 8, HallPalette.slateBlack)

        // "MENU" heading chalk
        let cx = x + width / 2
        canvas.hLine(x: cx - 8, y: y + 7, length: 16, HallPalette.chalkYellow)

        // Chalkboard menu lines (representing espresso, latte, etc.)
        for (idx, lineY) in stride(from: y + 12, to: y + height - 8, by: 4).enumerated() {
            let lineLen = idx % 2 == 0 ? width - 18 : width - 22
            canvas.hLine(x: x + 6, y: lineY, length: lineLen, HallPalette.chalkWhite)
            // Price dot in yellow/orange
            canvas.set(x + width - 8, lineY, idx % 2 == 0 ? HallPalette.chalkYellow : HallPalette.chalkOrange)
        }
    }

    private static func drawCoffeeBar(_ canvas: inout PixelCanvas, x: Int, y: Int, width: Int, height: Int) {
        // Counter wooden base with paneling
        canvas.fill(x: x + 2, y: y + 8, width: width - 4, height: height - 8, HallPalette.cafeFloorDark)
        canvas.stroke(x: x + 2, y: y + 8, width: width - 4, height: height - 8, HallPalette.outline)

        // Vertical panel lines on counter
        for px in stride(from: x + 10, to: x + width - 6, by: 12) {
            canvas.vLine(x: px, y: y + 9, length: height - 10, HallPalette.cafeFloorSeam)
        }

        // Marble countertop
        canvas.fill(x: x, y: y + 6, width: width, height: 4, HallPalette.marbleTop)
        canvas.hLine(x: x + 4, y: y + 7, length: width - 12, HallPalette.marbleVein)
        canvas.stroke(x: x, y: y + 6, width: width, height: 4, HallPalette.outline)

        // Glass Pastry Dome Cloche with Croissant inside
        let domeX = x + width - 20
        let domeY = y
        canvas.fill(x: domeX + 2, y: domeY + 1, width: 14, height: 5, HallPalette.glass)
        canvas.stroke(x: domeX + 2, y: domeY + 1, width: 14, height: 5, HallPalette.outline)
        // Golden croissant / pastry inside
        canvas.fill(x: domeX + 4, y: domeY + 3, width: 10, height: 3, HallPalette.pastryGold)

        // Coffee mugs stacked
        canvas.fill(x: x + 6, y: y + 2, width: 5, height: 4, HallPalette.paper)
        canvas.stroke(x: x + 6, y: y + 2, width: 5, height: 4, HallPalette.outline)
        canvas.fill(x: x + 13, y: y + 2, width: 5, height: 4, HallPalette.cafeRug)
        canvas.stroke(x: x + 13, y: y + 2, width: 5, height: 4, HallPalette.outline)
    }
}
