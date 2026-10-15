import Foundation

/// A study spot on the sand: sky and sea along the top, a boardwalk down the middle,
/// palms along the sides, umbrellas, towels, a sandcastle and shells.
enum BeachScenery: Scenery {
    private enum Palette {
        static let sky = PixelColor(0x8FD3F2FF)
        static let skyHaze = PixelColor(0xC6EDFAFF)
        static let cloud = PixelColor(0xFBFDFFFF)
        static let sun = PixelColor(0xFFE28AFF)
        static let sunGlow = PixelColor(0xFFF2B855)
        static let seaDeep = PixelColor(0x1F6FA8FF)
        static let sea = PixelColor(0x2F8FC9FF)
        static let seaLight = PixelColor(0x6CC3EAFF)
        static let foam = PixelColor(0xF4FBFFFF)

        static let sand = PixelColor(0xEBD49AFF)
        static let sandLight = PixelColor(0xF6E6B6FF)
        static let sandDark = PixelColor(0xD4B67AFF)
        static let wetSand = PixelColor(0xC9A86AFF)
        static let shadow = PixelColor(0x8A6A3A40)
        static let duneGrass = PixelColor(0x8DB75AFF)

        static let plank = PixelColor(0xB98A55FF)
        static let plankAlt = PixelColor(0xA87B4AFF)
        static let plankSeam = PixelColor(0x6E4A2AFF)
        static let nail = PixelColor(0x4A3220FF)

        static let trunk = PixelColor(0xA0743FFF)
        static let trunkDark = PixelColor(0x7C5630FF)
        static let leaf = PixelColor(0x3E9A4AFF)
        static let leafDark = PixelColor(0x2C7838FF)
        static let leafLight = PixelColor(0x6AC46CFF)
        static let coconut = PixelColor(0x6B4423FF)

        static let umbrellaRed = PixelColor(0xE2534AFF)
        static let umbrellaWhite = PixelColor(0xF7F3EAFF)
        static let pole = PixelColor(0xE9E2D2FF)
        static let towelBlue = PixelColor(0x3F7FD9FF)
        static let towelYellow = PixelColor(0xF2C94CFF)
        static let shellPink = PixelColor(0xF2B7B0FF)
        static let shellLine = PixelColor(0xC98A84FF)
        static let surfOrange = PixelColor(0xF28C38FF)
        static let surfTeal = PixelColor(0x3EC1B5FF)
        static let surfEdge = PixelColor(0xB8641FFF)
        static let flag = PixelColor(0xE2534AFF)
    }

    static let edge = Palette.sandDark

    // MARK: Backdrop & ground

    /// Sky with a sun and clouds, the sea with rolling wave lines, and foam on wet sand.
    static func drawBackdrop(_ canvas: inout PixelCanvas, width: Int, height: Int) {
        let horizon = 14
        let shore = height - 9
        canvas.fill(x: 0, y: 0, width: width, height: horizon, Palette.sky)
        canvas.fill(x: 0, y: horizon - 4, width: width, height: 4, Palette.skyHaze)
        canvas.disc(centerX: Double(width - 90), centerY: 7, radius: 9, Palette.sunGlow)
        canvas.disc(centerX: Double(width - 90), centerY: 7, radius: 5.5, Palette.sun)
        for cloudX in [60, 230, 410] {
            canvas.ellipse(centerX: Double(cloudX), centerY: 6, radiusX: 12, radiusY: 3, Palette.cloud)
            canvas.disc(centerX: Double(cloudX - 3), centerY: 4, radius: 3.5, Palette.cloud)
        }
        canvas.fill(x: 0, y: horizon, width: width, height: shore - horizon, Palette.sea)
        canvas.fill(x: 0, y: horizon, width: width, height: 5, Palette.seaDeep)
        for (row, waveY) in stride(from: horizon + 7, to: shore - 2, by: 5).enumerated() {
            for x in stride(from: (row * 9) % 22, to: width, by: 22) {
                canvas.hLine(x: x, y: waveY, length: 7, Palette.seaLight)
                canvas.hLine(x: x + 2, y: waveY - 1, length: 3, Palette.seaLight)
            }
        }
        canvas.fill(x: 0, y: shore, width: width, height: height - shore, Palette.wetSand)
        for x in 0..<width {
            let crest = Int((sin(Double(x) / 7) + 1) * 1.5)
            canvas.vLine(x: x, y: shore - 1 + crest, length: 2, Palette.foam)
        }
    }

