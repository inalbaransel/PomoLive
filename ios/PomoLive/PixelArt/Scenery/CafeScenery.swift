/// Gece Kafesi: brick walls, dark espresso floorboards, a neon cup sign, a chalkboard menu and a coffee bar.
enum CafeScenery: Scenery {
    private enum Palette {
        static let wallTop = PixelColor(0x3A21_1DFF)
        static let brick = PixelColor(0x823E_32FF)
        static let brickLight = PixelColor(0x994D_3FFF)
        static let mortar = PixelColor(0x4220_1BFF)
        static let wainscot = PixelColor(0x4424_17FF)
        static let wainscotHighlight = PixelColor(0x5E34_22FF)

        static let floorLight = PixelColor(0x6140_2EFF)
        static let floorMid = PixelColor(0x4E32_23FF)
        static let floorDark = PixelColor(0x3D25_19FF)
        static let floorSeam = PixelColor(0x2B18_0FFF)

        static let rug = PixelColor(0x9E4B_2CFF)
        static let rugBorder = PixelColor(0xDBA0_53FF)
        static let rugPattern = PixelColor(0xB85D_34FF)

        static let neonTube = PixelColor(0xFF8D_AFFF)
        static let neon = PixelColor(0xFF33_77FF)
        static let neonGlow = PixelColor(0xFF33_7744)
        static let neonGold = PixelColor(0xFFBA_42FF)
        static let neonGoldGlow = PixelColor(0xFFBA_4244)

        static let slate = PixelColor(0x2226_2BFF)
        static let chalkboardFrame = PixelColor(0x4E30_1EFF)
        static let chalk = PixelColor(0xF0EC_E1FF)
        static let chalkYellow = PixelColor(0xF5CF_6CFF)
        static let chalkOrange = PixelColor(0xF08A_4BFF)

        static let nightGlass = PixelColor(0x1B24_33FF)
        static let nightShine = PixelColor(0x5671_9CFF)

        static let marble = PixelColor(0xEAE4_DAFF)
        static let marbleVein = PixelColor(0xBFB6_A8FF)
        static let pastry = PixelColor(0xD991_3CFF)
    }

    static let edge = Palette.wallTop

    static func drawBackdrop(_ canvas: inout PixelCanvas, width: Int, height: Int) {
        canvas.fill(x: 0, y: 0, width: width, height: height, Palette.brick)
        for course in 0..<(height / 4) {
            let y = course * 4
            canvas.hLine(x: 0, y: y + 3, length: width, Palette.mortar)
            let offset = course % 2 == 1 ? 4 : 0
            for brickX in stride(from: offset, to: width, by: 8) {
                canvas.vLine(x: brickX, y: y, length: 3, Palette.mortar)
                canvas.hLine(x: brickX + 1, y: y, length: 6, Palette.brickLight)
            }
        }
        canvas.fill(x: 0, y: 0, width: width, height: 3, Palette.wallTop)
        canvas.fill(x: 0, y: height - 8, width: width, height: 8, Palette.wainscot)
        canvas.hLine(x: 0, y: height - 8, length: width, Palette.wainscotHighlight)
        canvas.hLine(x: 0, y: height - 1, length: width, HallPalette.outline)
    }

    static func drawGround(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isFirstRow: Bool) {
        LibraryScenery.drawPlanks(&canvas, tileX: tileX, tileY: tileY, tones: [Palette.floorLight, Palette.floorMid, Palette.floorDark], seam: Palette.floorSeam)
    }

    static func drawProp(_ kind: LayoutProp.Kind, on canvas: inout PixelCanvas, in rect: PixelRect, seed: Int) -> Bool {
        switch kind {
        case .rug: LibraryScenery.drawRug(&canvas, rect, base: Palette.rug, border: Palette.rugBorder, pattern: Palette.rugPattern)
        case .window: drawNightWindow(&canvas, rect)
        case .neonSign: drawNeonSign(&canvas, rect)
        case .chalkboard: drawChalkboard(&canvas, rect)
        case .coffeeBar: drawCoffeeBar(&canvas, rect)
        default: return false
        }
        return true
    }

    private static func drawNightWindow(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let (x, y, width, height) = (rect.x, rect.y, rect.width, rect.height)
        canvas.fill(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.woodDark)
        canvas.fill(x: x + 4, y: y + 6, width: width - 8, height: height - 10, Palette.nightGlass)
        for step in 0..<5 { canvas.set(x + 6 + step * 2, y + 8 + step, Palette.nightShine) }
        canvas.vLine(x: rect.midX, y: y + 6, length: height - 10, HallPalette.woodDark)
        canvas.hLine(x: x + 4, y: rect.midY + 1, length: width - 8, HallPalette.woodDark)
        canvas.stroke(x: x + 2, y: y + 4, width: width - 4, height: height - 6, HallPalette.outline)
    }

