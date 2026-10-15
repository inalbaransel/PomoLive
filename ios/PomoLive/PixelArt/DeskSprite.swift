import CoreGraphics

/// A desk node: chair, optional seated avatar, desk surface and a light, on a 2×2 tile (32×32 px) canvas.
/// Each room theme furnishes it differently: a library desk with a reading lamp, a café table with a
/// candle, a log table with a lantern, a metal console with a holo screen, or a bamboo table with a tiki torch.
enum DeskSprite {
    struct Key: Hashable {
        var theme: RoomTheme = .classic
        var avatar: AvatarSprite?
        var phase: TimerPhase
        var frame: Int
    }

    static let pixels = 32

    static func render(_ key: Key) -> CGImage {
        let style = Style(key.theme)
        var canvas = PixelCanvas(width: pixels, height: pixels)
        drawChair(&canvas, style)
        if let avatar = key.avatar {
            let pose: AvatarSprite.Pose = key.phase == .focus ? .typing(frame: key.frame) : .sipping(frame: key.frame)
            canvas.draw(avatar.canvas(pose), x: 8, y: 4)
        }
        drawDesk(&canvas, style)
        drawLight(&canvas, style, lit: key.avatar != nil, frame: key.frame)
        drawItems(&canvas, style, occupied: key.avatar != nil, phase: key.phase)
        return canvas.makeImage()
    }

    // MARK: - Style

    private enum Light {
        case readingLamp, candle, lantern, holoScreen, tikiTorch
    }

    private enum Surface {
        case planks, rings, panel, bamboo
    }

    private enum RestItem {
        case book, cup, mug, pouch, coconut
    }

    private struct Style {
        var chair: PixelColor
        var chairAccent: PixelColor
        var top: PixelColor
        var front: PixelColor
        var dark: PixelColor
        var surface: Surface
        var light: Light
        var restItem: RestItem

        init(_ theme: RoomTheme) {
            switch theme {
            case .classic:
                self.init(chair: HallPalette.woodDark, chairAccent: HallPalette.rug, top: HallPalette.woodLight, front: HallPalette.wood,
                          dark: HallPalette.woodDark, surface: .planks, light: .readingLamp, restItem: .book)
            case .coffeeShop:
                self.init(chair: PixelColor(0x3D2519FF), chairAccent: PixelColor(0xB85D34FF), top: PixelColor(0x6E4630FF),
                          front: PixelColor(0x52331FFF), dark: PixelColor(0x2B180FFF), surface: .planks, light: .candle, restItem: .cup)
            case .forest:
                self.init(chair: PixelColor(0x7A5332FF), chairAccent: PixelColor(0xD2A872FF), top: PixelColor(0xD2A872FF),
                          front: PixelColor(0x7A5332FF), dark: PixelColor(0x553820FF), surface: .rings, light: .lantern, restItem: .mug)
            case .space:
                self.init(chair: PixelColor(0xC9D3E0FF), chairAccent: PixelColor(0x4DE1F2FF), top: PixelColor(0x8A97ABFF),
                          front: PixelColor(0x3A4252FF), dark: PixelColor(0x262C38FF), surface: .panel, light: .holoScreen, restItem: .pouch)
            case .beach:
                self.init(chair: PixelColor(0x3F7FD9FF), chairAccent: PixelColor(0xF7F3EAFF), top: PixelColor(0xE2C07EFF),
                          front: PixelColor(0xC49A58FF), dark: PixelColor(0x8F653AFF), surface: .bamboo, light: .tikiTorch, restItem: .coconut)
            }
        }

        private init(chair: PixelColor, chairAccent: PixelColor, top: PixelColor, front: PixelColor, dark: PixelColor,
                     surface: Surface, light: Light, restItem: RestItem) {
            self.chair = chair
            self.chairAccent = chairAccent
            self.top = top
            self.front = front
            self.dark = dark
            self.surface = surface
            self.light = light
            self.restItem = restItem
        }
    }

    // MARK: - Furniture

