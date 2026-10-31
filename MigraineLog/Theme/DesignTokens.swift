import SwiftUI

extension Color {
    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            UIColor(hex: traits.userInterfaceStyle == .dark ? dark : light)
        })
    }
}

extension UIColor {
    convenience init(hex: UInt) {
        self.init(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                  blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
    }
}

/// "Tide": cool sea-glass teal moving into deep indigo (design/directions/README.md,
/// direction B). Low-glare grey-mint surfaces in light mode, near-black teal
/// in dark mode, tonal tiles without borders. Deliberately unlike Simply BP's
/// warm paper and blue, and outside the purple most migraine apps use.
enum AppColors {
    static let bgApp = Color(light: 0xE6EDEC, dark: 0x0B1315)
    static let bgCard = Color(light: 0xF2F6F5, dark: 0x132023)
    /// Fills for inputs, segmented tracks and inactive chips.
    static let bgInput = Color(light: 0xD9E3E2, dark: 0x1B2B2E)

    static let textPrimary = Color(light: 0x0F2627, dark: 0xE1EDEB)
    static let textSecondary = Color(light: 0x486364, dark: 0x8DA6A7)
    static let separator = Color(light: 0xC9D6D5, dark: 0x213236)

    static let accent = Color(light: 0x146B66, dark: 0x5FCBBF)
    /// Fill behind white text (buttons, selected chips): 6.3:1 light, 5.5:1 dark.
    static let accentFill = Color(light: 0x146B66, dark: 0x13756F)
    static let accentTint = Color(light: 0xCDE6E2, dark: 0x16393A)

    /// Data colors only — the indigo end never becomes a button or tint.
    static let migraine = Color(light: 0x3A4AA3, dark: 0x8E98F2)
    static let headache = Color(light: 0x1B8F86, dark: 0x5FCBBF)

    static let danger = Color(light: 0xA3233A, dark: 0xF08A9B)
    /// The emergency note's fill under white text.
    static let dangerFill = Color(light: 0x8E1D33, dark: 0x8E1D33)
    static let success = Color(light: 0x1F7A4F, dark: 0x6FD3A0)
}

/// The pain ramp in five steps (1–2, 3–4, 5–6, 7–8, 9–10): darker with pain in
/// light mode, brighter in dark mode. Every use also prints the number, so it
/// reads without color.
enum PainRamp {
    private static let light: [UInt] = [0xC4E7E1, 0x80CCC3, 0x2C7F9A, 0x4351A6, 0x2B2C77]
    private static let dark: [UInt] = [0x1D4644, 0x2A7471, 0x3C97B6, 0x8098F0, 0xB9B6FF]
    /// Which steps carry dark text (the rest white), chosen for ≥ 4.5:1.
    private static let darkTextLight: Set<Int> = [0, 1]
    private static let darkTextDark: Set<Int> = [2, 3, 4]

    static func step(_ intensity: Int) -> Int { min(max((intensity - 1) / 2, 0), 4) }

    static func fill(_ intensity: Int) -> Color {
        let i = step(intensity)
        return Color(light: light[i], dark: dark[i])
    }

    static func text(_ intensity: Int) -> Color {
        let i = step(intensity)
        return Color(uiColor: UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            let darkText = isDark ? darkTextDark.contains(i) : darkTextLight.contains(i)
            return darkText ? UIColor(hex: isDark ? 0x0B1315 : 0x0F2627) : .white
        })
    }
}

extension IntensityLevel {
    /// The band's representative ramp color, for charts and labels.
    var color: Color {
        switch self {
        case .mild: PainRamp.fill(4)
        case .moderate: PainRamp.fill(6)
        case .severe: PainRamp.fill(9)
        }
    }
}

extension AttackKind {
    var color: Color {
        switch self {
        case .migraine: AppColors.migraine
        case .headache: AppColors.headache
        }
    }
}

enum AppFont {
    /// Big figures: ultralight SF Pro, calm rather than loud. Callers scale `size` with `@ScaledMetric`.
    static func hero(_ size: CGFloat) -> Font { .system(size: size, weight: .ultraLight) }
    /// Mid-size numbers in tiles and badges.
    static func number(_ size: CGFloat) -> Font { .system(size: size, weight: .light) }
}

enum AppShape {
    /// Tiles and panels.
    static let cardRadius: CGFloat = 16
    static let buttonRadius: CGFloat = 18
    static let chipRadius: CGFloat = 12
}
