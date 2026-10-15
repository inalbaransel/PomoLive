import CoreGraphics

/// The pixel characters readers can pick. Raw values match the server's `AVATAR_SPRITE_IDS`.
enum AvatarSprite: String, CaseIterable, Identifiable, Sendable {
    case scholar = "scholar_01"
    case wizard = "wizard_dev_01"
    case knight = "knight_01"
    case ranger = "ranger_01"
    case bard = "bard_01"
    case robot = "robot_01"

    enum Pose: Hashable, Sendable {
        case idle
        case typing(frame: Int)
        case sipping(frame: Int)
    }

    static let size = 16

    var id: String { rawValue }

    init(id: String) {
        self = AvatarSprite(rawValue: id) ?? .scholar
    }

    var displayName: String {
        switch self {
        case .scholar: String(localized: "Akademisyen")
        case .wizard: String(localized: "Kod Büyücüsü")
        case .knight: String(localized: "Şövalye")
        case .ranger: String(localized: "Gezgin")
        case .bard: String(localized: "Ozan")
        case .robot: String(localized: "Robot")
        }
    }

    /// A 16×16 seated upper body; the desk drawn in front of it hides the legs.
    func canvas(_ pose: Pose) -> PixelCanvas {
        var canvas = PixelCanvas(width: Self.size, height: Self.size)
        canvas.stamp(Self.body(for: pose), x: 0, y: 8, palette: palette)
        canvas.stamp(head, x: 0, y: 0, palette: palette)
        if case .sipping(let frame) = pose {
            canvas.stamp(Self.cup, x: 9, y: frame == 0 ? 9 : 7, palette: Self.cupPalette)
        }
        return canvas
    }

    func image(_ pose: Pose) -> CGImage {
        canvas(pose).makeImage()
    }

    // MARK: - Art

    private var head: [String] {
        switch self {
        case .scholar: [
            "................",
            "................",
            ".....HHHHHH.....",
            "....HHHHHHHH....",
            "....HSSSSSSH....",
            "....SSESSESS....",
            "....SSSSSSSS....",
            ".....SSSSSS.....",
        ]
        case .wizard: [
            ".......PP.......",
            "......PPPY......",
            ".....PPPPPP.....",
            "....PPPPPPPP....",
            "...YYYYYYYYYY...",
            "....SSESSESS....",
            "....SSSSSSSS....",
            ".....SHHHHS.....",
        ]
        case .knight: [
            "................",
            ".....GGGGGG.....",
            "....GGGGGGGG....",
            "....GLLLLLLG....",
            "....GDDDDDDG....",
            "....GGGGGGGG....",
            "....GGGLLGGG....",
            ".....GGGGGG.....",
        ]
        case .ranger: [
            "................",
            ".....HHHHHH.....",
            "....HHHHHHHH....",
            "...HHSSSSSSHH...",
            "...HSSESSESSH...",
            "...HSSSSSSSSH...",
            "....HSSSSSSH....",
            ".....HHHHHH.....",
        ]
        case .bard: [
            "..........F.....",
            ".....BBBBBF.....",
            "...BBBBBBBBB....",
            "....HSSSSSSH....",
            "....SSESSESS....",
            "....SSSSSSSS....",
            ".....SSSSSS.....",
            "................",
        ]
        case .robot: [
            ".......A........",
            ".......A........",
            "....MMMMMMMM....",
            "....MLLLLLLM....",
            "....MEEMMEEM....",
            "....MMMMMMMM....",
            "....MMDDDDMM....",
            ".....MMMMMM.....",
        ]
        }
    }

    private static func body(for pose: Pose) -> [String] {
        switch pose {
        case .idle: [
            "....CCCCCCCC....",
            "...CCCCAACCCC...",
            "..CCCCCAACCCCC..",
            "..CCCCCCCCCCCC..",
            "..SCCCCCCCCCCS..",
            "...CCCCCCCCCC...",
            "...CCCCCCCCCC...",
            "...CCCCCCCCCC...",
        ]
        case .typing(let frame) where frame == 0: [
            "....CCCCCCCC....",
            "...CCCCAACCCC...",
            "..CCCCCAACCCCC..",
            "..CCCCCCCCCCCC..",
            "..CC.CCCCCC.CC..",
            "..CS.CCCCCC.SC..",
            "...CCCCCCCCCC...",
            "...CCCCCCCCCC...",
        ]
        case .typing: [
            "....CCCCCCCC....",
            "...CCCCAACCCC...",
            "..CCCCCAACCCCC..",
            "..CCCCCCCCCCCC..",
            "..CC.CCCCCC.CC..",
            "...CSCCCCCCSC...",
            "...CCCCCCCCCC...",
            "...CCCCCCCCCC...",
        ]
        case .sipping: [
            "....CCCCCCCC....",
            "...CCCCAACCCC...",
            "..CCCCCAACCCCC..",
            "..CCCCCCCCCCCC..",
            "..SCCCCCCCC.CC..",
            "...CCCCCCCC.CC..",
            "...CCCCCCCCCC...",
            "...CCCCCCCCCC...",
        ]
        }
    }

    private static let cup = [
        ".W.W.",
        "KKKK.",
        "KKKKK",
        "KKKK.",
        ".SS..",
    ]

    private static let cupPalette: [Character: PixelColor] = [
        "W": PixelColor(0xFFFF_FF99),
        "K": PixelColor(0xF4EE_E0FF),
        "S": PixelColor(0xF2C2_9BFF),
    ]

    private var palette: [Character: PixelColor] {
        var colors: [Character: PixelColor] = [
            "S": PixelColor(0xF2C2_9BFF),
            "E": PixelColor(0x2B21_33FF),
            "D": PixelColor(0x2B21_33FF),
        ]
        switch self {
        case .scholar:
            colors["H"] = PixelColor(0x6B42_26FF)
            colors["C"] = PixelColor(0x3E8E_5EFF)
            colors["A"] = PixelColor(0xF4EE_E0FF)
        case .wizard:
            colors["P"] = PixelColor(0x6A3F_B5FF)
            colors["Y"] = PixelColor(0xF9BF_4AFF)
            colors["H"] = PixelColor(0xD9D4_E8FF)
            colors["C"] = PixelColor(0x4B2C_8AFF)
            colors["A"] = PixelColor(0xF9BF_4AFF)
        case .knight:
            colors["G"] = PixelColor(0xA9B2_BFFF)
            colors["L"] = PixelColor(0xD8DF_E8FF)
            colors["C"] = PixelColor(0x7C86_96FF)
            colors["A"] = PixelColor(0xC0392BFF)
            colors["S"] = PixelColor(0xA9B2_BFFF)
        case .ranger:
            colors["H"] = PixelColor(0x2F5D_3AFF)
            colors["C"] = PixelColor(0x4F7A_3AFF)
            colors["A"] = PixelColor(0x8B5A_2BFF)
        case .bard:
            colors["B"] = PixelColor(0xC0392BFF)
            colors["F"] = PixelColor(0xF4EE_E0FF)
            colors["H"] = PixelColor(0xE0A2_3CFF)
            colors["C"] = PixelColor(0xE06A_2BFF)
            colors["A"] = PixelColor(0xF9BF_4AFF)
        case .robot:
            colors["M"] = PixelColor(0x8FA3_B3FF)
            colors["L"] = PixelColor(0xC3D2_DEFF)
            colors["E"] = PixelColor(0x4DE1_F2FF)
            colors["A"] = PixelColor(0xE74C_3CFF)
            colors["C"] = PixelColor(0x5D70_80FF)
            colors["S"] = PixelColor(0x8FA3_B3FF)
        }
        return colors
    }
}
