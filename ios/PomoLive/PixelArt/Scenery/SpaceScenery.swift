import Foundation

/// A shuttle's study deck: riveted hull panels with portholes onto the stars, a big viewscreen,
/// deck plating underfoot, consoles along the sides and an airlock at the back.
enum SpaceScenery: Scenery {
    private enum Palette {
        static let hull = PixelColor(0x5A6577FF)
        static let hullLight = PixelColor(0x7A879BFF)
        static let hullDark = PixelColor(0x3A4252FF)
        static let hullDeep = PixelColor(0x262C38FF)
        static let rivet = PixelColor(0x9AA6B8FF)

        static let deck = PixelColor(0x3E4555FF)
        static let deckLight = PixelColor(0x505869FF)
        static let deckSeam = PixelColor(0x262B36FF)
        static let grate = PixelColor(0x2E3440FF)

        static let space = PixelColor(0x0B0E1AFF)
        static let star = PixelColor(0xFFFFFFFF)
        static let starDim = PixelColor(0x8FA3C8FF)
        static let nebula = PixelColor(0x7A4FC055)
        static let planet = PixelColor(0xE07A4AFF)
        static let planetShade = PixelColor(0xA9502CFF)
        static let planetRing = PixelColor(0xF2D39AFF)

        static let screen = PixelColor(0x0F3D46FF)
        static let screenLine = PixelColor(0x4DE1F2FF)
        static let lightStrip = PixelColor(0x8FE6FFFF)
        static let lightGlow = PixelColor(0x8FE6FF40)
        static let hologram = PixelColor(0x6FD8FF70)
        static let hologramLine = PixelColor(0xA8ECFFFF)

        static let red = PixelColor(0xF0544FFF)
        static let green = PixelColor(0x5EE07AFF)
        static let amber = PixelColor(0xF2B33DFF)
        static let hazard = PixelColor(0xF2C12EFF)
        static let hazardDark = PixelColor(0x1E1E22FF)
    }

    static let edge = Palette.hullDeep

    // MARK: Backdrop & ground

    static func drawBackdrop(_ canvas: inout PixelCanvas, width: Int, height: Int) {
        canvas.fill(x: 0, y: 0, width: width, height: height, Palette.hull)
        for panelY in stride(from: 0, to: height - 8, by: 14) {
            canvas.hLine(x: 0, y: panelY, length: width, Palette.hullDark)
            canvas.hLine(x: 0, y: panelY + 1, length: width, Palette.hullLight)
        }
        for panelX in stride(from: 0, to: width, by: 32) {
            canvas.vLine(x: panelX, y: 0, length: height - 8, Palette.hullDark)
            for rivetY in stride(from: 4, to: height - 8, by: 7) {
                canvas.set(panelX + 3, rivetY, Palette.rivet)
                canvas.set(panelX + 28, rivetY, Palette.rivet)
            }
        }
        // A lit trim and a hazard band where the wall meets the deck.
        canvas.fill(x: 0, y: height - 8, width: width, height: 8, Palette.hullDark)
        canvas.hLine(x: 0, y: height - 7, length: width, Palette.lightStrip)
        canvas.hLine(x: 0, y: height - 6, length: width, Palette.lightGlow)
        for x in 0..<width {
            for row in 0..<3 {
                canvas.set(x, height - 4 + row, (x + row) / 4 % 2 == 0 ? Palette.hazard : Palette.hazardDark)
            }
        }
    }

    static func drawGround(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isFirstRow: Bool) {
        let tile = HallRenderer.tilePixels
        let x = tileX * tile
        let y = tileY * tile
        canvas.fill(x: x, y: y, width: tile, height: tile, Palette.deck)
        canvas.hLine(x: x, y: y, length: tile, Palette.deckLight)
        canvas.vLine(x: x, y: y, length: tile, Palette.deckLight)
        canvas.hLine(x: x, y: y + tile - 1, length: tile, Palette.deckSeam)
        canvas.vLine(x: x + tile - 1, y: y, length: tile, Palette.deckSeam)
        for (rivetX, rivetY) in [(2, 2), (13, 2), (2, 13), (13, 13)] {
            canvas.set(x + rivetX, y + rivetY, Palette.deckSeam)
        }
        if pixelHash(tileX, tileY) % 11 == 0 {
            for slot in 0..<4 { canvas.hLine(x: x + 4, y: y + 5 + slot * 2, length: 8, Palette.grate) }
        }
    }

    // MARK: Props