    static func drawGround(_ canvas: inout PixelCanvas, tileX: Int, tileY: Int, isFirstRow: Bool) {
        let tile = HallRenderer.tilePixels
        let x = tileX * tile
        let y = tileY * tile
        canvas.fill(x: x, y: y, width: tile, height: tile, Palette.sand)
        if isFirstRow { canvas.fill(x: x, y: y, width: tile, height: 4, Palette.wetSand) }
        for grain in 0..<5 {
            let hash = pixelHash(tileX, tileY, grain)
            canvas.set(x + hash % tile, y + (hash / 32) % tile, grain % 2 == 0 ? Palette.sandLight : Palette.sandDark)
        }
        if pixelHash(tileX, tileY, 9) % 9 == 0 {
            let rippleY = y + 6 + pixelHash(tileX, tileY, 10) % 6
            canvas.hLine(x: x + 3, y: rippleY, length: 6, Palette.sandDark)
            canvas.hLine(x: x + 5, y: rippleY - 1, length: 3, Palette.sandLight)
        }
    }

    // MARK: Props

    static func drawProp(_ kind: LayoutProp.Kind, on canvas: inout PixelCanvas, in rect: PixelRect, seed: Int) -> Bool {
        switch kind {
        case .boardwalk: drawBoardwalk(&canvas, rect)
        case .palm: drawPalm(&canvas, rect)
        case .umbrella: drawUmbrella(&canvas, rect)
        case .towel: drawTowel(&canvas, rect, seed: seed)
        case .sandcastle: drawSandcastle(&canvas, rect)
        case .shell: drawShell(&canvas, rect)
        case .surfboard: drawSurfboard(&canvas, rect, seed: seed)
        default: return false
        }
        return true
    }

    /// Weathered planks running across, nailed at both ends.
    private static func drawBoardwalk(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let left = rect.x + 4
        let width = rect.width - 8
        for (index, plankY) in stride(from: rect.y, to: rect.maxY, by: 5).enumerated() {
            let height = min(4, rect.maxY - plankY)
            canvas.fill(x: left, y: plankY, width: width, height: height, index % 2 == 0 ? Palette.plank : Palette.plankAlt)
            canvas.hLine(x: left, y: plankY + height, length: width, Palette.plankSeam)
            canvas.set(left + 2, plankY + 1, Palette.nail)
            canvas.set(left + width - 3, plankY + 1, Palette.nail)
            canvas.hLine(x: left + 6 + pixelHash(index, 4) % (width - 16), y: plankY + 2, length: 5, Palette.plankAlt)
        }
        canvas.vLine(x: left - 1, y: rect.y, length: rect.height, Palette.plankSeam)
        canvas.vLine(x: left + width, y: rect.y, length: rect.height, Palette.plankSeam)
    }

    /// A gently curving trunk with drooping fronds and a cluster of coconuts.
    private static func drawPalm(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.ellipse(centerX: Double(rect.midX + 6), centerY: Double(rect.maxY - 3), radiusX: 13, radiusY: 3, Palette.shadow)
        let crownX = Double(rect.midX + 3)
        let crownY = Double(rect.y + 12)
        for segment in 0..<12 {
            let progress = Double(segment) / 11
            let x = Double(rect.midX - 3) + progress * progress * 6
            let y = Double(rect.maxY - 4) - progress * (Double(rect.maxY - 4) - crownY)
            canvas.fill(x: Int(x), y: Int(y) - 3, width: 5, height: 4, segment % 2 == 0 ? Palette.trunk : Palette.trunkDark)
        }
        let fronds: [(angle: Double, length: Double)] = [(-2.9, 15), (-2.2, 13), (-1.4, 11), (-0.9, 13), (-0.25, 15), (0.5, 12), (2.6, 12)]
        for frond in fronds {
            for step in stride(from: 0.0, through: frond.length, by: 1) {
                let droop = step * step / (frond.length * 4)
                let x = crownX + cos(frond.angle) * step
                let y = crownY + sin(frond.angle) * step + droop
                let thickness = 2.6 - step / frond.length * 1.6
                canvas.disc(centerX: x, centerY: y + 0.6, radius: thickness, Palette.leafDark)
                canvas.disc(centerX: x, centerY: y, radius: thickness - 0.4, step < frond.length / 2 ? Palette.leaf : Palette.leafLight)
            }
        }
        for (x, y) in [(-2.0, 3.0), (2.0, 3.0), (0.0, 5.0)] {
            canvas.disc(centerX: crownX + x, centerY: crownY + y, radius: 1.8, Palette.coconut)
        }
    }

    /// A red-and-white striped parasol and its round shadow.
    private static func drawUmbrella(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let centerX = Double(rect.midX)
        let canopyY = Double(rect.y + 12)
        canvas.ellipse(centerX: centerX + 3, centerY: Double(rect.maxY - 5), radiusX: 13, radiusY: 4, Palette.shadow)
        canvas.vLine(x: rect.midX, y: Int(canopyY), length: rect.maxY - Int(canopyY) - 4, Palette.pole)
        let radius = 14.0
        for y in Int(canopyY - radius)...Int(canopyY) {
            for x in Int(centerX - radius)...Int(centerX + radius) {
                let dx = Double(x) + 0.5 - centerX
                let dy = Double(y) + 0.5 - canopyY
                guard dx * dx + dy * dy <= radius * radius, dy <= 0 else { continue }
                let segment = Int((atan2(dy, dx) + .pi) / (.pi / 6))
                canvas.set(x, y, segment % 2 == 0 ? Palette.umbrellaRed : Palette.umbrellaWhite)
            }
        }
        for x in stride(from: rect.midX - 14, through: rect.midX + 12, by: 4) {
            canvas.hLine(x: x, y: Int(canopyY) + 1, length: 2, Palette.umbrellaRed)
        }
        canvas.set(rect.midX, Int(canopyY - radius) - 1, Palette.pole)
    }