    private static func drawChair(_ canvas: inout PixelCanvas, _ style: Style) {
        switch style.surface {
        case .rings:
            // A stump stool.
            canvas.ellipse(centerX: 16, centerY: 12, radiusX: 6.5, radiusY: 6, style.chair)
            canvas.ellipse(centerX: 16, centerY: 10, radiusX: 5, radiusY: 3, style.chairAccent)
        case .bamboo:
            // A striped deck chair.
            canvas.fill(x: 10, y: 6, width: 12, height: 12, style.chairAccent)
            for stripe in stride(from: 10, to: 22, by: 4) { canvas.fill(x: stripe, y: 6, width: 2, height: 12, style.chair) }
            canvas.stroke(x: 10, y: 6, width: 12, height: 12, style.dark)
        case .panel:
            // A rounded pod seat with a glowing trim.
            canvas.fill(x: 10, y: 7, width: 12, height: 11, style.chair)
            canvas.fill(x: 11, y: 6, width: 10, height: 1, style.chair)
            canvas.hLine(x: 11, y: 9, length: 10, style.chairAccent)
            canvas.stroke(x: 10, y: 7, width: 12, height: 11, style.dark)
        case .planks:
            canvas.fill(x: 10, y: 6, width: 12, height: 12, style.chair)
            canvas.stroke(x: 10, y: 6, width: 12, height: 12, HallPalette.outline)
            canvas.fill(x: 12, y: 8, width: 8, height: 3, style.chairAccent)
        }
    }

    private static func drawDesk(_ canvas: inout PixelCanvas, _ style: Style) {
        canvas.fill(x: 1, y: 17, width: 30, height: 7, style.top)
        canvas.hLine(x: 1, y: 17, length: 30, HallPalette.paper.withAlpha(0x40))
        canvas.fill(x: 1, y: 24, width: 30, height: 5, style.front)
        canvas.hLine(x: 1, y: 24, length: 30, style.dark)
        switch style.surface {
        case .planks:
            canvas.fill(x: 2, y: 29, width: 3, height: 3, style.dark)
            canvas.fill(x: 27, y: 29, width: 3, height: 3, style.dark)
        case .rings:
            // A sawn log: growth rings on top, bark down the front.
            canvas.ellipse(centerX: 8, centerY: 20.5, radiusX: 3, radiusY: 1.5, style.front)
            canvas.ellipse(centerX: 25, centerY: 21, radiusX: 2, radiusY: 1, style.front)
            for barkX in stride(from: 3, to: 30, by: 4) { canvas.vLine(x: barkX, y: 25, length: 4, style.dark) }
            canvas.fill(x: 3, y: 29, width: 5, height: 3, style.dark)
            canvas.fill(x: 24, y: 29, width: 5, height: 3, style.dark)
        case .panel:
            // A console: cyan edge light and status LEDs on the front.
            canvas.hLine(x: 1, y: 23, length: 30, style.chairAccent)
            for (index, color) in [PixelColor(0x5EE07AFF), PixelColor(0xF2B33DFF), PixelColor(0xF0544FFF)].enumerated() {
                canvas.fill(x: 4 + index * 3, y: 26, width: 2, height: 1, color)
            }
            canvas.hLine(x: 18, y: 26, length: 10, style.top)
            canvas.fill(x: 4, y: 29, width: 24, height: 2, style.dark)
        case .bamboo:
            // Bamboo slats with knots, on bamboo legs.
            for slatX in stride(from: 1, to: 31, by: 3) { canvas.vLine(x: slatX, y: 17, length: 7, style.front) }
            for slatX in stride(from: 2, to: 31, by: 6) { canvas.vLine(x: slatX, y: 25, length: 4, style.dark) }
            canvas.fill(x: 2, y: 29, width: 2, height: 3, style.dark)
            canvas.fill(x: 28, y: 29, width: 2, height: 3, style.dark)
        }
        canvas.stroke(x: 0, y: 16, width: 32, height: 14, HallPalette.outline)
    }