    static func drawProp(_ kind: LayoutProp.Kind, on canvas: inout PixelCanvas, in rect: PixelRect, seed: Int) -> Bool {
        switch kind {
        case .walkway: drawWalkway(&canvas, rect)
        case .porthole: drawPorthole(&canvas, rect, seed: seed)
        case .viewscreen: drawViewscreen(&canvas, rect)
        case .console: drawConsole(&canvas, rect, seed: seed)
        case .crate: drawCrate(&canvas, rect)
        case .hologram: drawHologram(&canvas, rect)
        case .airlock: drawAirlock(&canvas, rect)
        default: return false
        }
        return true
    }

    /// Grated metal with running lights along both edges.
    private static func drawWalkway(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.fill(x: rect.x + 3, y: rect.y, width: rect.width - 6, height: rect.height, Palette.grate)
        for gridY in stride(from: rect.y, to: rect.maxY, by: 4) {
            canvas.hLine(x: rect.x + 3, y: gridY, length: rect.width - 6, Palette.deckSeam)
        }
        for gridX in stride(from: rect.x + 3, to: rect.maxX - 3, by: 4) {
            canvas.vLine(x: gridX, y: rect.y, length: rect.height, Palette.deckSeam)
        }
        for edgeX in [rect.x + 1, rect.maxX - 3] {
            canvas.fill(x: edgeX, y: rect.y, width: 2, height: rect.height, Palette.hullDark)
            for lightY in stride(from: rect.y + 4, to: rect.maxY, by: 10) {
                canvas.fill(x: edgeX, y: lightY, width: 2, height: 3, Palette.lightStrip)
                canvas.fill(x: edgeX - 1, y: lightY - 1, width: 4, height: 5, Palette.lightGlow)
            }
        }
    }

    private static func drawStars(_ canvas: inout PixelCanvas, in rect: PixelRect, seed: Int, count: Int) {
        for star in 0..<count {
            let hash = pixelHash(seed, star, 17)
            let x = rect.x + hash % max(1, rect.width)
            let y = rect.y + (hash / 1024) % max(1, rect.height)
            canvas.set(x, y, hash % 4 == 0 ? Palette.star : Palette.starDim)
        }
    }

    private static func drawPorthole(_ canvas: inout PixelCanvas, _ rect: PixelRect, seed: Int) {
        let centerX = Double(rect.midX)
        let centerY = Double(rect.midY)
        canvas.disc(centerX: centerX, centerY: centerY, radius: 13, Palette.hullDeep)
        canvas.disc(centerX: centerX, centerY: centerY, radius: 12, Palette.hullLight)
        canvas.disc(centerX: centerX, centerY: centerY, radius: 9.5, Palette.space)
        for star in 0..<9 {
            let hash = pixelHash(seed, star, 23)
            let angle = Double(hash % 628) / 100
            let distance = Double((hash / 1000) % 8)
            canvas.set(rect.midX + Int(cos(angle) * distance), rect.midY + Int(sin(angle) * distance), star % 3 == 0 ? Palette.star : Palette.starDim)
        }
        for step in 0..<4 { canvas.set(rect.midX - 6 + step, rect.midY - 4 - step / 2, Palette.hologramLine) }
        for angle in stride(from: 0.0, to: 2 * .pi, by: .pi / 4) {
            canvas.set(rect.midX + Int(cos(angle) * 11), rect.midY + Int(sin(angle) * 11), Palette.rivet)
        }
    }

    /// A wide window onto space with a ringed planet drifting by.
    private static func drawViewscreen(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.fill(x: rect.x, y: rect.y + 2, width: rect.width, height: rect.height - 2, Palette.hullDeep)
        let glass = PixelRect(x: rect.x + 3, y: rect.y + 5, width: rect.width - 6, height: rect.height - 8)
        canvas.fill(x: glass.x, y: glass.y, width: glass.width, height: glass.height, Palette.space)
        canvas.ellipse(centerX: Double(glass.x + 30), centerY: Double(glass.midY), radiusX: 22, radiusY: 9, Palette.nebula)
        drawStars(&canvas, in: glass, seed: 99, count: 40)
        let planetX = Double(glass.maxX - 30)
        let planetY = Double(glass.midY + 2)
        canvas.ellipse(centerX: planetX, centerY: planetY, radiusX: 17, radiusY: 3, Palette.planetRing)
        canvas.disc(centerX: planetX, centerY: planetY, radius: 9, Palette.planet)
        canvas.disc(centerX: planetX + 3, centerY: planetY + 3, radius: 7, Palette.planetShade)
        canvas.hLine(x: Int(planetX) - 8, y: Int(planetY) + 1, length: 17, Palette.planetRing)
        for divider in stride(from: glass.x + glass.width / 4, to: glass.maxX, by: glass.width / 4) {
            canvas.vLine(x: divider, y: glass.y, length: glass.height, Palette.hullDark)
        }
        canvas.stroke(x: glass.x - 1, y: glass.y - 1, width: glass.width + 2, height: glass.height + 2, Palette.hullLight)
    }

