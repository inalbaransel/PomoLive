import SwiftUI

/// What the full-screen focus mode shows.
enum FocusModeStyle: String, CaseIterable, Identifiable {
    /// A large clock on pure black.
    case clock
    /// The room in the dark: only lit desks glow, with a small clock in the corner.
    case nightMap

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .clock: "Saat"
        case .nightMap: "Gece Haritası"
        }
    }

    var symbol: String {
        switch self {
        case .clock: "clock.fill"
        case .nightMap: "moon.stars.fill"
        }
    }
}

/// The clock face in `FocusModeStyle.clock`.
enum ClockFace: String, CaseIterable, Identifiable {
    case digital, ring, analog

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .digital: "Dijital"
        case .ring: "Halka"
        case .analog: "Kadran"
        }
    }

    var symbol: String {
        switch self {
        case .digital: "textformat.123"
        case .ring: "circle.circle"
        case .analog: "clock"
        }
    }
}

/// The ink colour of the focus mode. Dim, warm tones are kindest to eyes and OLED panels at night.
enum ClockTint: String, CaseIterable, Identifiable {
    case white, indigo, amber, mint, red

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .white: Color(white: 0.92)
        case .indigo: Color(red: 0.55, green: 0.55, blue: 1)
        case .amber: Color(red: 1, green: 0.72, blue: 0.3)
        case .mint: Color(red: 0.45, green: 0.95, blue: 0.78)
        case .red: Color(red: 1, green: 0.32, blue: 0.28)
        }
    }

    var title: LocalizedStringKey {
        switch self {
        case .white: "Beyaz"
        case .indigo: "Çivit"
        case .amber: "Kehribar"
        case .mint: "Nane"
        case .red: "Gece Kırmızısı"
        }
    }
}
