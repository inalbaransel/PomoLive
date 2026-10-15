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

    // MARK: - Coffee Shop Palette (Gece Kafesi)

    // Brick Wall
    static let cafeWallTop = PixelColor(0x3A21_1DFF)
    static let cafeBrickMain = PixelColor(0x823E_32FF)
    static let cafeBrickDark = PixelColor(0x6D31_27FF)
    static let cafeBrickLight = PixelColor(0x994D_3FFF)
    static let cafeBrickMortar = PixelColor(0x4220_1BFF)
    static let cafeWainscot = PixelColor(0x4424_17FF)
    static let cafeWainscotHighlight = PixelColor(0x5E34_22FF)

    // Espresso Wood Floor
    static let cafeFloorLight = PixelColor(0x6140_2EFF)
    static let cafeFloorMid = PixelColor(0x4E32_23FF)
    static let cafeFloorDark = PixelColor(0x3D25_19FF)
    static let cafeFloorSeam = PixelColor(0x2B18_0FFF)

    // Cafe Runner Rug
    static let cafeRug = PixelColor(0x9E4B_2CFF)
    static let cafeRugBorder = PixelColor(0xDBA0_53FF)
    static let cafeRugPattern = PixelColor(0xB85D_34FF)

    // Glowing Neon Sign
    static let neonTube = PixelColor(0xFF8DAFFF)
    static let neonMain = PixelColor(0xFF33_77FF)
    static let neonGlow = PixelColor(0xFF33_7744)
    static let neonWarmGold = PixelColor(0xFFBA_42FF)
    static let neonWarmGlow = PixelColor(0xFFBA_4244)

    // Chalkboard
    static let slateBlack = PixelColor(0x2226_2BFF)
    static let chalkboardFrame = PixelColor(0x4E30_1EFF)
    static let chalkWhite = PixelColor(0xF0ECE1FF)
    static let chalkYellow = PixelColor(0xF5CF_6CFF)
    static let chalkOrange = PixelColor(0xF08A_4BFF)

    // Night Window
    static let nightGlass = PixelColor(0x1B24_33FF)
    static let nightShine = PixelColor(0x5671_9CFF)

    // Coffee Counter & Pastry Case
    static let marbleTop = PixelColor(0xEAE4_DAFF)
    static let marbleVein = PixelColor(0xBFB6_A8FF)
    static let pastryGold = PixelColor(0xD991_3CFF)
}