    private static func drawConsole(_ canvas: inout PixelCanvas, _ rect: PixelRect, seed: Int) {
        canvas.fill(x: rect.x + 2, y: rect.y + 4, width: rect.width - 4, height: rect.height - 4, Palette.hullDark)
        canvas.stroke(x: rect.x + 2, y: rect.y + 4, width: rect.width - 4, height: rect.height - 4, Palette.hullDeep)
        canvas.fill(x: rect.x + 5, y: rect.y + 7, width: rect.width - 10, height: 11, Palette.screen)
        for line in 0..<3 {
            let length = 6 + pixelHash(seed, line) % (rect.width - 16)
            canvas.hLine(x: rect.x + 7, y: rect.y + 9 + line * 3, length: length, Palette.screenLine)
        }
        for (index, color) in [Palette.red, Palette.green, Palette.amber, Palette.green].enumerated() {
            canvas.fill(x: rect.x + 6 + index * 5, y: rect.y + 22, width: 3, height: 2, color)
        }
        canvas.hLine(x: rect.x + 5, y: rect.y + 26, length: rect.width - 10, Palette.hull)
        canvas.hLine(x: rect.x + 5, y: rect.y + 28, length: rect.width - 10, Palette.hull)
    }

    private static func drawCrate(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.fill(x: rect.x + 1, y: rect.y + 2, width: 14, height: 13, Palette.hull)
        canvas.stroke(x: rect.x + 1, y: rect.y + 2, width: 14, height: 13, Palette.hullDeep)
        canvas.hLine(x: rect.x + 2, y: rect.y + 3, length: 12, Palette.hullLight)
        for x in 0..<12 {
            canvas.set(rect.x + 2 + x, rect.y + 12, x / 2 % 2 == 0 ? Palette.hazard : Palette.hazardDark)
            canvas.set(rect.x + 2 + x, rect.y + 13, (x + 1) / 2 % 2 == 0 ? Palette.hazard : Palette.hazardDark)
        }
        canvas.fill(x: rect.x + 6, y: rect.y + 6, width: 4, height: 3, Palette.hullDark)
    }

    /// A projector pad casting a wireframe globe.
    private static func drawHologram(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let centerX = Double(rect.midX)
        let baseY = Double(rect.maxY - 7)
        canvas.ellipse(centerX: centerX, centerY: baseY, radiusX: 14, radiusY: 5, Palette.hullDeep)
        canvas.ellipse(centerX: centerX, centerY: baseY - 1, radiusX: 12, radiusY: 3.5, Palette.hullLight)
        canvas.ellipse(centerX: centerX, centerY: baseY - 1, radiusX: 5, radiusY: 1.5, Palette.lightStrip)
        let globeY = Double(rect.y + 17)
        canvas.ellipse(centerX: centerX, centerY: (globeY + baseY) / 2 + 4, radiusX: 8, radiusY: 12, Palette.hologram)
        canvas.disc(centerX: centerX, centerY: globeY, radius: 11, Palette.hologram)
        for step in 0..<48 {
            let angle = Double(step) / 48 * 2 * .pi
            canvas.set(rect.midX + Int(cos(angle) * 11), Int(globeY) + Int(sin(angle) * 11), Palette.hologramLine)
            canvas.set(rect.midX + Int(cos(angle) * 4.5), Int(globeY) + Int(sin(angle) * 11), Palette.hologramLine)
        }
        canvas.hLine(x: rect.midX - 10, y: Int(globeY), length: 21, Palette.hologramLine)
        canvas.hLine(x: rect.midX - 8, y: Int(globeY) - 6, length: 17, Palette.hologramLine)
        canvas.hLine(x: rect.midX - 8, y: Int(globeY) + 6, length: 17, Palette.hologramLine)
    }

    private static func drawAirlock(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.fill(x: rect.x, y: rect.y, width: rect.width, height: rect.height, Palette.hullDeep)
        for x in 0..<rect.width {
            for row in 0..<3 {
                canvas.set(rect.x + x, rect.y + row, (x + row) / 4 % 2 == 0 ? Palette.hazard : Palette.hazardDark)
            }
        }
        canvas.fill(x: rect.x + 4, y: rect.y + 5, width: rect.width - 8, height: rect.height - 5, Palette.hull)
        canvas.vLine(x: rect.midX, y: rect.y + 5, length: rect.height - 5, Palette.hullDeep)
        canvas.hLine(x: rect.x + 4, y: rect.y + 5, length: rect.width - 8, Palette.hullLight)
        for side in [-1, 1] {
            canvas.fill(x: rect.midX + side * 8 - 2, y: rect.y + 12, width: 4, height: 8, Palette.hullDark)
        }
        canvas.fill(x: rect.midX - 2, y: rect.y + 3, width: 4, height: 2, Palette.red)
    }
}
