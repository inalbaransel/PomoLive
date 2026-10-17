import SwiftUI

/// The Plus mark: a small pixel crown in the app's own 16-bit style, on a night-library tile.
struct PlusEmblem: View {
    var size: CGFloat = 40

    private static let crown: CGImage = {
        var canvas = PixelCanvas(width: 13, height: 9)
        canvas.stamp([
            "Y.....Y.....Y",
            "G.....G.....G",
            "GG...GGG...GG",
            "GGG.GGGGG.GGG",
            "GGGGGGGGGGGGG",
            "GGRGGGBGGGRGG",
            "GGGGGGGGGGGGG",
            "DDDDDDDDDDDDD",
            ".............",
        ], x: 0, y: 0, palette: [
            "Y": PixelColor(0xFFF1_A8FF),
            "G": PixelColor(0xF5B9_3BFF),
            "D": PixelColor(0xB97A_1EFF),
            "R": PixelColor(0xE0475AFF),
            "B": PixelColor(0x5B8CF0FF),
        ])
        return canvas.makeImage()
    }()

    var body: some View {
        Image(decorative: Self.crown, scale: 1)
            .resizable()
            .interpolation(.none)
            .aspectRatio(13 / 9, contentMode: .fit)
            .frame(width: size * 0.66)
            .frame(width: size, height: size)
            .background(
                LinearGradient(
                    colors: [Color(red: 0.2, green: 0.17, blue: 0.4), Color(red: 0.09, green: 0.08, blue: 0.2)],
                    startPoint: .top, endPoint: .bottom
                ),
                in: .rect(cornerRadius: size * 0.26)
            )
            .accessibilityHidden(true)
    }
}