    /// A glowing coffee cup with rising steam.
    private static func drawNeonSign(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let centerX = rect.midX
        let centerY = rect.midY
        canvas.disc(centerX: Double(centerX), centerY: Double(centerY), radius: 14, Palette.neonGlow)
        canvas.disc(centerX: Double(centerX), centerY: Double(centerY - 6), radius: 10, Palette.neonGoldGlow)
        canvas.hLine(x: centerX - 12, y: centerY + 8, length: 24, Palette.neon)
        canvas.hLine(x: centerX - 10, y: centerY + 8, length: 20, Palette.neonTube)
        canvas.hLine(x: centerX - 9, y: centerY - 2, length: 18, Palette.neon)
        canvas.hLine(x: centerX - 8, y: centerY - 2, length: 16, Palette.neonTube)
        canvas.fill(x: centerX - 8, y: centerY - 1, width: 16, height: 6, Palette.neon)
        canvas.fill(x: centerX - 6, y: centerY + 5, width: 12, height: 2, Palette.neon)
        canvas.vLine(x: centerX + 10, y: centerY, length: 4, Palette.neon)
        canvas.hLine(x: centerX + 9, y: centerY, length: 2, Palette.neonTube)
        canvas.hLine(x: centerX + 9, y: centerY + 3, length: 2, Palette.neonTube)
        for steamX in [-4, 0, 4] {
            canvas.set(centerX + steamX, centerY - 5, Palette.neonGold)
            canvas.set(centerX + steamX + 1, centerY - 7, Palette.neonGold)
            canvas.set(centerX + steamX, centerY - 9, Palette.neonGold)
        }
    }

    private static func drawChalkboard(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let (x, y, width, height) = (rect.x, rect.y, rect.width, rect.height)
        canvas.fill(x: x + 1, y: y + 2, width: width - 2, height: height - 4, Palette.chalkboardFrame)
        canvas.stroke(x: x + 1, y: y + 2, width: width - 2, height: height - 4, HallPalette.outline)
        canvas.fill(x: x + 3, y: y + 4, width: width - 6, height: height - 8, Palette.slate)
        canvas.hLine(x: rect.midX - 8, y: y + 7, length: 16, Palette.chalkYellow)
        for (index, lineY) in stride(from: y + 12, to: y + height - 8, by: 4).enumerated() {
            canvas.hLine(x: x + 6, y: lineY, length: index % 2 == 0 ? width - 18 : width - 22, Palette.chalk)
            canvas.set(x + width - 8, lineY, index % 2 == 0 ? Palette.chalkYellow : Palette.chalkOrange)
        }
    }

    private static func drawCoffeeBar(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let (x, y, width, height) = (rect.x, rect.y, rect.width, rect.height)
        canvas.fill(x: x + 2, y: y + 8, width: width - 4, height: height - 8, Palette.floorDark)
        canvas.stroke(x: x + 2, y: y + 8, width: width - 4, height: height - 8, HallPalette.outline)
        for panelX in stride(from: x + 10, to: x + width - 6, by: 12) {
            canvas.vLine(x: panelX, y: y + 9, length: height - 10, Palette.floorSeam)
        }
        canvas.fill(x: x, y: y + 6, width: width, height: 4, Palette.marble)
        canvas.hLine(x: x + 4, y: y + 7, length: width - 12, Palette.marbleVein)
        canvas.stroke(x: x, y: y + 6, width: width, height: 4, HallPalette.outline)
        let domeX = x + width - 20
        canvas.fill(x: domeX + 2, y: y + 1, width: 14, height: 5, HallPalette.glass)
        canvas.stroke(x: domeX + 2, y: y + 1, width: 14, height: 5, HallPalette.outline)
        canvas.fill(x: domeX + 4, y: y + 3, width: 10, height: 3, Palette.pastry)
        canvas.fill(x: x + 6, y: y + 2, width: 5, height: 4, HallPalette.paper)
        canvas.stroke(x: x + 6, y: y + 2, width: 5, height: 4, HallPalette.outline)
        canvas.fill(x: x + 13, y: y + 2, width: 5, height: 4, Palette.rug)
        canvas.stroke(x: x + 13, y: y + 2, width: 5, height: 4, HallPalette.outline)
    }
}
