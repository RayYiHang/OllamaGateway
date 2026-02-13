import SwiftUI

// MARK: - Theme

struct AppTheme {
    let background: Color
    let cardBackground: Color
    let cardBorder: Color
    let primaryText: Color
    let secondaryText: Color
    let accent: Color
    let accentGradient: LinearGradient
    let success: Color
    let warning: Color
    let error: Color
    let sidebarBackground: Color

    static let dark = AppTheme(
        background: Color(r: 13, g: 17, b: 23),
        cardBackground: Color(r: 22, g: 27, b: 34),
        cardBorder: Color(r: 48, g: 54, b: 61),
        primaryText: Color(r: 240, g: 246, b: 252),
        secondaryText: Color(r: 139, g: 148, b: 158),
        accent: Color(r: 0, g: 212, b: 170),
        accentGradient: LinearGradient(
            colors: [Color(r: 0, g: 212, b: 170), Color(r: 0, g: 180, b: 216)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        success: Color(r: 63, g: 185, b: 80),
        warning: Color(r: 210, g: 153, b: 34),
        error: Color(r: 248, g: 81, b: 73),
        sidebarBackground: Color(r: 13, g: 17, b: 23)
    )

    static let light = AppTheme(
        background: Color(r: 246, g: 248, b: 250),
        cardBackground: .white,
        cardBorder: Color(r: 208, g: 215, b: 222),
        primaryText: Color(r: 36, g: 41, b: 47),
        secondaryText: Color(r: 87, g: 96, b: 106),
        accent: Color(r: 0, g: 184, b: 148),
        accentGradient: LinearGradient(
            colors: [Color(r: 0, g: 184, b: 148), Color(r: 0, g: 160, b: 200)],
            startPoint: .topLeading, endPoint: .bottomTrailing
        ),
        success: Color(r: 26, g: 127, b: 55),
        warning: Color(r: 154, g: 103, b: 0),
        error: Color(r: 207, g: 34, b: 46),
        sidebarBackground: Color(r: 240, g: 242, b: 245)
    )
}

// MARK: - Color Extension

extension Color {
    init(r: Int, g: Int, b: Int, a: Double = 1.0) {
        self.init(red: Double(r) / 255.0, green: Double(g) / 255.0, blue: Double(b) / 255.0, opacity: a)
    }

    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        switch hex.count {
        case 6:
            (r, g, b) = (int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (0, 0, 0)
        }
        self.init(red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}

// MARK: - Theme Environment

struct ThemeKey: EnvironmentKey {
    static let defaultValue: AppTheme = .dark
}

extension EnvironmentValues {
    var theme: AppTheme {
        get { self[ThemeKey.self] }
        set { self[ThemeKey.self] = newValue }
    }
}

// MARK: - Theme Helper

extension ThemeMode {
    func resolvedTheme(systemScheme: ColorScheme?) -> AppTheme {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system:
            return systemScheme == .light ? .light : .dark
        }
    }

    func colorScheme() -> ColorScheme? {
        switch self {
        case .dark: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}