    private static func drawTowel(_ canvas: inout PixelCanvas, _ rect: PixelRect, seed: Int) {
        let stripe = seed % 2 == 0 ? Palette.towelBlue : Palette.umbrellaRed
        canvas.fill(x: rect.x + 2, y: rect.y + 3, width: rect.width - 4, height: 10, Palette.umbrellaWhite)
        for stripeY in stride(from: rect.y + 3, to: rect.y + 13, by: 4) {
            canvas.fill(x: rect.x + 2, y: stripeY, width: rect.width - 4, height: 2, stripe)
        }
        canvas.vLine(x: rect.x + 8, y: rect.y + 3, length: 10, Palette.towelYellow)
        for fringeY in stride(from: rect.y + 3, to: rect.y + 13, by: 2) {
            canvas.set(rect.x + 1, fringeY, Palette.umbrellaWhite)
            canvas.set(rect.maxX - 2, fringeY, Palette.umbrellaWhite)
        }
    }

    /// Three towers with crenellations, a gate and a little flag.
    private static func drawSandcastle(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        let (x, y) = (rect.x, rect.y)
        canvas.ellipse(centerX: Double(rect.midX), centerY: Double(rect.maxY - 3), radiusX: 15, radiusY: 3, Palette.shadow)
        canvas.fill(x: x + 4, y: y + 18, width: 24, height: 11, Palette.sandDark)
        canvas.fill(x: x + 5, y: y + 18, width: 22, height: 9, Palette.sand)
        for towerX in [x + 3, x + 23] {
            canvas.fill(x: towerX, y: y + 12, width: 7, height: 15, Palette.sandDark)
            canvas.fill(x: towerX + 1, y: y + 12, width: 5, height: 13, Palette.sandLight)
            canvas.set(towerX + 1, y + 11, Palette.sandDark)
            canvas.set(towerX + 3, y + 11, Palette.sandDark)
            canvas.set(towerX + 5, y + 11, Palette.sandDark)
        }
        canvas.fill(x: x + 12, y: y + 8, width: 8, height: 18, Palette.sandDark)
        canvas.fill(x: x + 13, y: y + 8, width: 6, height: 16, Palette.sandLight)
        canvas.set(x + 13, y + 7, Palette.sandDark)
        canvas.set(x + 16, y + 7, Palette.sandDark)
        canvas.set(x + 18, y + 7, Palette.sandDark)
        canvas.fill(x: x + 14, y: y + 20, width: 4, height: 6, Palette.wetSand)
        canvas.vLine(x: x + 16, y: y + 1, length: 7, Palette.trunkDark)
        canvas.fill(x: x + 17, y: y + 1, width: 4, height: 3, Palette.flag)
    }

    private static func drawShell(_ canvas: inout PixelCanvas, _ rect: PixelRect) {
        canvas.stamp([
            "................",
            "................",
            "................",
            "................",
            "................",
            "......PPPP......",
            ".....PLPPLP.....",
            "....PPLPPLPP....",
            "....PPLPPLPP....",
            ".....PLPPLP.....",
            "......PPPP......",
            ".......PP.......",
            "................",
            "................",
            "................",
            "................",
        ], x: rect.x, y: rect.y, palette: ["P": Palette.shellPink, "L": Palette.shellLine])
    }

    /// A board standing upright in the sand.
    private static func drawSurfboard(_ canvas: inout PixelCanvas, _ rect: PixelRect, seed: Int) {
        let body = seed % 2 == 0 ? Palette.surfOrange : Palette.surfTeal
        let accent = seed % 2 == 0 ? Palette.surfTeal : Palette.towelYellow
        let centerX = Double(rect.midX)
        let centerY = Double(rect.midY - 2)
        let halfLength = Double(rect.height) / 2 - 4
        canvas.ellipse(centerX: centerX, centerY: centerY, radiusX: 6, radiusY: halfLength, Palette.surfEdge)
        canvas.ellipse(centerX: centerX, centerY: centerY, radiusX: 5, radiusY: halfLength - 1, body)
        canvas.vLine(x: rect.midX, y: Int(centerY - halfLength) + 4, length: Int(halfLength * 2) - 8, accent)
        canvas.ellipse(centerX: centerX + 4, centerY: Double(rect.maxY - 3), radiusX: 6, radiusY: 2, Palette.shadow)
    }
}
