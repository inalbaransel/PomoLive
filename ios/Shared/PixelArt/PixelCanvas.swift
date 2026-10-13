import CoreGraphics
import Foundation

/// An sRGB color packed as `0xRRGGBBAA`, the unit every sprite is authored in.
struct PixelColor: Hashable, Sendable {
    let rgba: UInt32

    init(_ rgba: UInt32) {
        self.rgba = rgba
    }

    static let clear = PixelColor(0x0000_0000)

    func withAlpha(_ alpha: UInt8) -> PixelColor {
        PixelColor(rgba & 0xFFFF_FF00 | UInt32(alpha))
    }
}

/// A tiny RGBA framebuffer with top-left origin. Sprites are drawn here and turned into a `CGImage`
/// that SwiftUI scales with nearest-neighbour sampling, so every art pixel stays crisp.
struct PixelCanvas {
    let width: Int
    let height: Int
    private var pixels: [UInt32]

    init(width: Int, height: Int, fill: PixelColor = .clear) {
        self.width = width
        self.height = height
        pixels = Array(repeating: fill.rgba, count: width * height)
    }

    mutating func set(_ x: Int, _ y: Int, _ color: PixelColor) {
        guard x >= 0, y >= 0, x < width, y < height else { return }
        let alpha = color.rgba & 0xFF
        if alpha == 0xFF {
            pixels[y * width + x] = color.rgba
        } else if alpha > 0 {
            pixels[y * width + x] = Self.blend(color.rgba, over: pixels[y * width + x])
        }
    }

    mutating func fill(x: Int, y: Int, width: Int, height: Int, _ color: PixelColor) {
        for row in y..<(y + height) {
            for column in x..<(x + width) { set(column, row, color) }
        }
    }

    mutating func hLine(x: Int, y: Int, length: Int, _ color: PixelColor) {
        fill(x: x, y: y, width: length, height: 1, color)
    }

    mutating func vLine(x: Int, y: Int, length: Int, _ color: PixelColor) {
        fill(x: x, y: y, width: 1, height: length, color)
    }

    mutating func stroke(x: Int, y: Int, width: Int, height: Int, _ color: PixelColor) {
        hLine(x: x, y: y, length: width, color)
        hLine(x: x, y: y + height - 1, length: width, color)
        vLine(x: x, y: y, length: height, color)
        vLine(x: x + width - 1, y: y, length: height, color)
    }

    mutating func disc(centerX: Double, centerY: Double, radius: Double, _ color: PixelColor) {
        let bounds = Int((centerY - radius).rounded(.down))...Int((centerY + radius).rounded(.up))
        for y in bounds {
            for x in Int((centerX - radius).rounded(.down))...Int((centerX + radius).rounded(.up)) {
                let dx = Double(x) + 0.5 - centerX
                let dy = Double(y) + 0.5 - centerY
                if dx * dx + dy * dy <= radius * radius { set(x, y, color) }
            }
        }
    }

    /// Draws a sprite authored as strings, one character per pixel. Characters missing from `palette` are transparent.
    mutating func stamp(_ rows: [String], x: Int, y: Int, palette: [Character: PixelColor]) {
        for (rowIndex, row) in rows.enumerated() {
            for (columnIndex, key) in row.enumerated() {
                if let color = palette[key] { set(x + columnIndex, y + rowIndex, color) }
            }
        }
    }

    mutating func draw(_ other: PixelCanvas, x: Int, y: Int) {
        for row in 0..<other.height {
            for column in 0..<other.width {
                set(x + column, y + row, PixelColor(other.pixels[row * other.width + column]))
            }
        }
    }

    func makeImage() -> CGImage {
        let bytes = pixels.flatMap { value in
            [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        }
        let provider = CGDataProvider(data: Data(bytes) as CFData)!
        return CGImage(
            width: width,
            height: height,
            bitsPerComponent: 8,
            bitsPerPixel: 32,
            bytesPerRow: width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.last.rawValue),
            provider: provider,
            decode: nil,
            shouldInterpolate: false,
            intent: .defaultIntent
        )!
    }

    private static func blend(_ source: UInt32, over destination: UInt32) -> UInt32 {
        let alpha = Double(source & 0xFF) / 255
        func channel(_ shift: UInt32) -> UInt32 {
            let top = Double((source >> shift) & 0xFF)
            let bottom = Double((destination >> shift) & 0xFF)
            return UInt32((top * alpha + bottom * (1 - alpha)).rounded()) << shift
        }
        let resultAlpha = max(source & 0xFF, destination & 0xFF)
        return channel(24) | channel(16) | channel(8) | resultAlpha
    }
}
