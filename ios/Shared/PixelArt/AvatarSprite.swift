import CoreGraphics

/// The pixel characters readers can pick. Raw values match the server's `AVATAR_SPRITE_IDS`.
enum AvatarSprite: String, CaseIterable, Identifiable, Sendable {
    case scholar = "scholar_01"
    case wizard = "wizard_dev_01"
    case knight = "knight_01"
    case ranger = "ranger_01"
    case bard = "bard_01"
    case robot = "robot_01"
    case student = "student_f_01"
    case coder = "coder_m_01"
    case artist = "artist_f_01"
    case athlete = "athlete_m_01"
    case doctor = "doctor_f_01"
    case gamer = "gamer_m_01"
    case scientist = "scientist_f_01"
    case hijabi = "hijab_f_01"
    case cat = "cat_01"
    case blonde = "blonde_f_01"
    case ponytail = "ponytail_f_01"
    case flower = "flower_f_01"
    case pinkBuns = "pink_buns_f_01"

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
        case .student: String(localized: "Öğrenci")
        case .coder: String(localized: "Yazılımcı")
        case .artist: String(localized: "Ressam")
        case .athlete: String(localized: "Sporcu")
        case .doctor: String(localized: "Doktor")
        case .gamer: String(localized: "Oyuncu")
        case .scientist: String(localized: "Bilim İnsanı")
        case .hijabi: String(localized: "Kitap Kurdu")
        case .cat: String(localized: "Kedi")
        case .blonde: String(localized: "Sarışın")
        case .ponytail: String(localized: "Atkuyruklu")
        case .flower: String(localized: "Çiçekli")
        case .pinkBuns: String(localized: "Pembe Topuz")
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
        case .student: [
            "................",
            ".....HHHHHH.....",
            "....HHHHHHHH....",
            "...HHSSSSSSHH...",
            "...HSSESSESSH...",
            "...HSSSSSSSSH...",
            "...HHSSPPSSHH...",
            "...HH.SSSS.HH...",
        ]
        case .coder: [
            "................",
            "....HHHHHHH.....",
            "....HHHHHHHH....",
            "....HSSSSSSS....",
            "....GEGSSGEG....",
            "....SSSSSSSS....",
            ".....SSSSSS.....",
            "................",
        ]
        case .artist: [
            ".........B......",
            "....BBBBBBB.....",
            "...BBBBBBBBB....",
            "...HHSSSSSSHH...",
            "...HSSESSESSH...",
            "...HSSSSSSSSH...",
            "....HSSPPSSH....",
            "....HH....HH....",
        ]
        case .athlete: [
            "................",
            ".....HHHHHH.....",
            "....HHHHHHHH....",
            "....RRRRRRRR....",
            "....SSESSESS....",
            "....SSSSSSSS....",
            ".....SSSSSS.....",
            "................",
        ]
        case .doctor: [
            "......HHHH......",
            "......HHHH......",
            ".....HHHHHH.....",
            "....HHSSSSHH....",
            "....SSESSESS....",
            "....SSSSSSSS....",
            ".....SSPPSS.....",
            "................",
        ]
        case .gamer: [
            "................",
            ".....KKKKKK.....",
            "....K.HHHH.K....",
            "...KKHHHHHHKK...",
            "...RKSESSESKR...",
            "...RKSSSSSSKR...",
            "....SSSSSSSS....",
            ".....SSSSSS.....",
        ]
        case .scientist: [
            "....HHH.HHH.....",
            "...HHHHHHHHHH...",
            "...HHHHHHHHHH...",
            "...HHSSSSSSHH...",
            "...HGEGSSGEGH...",
            "...HSSSSSSSSH...",
            "...HHSSPPSSHH...",
            "....HH....HH....",
        ]
        case .hijabi: [
            "................",
            ".....WWWWWW.....",
            "....WWWWWWWW....",
            "...WWSSSSSSWW...",
            "...WSSESSESSW...",
            "...WSSSSSSSSW...",
            "...WWSSPPSSWW...",
            "....WWWWWWWW....",
        ]
        case .cat: [
            "...K........K...",
            "...KK......KK...",
            "...KKKKKKKKKK...",
            "...KKKKKKKKKK...",
            "...KKGKKKKGKK...",
            "...KKKKPPKKKK...",
            "....KKKKKKKK....",
            ".....KKKKKK.....",
        ]
        case .blonde: [
            "................",
            ".....HHHHHH.....",
            "....HHHHHHHH....",
            "...HHHHSSHHHH...",
            "...HSSESSESSH...",
            "...HSSSSSSSSH...",
            "...HHSSPPSSHH...",
            "...HH.SSSS.HH...",
        ]
        case .ponytail: [
            "..........RR....",
            ".....HHHHHRR....",
            "....HHHHHHHHH...",
            "...HHSSSSSSHHH..",
            "...HSSESSESSHH..",
            "....SSSSSSSS.H..",
            ".....SSPPSS.....",
            "................",
        ]
        case .flower: [
            "................",
            "....HHHHHHHF....",
            "...HHHHHHHFYF...",
            "...HHSSSSSSFH...",
            "...HSSESSESSH...",
            "...HSSSSSSSSH...",
            "...HHSSPPSSHH...",
            "...HHH....HHH...",
        ]
        case .pinkBuns: [
            "...HH......HH...",
            "..HHHHHHHHHHHH..",
            "....HHHHHHHH....",
            "....HSSSSSSH....",
            "....SSESSESS....",
            "....SSSSSSSS....",
            ".....SSPPSS.....",
            "................",
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
        case .student:
            colors["H"] = PixelColor(0x5A3825FF)
            colors["P"] = PixelColor(0xD9747CFF)
            colors["C"] = PixelColor(0x3F7FD9FF)
            colors["A"] = PixelColor(0xF4EE_E0FF)
        case .coder:
            colors["S"] = PixelColor(0xD9A066FF)
            colors["H"] = PixelColor(0x1F1A1CFF)
            colors["G"] = PixelColor(0x8FA3_B3FF)
            colors["C"] = PixelColor(0x3A3F4BFF)
            colors["A"] = PixelColor(0x4DE1_F2FF)
        case .artist:
            colors["B"] = PixelColor(0x2B2D42FF)
            colors["H"] = PixelColor(0xC2452DFF)
            colors["P"] = PixelColor(0xD9747CFF)
            colors["C"] = PixelColor(0xF2D16BFF)
            colors["A"] = PixelColor(0xE86A8AFF)
        case .athlete:
            colors["S"] = PixelColor(0x8D5524FF)
            colors["H"] = PixelColor(0x1F1A1CFF)
            colors["R"] = PixelColor(0xE2534AFF)
            colors["C"] = PixelColor(0xE2534AFF)
            colors["A"] = PixelColor(0xF4EE_E0FF)
        case .doctor:
            colors["H"] = PixelColor(0xE8C46AFF)
            colors["P"] = PixelColor(0xD9747CFF)
            colors["C"] = PixelColor(0xF4F6F8FF)
            colors["A"] = PixelColor(0x3EC1B5FF)
        case .gamer:
            colors["S"] = PixelColor(0xC68642FF)
            colors["H"] = PixelColor(0x3B2A1EFF)
            colors["K"] = PixelColor(0x222428FF)
            colors["R"] = PixelColor(0x8E44_ADFF)
            colors["C"] = PixelColor(0x8E44_ADFF)
            colors["A"] = PixelColor(0x2ECC71FF)
        case .scientist:
            colors["S"] = PixelColor(0x8D5524FF)
            colors["H"] = PixelColor(0x1F1A1CFF)
            colors["G"] = PixelColor(0xC0C6CFFF)
            colors["P"] = PixelColor(0xA8505AFF)
            colors["C"] = PixelColor(0xF4F6F8FF)
            colors["A"] = PixelColor(0x6A3F_B5FF)
        case .hijabi:
            colors["S"] = PixelColor(0xD9A066FF)
            colors["W"] = PixelColor(0x2E8B7AFF)
            colors["P"] = PixelColor(0xB5606AFF)
            colors["C"] = PixelColor(0x2E8B7AFF)
            colors["A"] = PixelColor(0xF2D16BFF)
        case .cat:
            colors["K"] = PixelColor(0xE89A4AFF)
            colors["G"] = PixelColor(0x3DBE5AFF)
            colors["P"] = PixelColor(0xF29BB0FF)
            colors["S"] = PixelColor(0xE89A4AFF)
            colors["C"] = PixelColor(0xE89A4AFF)
            colors["A"] = PixelColor(0xF7F3EAFF)
        case .blonde:
            colors["H"] = PixelColor(0xF2D16BFF)
            colors["P"] = PixelColor(0xE0707EFF)
            colors["C"] = PixelColor(0xF29BB0FF)
            colors["A"] = PixelColor(0xF7F3EAFF)
        case .ponytail:
            colors["S"] = PixelColor(0xE8B88AFF)
            colors["H"] = PixelColor(0x6B3E26FF)
            colors["R"] = PixelColor(0xE2534AFF)
            colors["P"] = PixelColor(0xD9606EFF)
            colors["C"] = PixelColor(0xF7F3EAFF)
            colors["A"] = PixelColor(0xE2534AFF)
        case .flower:
            colors["S"] = PixelColor(0xD9A066FF)
            colors["H"] = PixelColor(0x1F1A1CFF)
            colors["F"] = PixelColor(0xF4A6C0FF)
            colors["Y"] = PixelColor(0xF6D44AFF)
            colors["P"] = PixelColor(0xC2505EFF)
            colors["C"] = PixelColor(0x6CC3EAFF)
            colors["A"] = PixelColor(0xF7F3EAFF)
        case .pinkBuns:
            colors["H"] = PixelColor(0xF29BC8FF)
            colors["P"] = PixelColor(0xE0707EFF)
            colors["C"] = PixelColor(0x9B8BE8FF)
            colors["A"] = PixelColor(0xF7F3EAFF)
        }
        return colors
    }
}