    /// The desk's light source, lit (and gently flickering for flames) while someone is seated.
    private static func drawLight(_ canvas: inout PixelCanvas, _ style: Style, lit: Bool, frame: Int) {
        let flame = frame == 0 ? PixelColor(0xF2862EFF) : PixelColor(0xFFA040FF)
        let flameCore = PixelColor(0xFFD45AFF)
        switch style.light {
        case .readingLamp:
            if lit { canvas.disc(centerX: 6, centerY: 20, radius: 6, HallPalette.lampGlow) }
            canvas.vLine(x: 5, y: 12, length: 9, HallPalette.metal)
            canvas.fill(x: 3, y: 20, width: 5, height: 2, HallPalette.metal)
            canvas.fill(x: 2, y: 9, width: 7, height: 4, lit ? HallPalette.lampGold : HallPalette.metalLight)
            canvas.hLine(x: 2, y: 9, length: 7, HallPalette.outline)
        case .candle:
            if lit { canvas.disc(centerX: 5, centerY: 16, radius: 6, HallPalette.lampGlow) }
            canvas.fill(x: 3, y: 19, width: 5, height: 2, PixelColor(0x8A6A4AFF))
            canvas.fill(x: 4, y: 14, width: 3, height: 5, HallPalette.paper)
            if lit {
                canvas.set(5, 12, flame)
                canvas.set(5, 13, flameCore)
            }
        case .lantern:
            if lit { canvas.disc(centerX: 5.5, centerY: 16, radius: 7, HallPalette.lampGlow) }
            canvas.hLine(x: 4, y: 10, length: 3, style.dark)
            canvas.fill(x: 3, y: 11, width: 5, height: 8, PixelColor(0x2B2B2BFF))
            canvas.fill(x: 4, y: 12, width: 3, height: 6, lit ? flameCore : HallPalette.glass.withAlpha(0x80))
            if lit { canvas.fill(x: 5, y: 14, width: 1, height: 3, flame) }
            canvas.fill(x: 3, y: 19, width: 5, height: 2, PixelColor(0x2B2B2BFF))
        case .holoScreen:
            canvas.vLine(x: 5, y: 15, length: 6, style.dark)
            canvas.fill(x: 3, y: 20, width: 5, height: 2, style.dark)
            let screen = lit ? PixelColor(0x4DE1F2B0) : PixelColor(0x4DE1F240)
            canvas.fill(x: 1, y: 8, width: 9, height: 7, screen)
            if lit {
                canvas.hLine(x: 2, y: 10, length: 5, PixelColor(0xA8ECFFFF))
                canvas.hLine(x: 2, y: 12, length: 3 + frame * 3, PixelColor(0xA8ECFFFF))
            }
        case .tikiTorch:
            if lit { canvas.disc(centerX: 5, centerY: 9, radius: 6, HallPalette.lampGlow) }
            canvas.vLine(x: 5, y: 10, length: 11, PixelColor(0x7C5630FF))
            canvas.fill(x: 4, y: 9, width: 3, height: 3, PixelColor(0xA0743FFF))
            canvas.fill(x: 3, y: 20, width: 5, height: 2, PixelColor(0x7C5630FF))
            if lit {
                canvas.fill(x: 4, y: 6, width: 3, height: 3, flame)
                canvas.set(5, 5, flame)
                canvas.set(5, 7, flameCore)
            }
        }
    }

    /// Work on the desk while focusing, the theme's break treat while resting, paper when empty.
    private static func drawItems(_ canvas: inout PixelCanvas, _ style: Style, occupied: Bool, phase: TimerPhase) {
        guard occupied else {
            canvas.fill(x: 20, y: 19, width: 7, height: 3, HallPalette.paper)
            canvas.vLine(x: 23, y: 19, length: 3, HallPalette.floorSeam)
            return
        }
        if phase == .focus {
            canvas.fill(x: 12, y: 18, width: 9, height: 4, HallPalette.metalLight)
            canvas.fill(x: 13, y: 18, width: 7, height: 2, HallPalette.screenGlow)
            canvas.hLine(x: 11, y: 22, length: 11, HallPalette.metal)
            return
        }
        switch style.restItem {
        case .book:
            canvas.fill(x: 13, y: 19, width: 7, height: 3, HallPalette.bookSpines[0])
            canvas.hLine(x: 13, y: 21, length: 7, HallPalette.paper)
        case .cup:
            canvas.ellipse(centerX: 16.5, centerY: 22, radiusX: 4.5, radiusY: 1.2, HallPalette.paper)
            canvas.fill(x: 14, y: 18, width: 5, height: 4, HallPalette.paper)
            canvas.hLine(x: 15, y: 18, length: 3, PixelColor(0x5A3420FF))
            canvas.set(19, 19, HallPalette.paper)
            canvas.set(20, 20, HallPalette.paper)
        case .mug:
            canvas.fill(x: 14, y: 18, width: 5, height: 4, PixelColor(0x6E8B9AFF))
            canvas.hLine(x: 14, y: 18, length: 5, PixelColor(0xA9C3D0FF))
            canvas.vLine(x: 19, y: 19, length: 2, PixelColor(0x6E8B9AFF))
        case .pouch:
            canvas.fill(x: 14, y: 18, width: 5, height: 4, PixelColor(0xE9ECF1FF))
            canvas.hLine(x: 14, y: 20, length: 5, PixelColor(0xF2B33DFF))
            canvas.fill(x: 16, y: 16, width: 1, height: 2, PixelColor(0x8A97ABFF))
        case .coconut:
            canvas.disc(centerX: 16.5, centerY: 20, radius: 2.8, PixelColor(0x6B4423FF))
            canvas.hLine(x: 15, y: 18, length: 4, PixelColor(0xF7F3EAFF))
            canvas.vLine(x: 18, y: 14, length: 4, PixelColor(0xE2534AFF))
            canvas.set(17, 14, PixelColor(0xE2534AFF))
        }
    }
}
