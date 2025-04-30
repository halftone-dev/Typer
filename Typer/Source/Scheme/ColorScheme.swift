import SwiftUI

enum ColorScheme {
    // Color Creation
    static func rgb(_ r: Double, _ g: Double, _ b: Double, alpha: Double = 1) -> Color {
        Color(red: r / 255, green: g / 255, blue: b / 255, opacity: alpha)
    }

    static func hex(_ hex: String) -> Color {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            return .clear
        }
        return Color(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }

    // Brand Colors
    static let primary = Color(light: hex("#3A608F"), dark: hex("#A4C9FE"))
    static let secondary = Color(light: hex("#545F71"), dark: hex("#BCC7DB"))
    static let secondaryContainer = Color(light: hex("#D8E3F8"), dark: hex("#3C4758"))

    // UI Colors
    static let inverseSurface = Color(light: hex("#2E3035"), dark: hex("#1D2024"))
    static let surfaceBright = Color(light: hex("#F7F7F7"), dark: hex("#37393E"))
    static let surfaceVariant = Color(light: hex("#DFE2EB"), dark: hex("#43474E"))
    static let onSurfaceVariant = Color(light: hex("#43474E"), dark: hex("#43474E"))
    static let background = Color(light: hex("#FFFFFF"), dark: hex("#191C20"))
    static let onPrimary = Color(light: hex("#FFFFFF"), dark: hex("#E1E2E9"))
    static let outline = Color(light: hex("#9FA3AB"), dark: hex("#8D9199"))
    static let error = Color(light: hex("#BA1A1A"), dark: hex("#FFB4AB"))
    static let errorContainer = Color(light: hex("#FFDAD6"), dark: hex("#93000A"))
}

extension Color {
    init(light: Color, dark: Color) {
        self.init(nsColor: NSColor(name: nil, dynamicProvider: { appearance in
            switch appearance.name {
            case .darkAqua, .vibrantDark:
                return NSColor(dark)
            default:
                return NSColor(light)
            }
        }))
    }
}
