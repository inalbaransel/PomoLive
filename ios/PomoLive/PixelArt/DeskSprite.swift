import CoreGraphics

/// A desk node: chair, optional seated avatar, desk surface and reading lamp, on a 2×2 tile (32×32 px) canvas.
enum DeskSprite {
    struct Key: Hashable {
        var avatar: AvatarSprite?
        var phase: TimerPhase
        var frame: Int
    }

    static let pixels = 32

    static func render(_ key: Key) -> CGImage {
        var canvas = PixelCanvas(width: pixels, height: pixels)
        drawChair(&canvas)
        if let avatar = key.avatar {
            let pose: AvatarSprite.Pose = key.phase == .focus ? .typing(frame: key.frame) : .sipping(frame: key.frame)
            canvas.draw(avatar.canvas(pose), x: 8, y: 4)
        }
        drawDesk(&canvas, occupied: key.avatar != nil, phase: key.phase)
        return canvas.makeImage()
    }

    private static func drawChair(_ canvas: inout PixelCanvas) {
        canvas.fill(x: 10, y: 6, width: 12, height: 12, HallPalette.woodDark)
        canvas.stroke(x: 10, y: 6, width: 12, height: 12, HallPalette.outline)
        canvas.fill(x: 12, y: 8, width: 8, height: 3, HallPalette.rug)
    }

    private static func drawDesk(_ canvas: inout PixelCanvas, occupied: Bool, phase: TimerPhase) {
        // Surface and front panel.
        canvas.fill(x: 1, y: 17, width: 30, height: 7, HallPalette.woodLight)
        canvas.hLine(x: 1, y: 17, length: 30, HallPalette.paper.withAlpha(0x40))
        canvas.fill(x: 1, y: 24, width: 30, height: 5, HallPalette.wood)
        canvas.hLine(x: 1, y: 24, length: 30, HallPalette.woodDark)
        canvas.fill(x: 2, y: 29, width: 3, height: 3, HallPalette.woodDark)
        canvas.fill(x: 27, y: 29, width: 3, height: 3, HallPalette.woodDark)
        canvas.stroke(x: 0, y: 16, width: 32, height: 14, HallPalette.outline)

        // Reading lamp, lit while someone is seated.
        if occupied {
            canvas.disc(centerX: 6, centerY: 20, radius: 6, HallPalette.lampGlow)
        }
        canvas.vLine(x: 5, y: 12, length: 9, HallPalette.metal)
        canvas.fill(x: 3, y: 20, width: 5, height: 2, HallPalette.metal)
        canvas.fill(x: 2, y: 9, width: 7, height: 4, occupied ? HallPalette.lampGold : HallPalette.metalLight)
        canvas.hLine(x: 2, y: 9, length: 7, HallPalette.outline)

        guard occupied else {
            canvas.fill(x: 20, y: 19, width: 7, height: 3, HallPalette.paper)
            canvas.vLine(x: 23, y: 19, length: 3, HallPalette.floorSeam)
            return
        }
        switch phase {
        case .focus:
            // Open laptop with a glowing screen.
            canvas.fill(x: 12, y: 18, width: 9, height: 4, HallPalette.metalLight)
            canvas.fill(x: 13, y: 18, width: 7, height: 2, HallPalette.screenGlow)
            canvas.hLine(x: 11, y: 22, length: 11, HallPalette.metal)
        case .rest:
            // Closed book while resting.
            canvas.fill(x: 13, y: 19, width: 7, height: 3, HallPalette.bookSpines[0])
            canvas.hLine(x: 13, y: 21, length: 7, HallPalette.paper)
        }
    }
}
