/// The hall's 16-bit palette: warm wood, deep library greens and lamp gold.
enum HallPalette {
    static let outline = PixelColor(0x2B21_33FF)
    static let void = PixelColor(0x1A14_20FF)

    static let floorLight = PixelColor(0xB07A_4AFF)
    static let floorMid = PixelColor(0x9C69_3DFF)
    static let floorDark = PixelColor(0x7E52_2FFF)
    static let floorSeam = PixelColor(0x5E3C_22FF)

    static let wallTop = PixelColor(0x2F3B_33FF)
    static let wallpaper = PixelColor(0x3F5A_48FF)
    static let wallpaperStripe = PixelColor(0x4B6B_55FF)
    static let wainscot = PixelColor(0x5E3C_22FF)
    static let wainscotHighlight = PixelColor(0x7E52_2FFF)

    static let rug = PixelColor(0x8E2F_36FF)
    static let rugPattern = PixelColor(0xA8414AFF)
    static let rugBorder = PixelColor(0xE0B0_4CFF)

    static let woodLight = PixelColor(0xC48A_52FF)
    static let wood = PixelColor(0xA06A_3BFF)
    static let woodDark = PixelColor(0x6E43_24FF)

    static let glass = PixelColor(0x9FD3_E8FF)
    static let glassShine = PixelColor(0xE4F6_FBFF)
    static let windowFrame = PixelColor(0xE9DD_C4FF)

    static let leaf = PixelColor(0x3E8E_5EFF)
    static let leafLight = PixelColor(0x6CC0_7AFF)
    static let pot = PixelColor(0xC56A_3EFF)

    static let metal = PixelColor(0x5D70_80FF)
    static let metalLight = PixelColor(0x8FA3_B3FF)
    static let paper = PixelColor(0xF4EE_E0FF)
    static let lampGold = PixelColor(0xF9BF_4AFF)
    static let lampGlow = PixelColor(0xFFE0_8A55)
    static let screenGlow = PixelColor(0x4DE1_F2FF)

    static let bookSpines: [PixelColor] = [
        PixelColor(0xC0392BFF), PixelColor(0x2E86_C1FF), PixelColor(0xF9BF_4AFF),
        PixelColor(0x3E8E_5EFF), PixelColor(0x8E44_ADFF), PixelColor(0xE06A_2BFF),
        PixelColor(0xF4EE_E0FF),
    ]
}
