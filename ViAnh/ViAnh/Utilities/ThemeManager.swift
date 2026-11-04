import SwiftUI

// MARK: - App Theme Palette

enum AppThemePalette: String, CaseIterable, Identifiable {
    case warmCream = "warmCream"
    case matchaGreen = "matchaGreen"
    case sakuraPink = "sakuraPink"
    case midnightOLED = "midnightOLED"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .warmCream: return "Warm Cream (Ấm áp)"
        case .matchaGreen: return "Matcha Green (Xanh mát)"
        case .sakuraPink: return "Sakura Pink (Hồng phấn)"
        case .midnightOLED: return "Midnight OLED (Đen tuyền)"
        }
    }
}

// MARK: - App Theme Mode

enum AppThemeMode: String, CaseIterable, Identifiable {
    case system = "system"
    case light = "light"
    case dark = "dark"

    var id: String { rawValue }

    @MainActor
    var title: String {
        let isVN = LocalizationManager.shared.currentLanguage == .vietnamese
        switch self {
        case .system: return isVN ? "Theo hệ thống" : "System"
        case .light: return isVN ? "Luôn sáng" : "Light"
        case .dark: return isVN ? "Luôn tối" : "Dark"
        }
    }
}

// MARK: - ThemeManager

/// Quản lý màu sắc, 4 theme palette, chế độ Sáng/Tối, kiểu dáng, bo góc theo UI/UX Pro Max
@MainActor
@Observable
final class ThemeManager {

    static let shared = ThemeManager()

    var palette: AppThemePalette = .warmCream {
        didSet {
            UserDefaults.standard.set(palette.rawValue, forKey: "app_theme_palette")
        }
    }

    var mode: AppThemeMode = .system {
        didSet {
            UserDefaults.standard.set(mode.rawValue, forKey: "app_theme_mode")
        }
    }

    init() {
        if let savedPalette = UserDefaults.standard.string(forKey: "app_theme_palette"),
           let loadedPalette = AppThemePalette(rawValue: savedPalette) {
            self.palette = loadedPalette
        } else {
            self.palette = .warmCream
        }

        if let saved = UserDefaults.standard.string(forKey: "app_theme_mode") {
            if saved == "autoTime" {
                self.mode = .system
            } else if let loaded = AppThemeMode(rawValue: saved) {
                self.mode = loaded
            } else {
                self.mode = .system
            }
        } else {
            self.mode = .system
        }
    }

    var preferredColorScheme: ColorScheme? {
        if palette == .midnightOLED {
            return .dark
        }
        switch mode {
        case .system:
            return nil
        case .light:
            return .light
        case .dark:
            return .dark
        }
    }

    var isDarkModeEffective: Bool {
        if palette == .midnightOLED { return true }
        switch mode {
        case .system:
            return UITraitCollection.current.userInterfaceStyle == .dark
        case .light:
            return false
        case .dark:
            return true
        }
    }

    // MARK: - Color Tokens (Phân tầng mượt mà, dịu mắt chuẩn WCAG AAA)

    /// Nền chính: Đen xám dịu #161616 ở dark mode hoặc #000000 ở OLED; #FAF6F0 ở Warm Cream
    var background: Color {
        if palette == .midnightOLED {
            return Color.black
        }
        if isDarkModeEffective {
            return Color(hex: "#161616") ?? Color.black
        }
        switch palette {
        case .warmCream:
            return Color(hex: "#FAF6F0") ?? Color(white: 0.98)
        case .matchaGreen:
            return Color(hex: "#F2F7F2") ?? Color(white: 0.98)
        case .sakuraPink:
            return Color(hex: "#FFF5F7") ?? Color(white: 0.98)
        case .midnightOLED:
            return Color.black
        }
    }

    /// Nền thẻ (Surface): Có độ sáng nhỉnh hơn nền #222222 ở dark mode; #FFFFFF ở light mode
    var surface: Color {
        if palette == .midnightOLED {
            return Color(hex: "#141414") ?? Color(white: 0.1)
        }
        if isDarkModeEffective {
            return Color(hex: "#222222") ?? Color(white: 0.15)
        }
        return Color.white
    }

    /// Nền thẻ nổi cao hơn (Surface Elevated)
    var surfaceElevated: Color {
        if isDarkModeEffective {
            return Color(hex: "#2C2C2E") ?? Color(white: 0.2)
        }
        return Color(hex: "#F5F0E8") ?? Color(white: 0.96)
    }

    /// Màu hành động chính
    var primaryAction: Color {
        if isDarkModeEffective {
            switch palette {
            case .warmCream:
                return Color(hex: "#34D399") ?? Color.green
            case .matchaGreen:
                return Color(hex: "#4ADE80") ?? Color.green
            case .sakuraPink:
                return Color(hex: "#F472B6") ?? Color.pink
            case .midnightOLED:
                return Color(hex: "#38BDF8") ?? Color.blue
            }
        } else {
            switch palette {
            case .warmCream:
                return Color(hex: "#1B4D3E") ?? Color.green
            case .matchaGreen:
                return Color(hex: "#205E3B") ?? Color.green
            case .sakuraPink:
                return Color(hex: "#B83B5E") ?? Color.pink
            case .midnightOLED:
                return Color(hex: "#0284C7") ?? Color.blue
            }
        }
    }

    /// Màu chi tiêu: Hồng đỏ dịu mắt không chói
    var expenseColor: Color {
        isDarkModeEffective ? (Color(hex: "#FB7185") ?? Color.red) : (Color(hex: "#E84A5F") ?? Color.red)
    }

    /// Màu thu nhập: Xanh lá dịu mát
    var incomeColor: Color {
        isDarkModeEffective ? (Color(hex: "#34D399") ?? Color.green) : (Color(hex: "#2E7D32") ?? Color.green)
    }

    /// Màu cảnh báo ngân sách
    var warningColor: Color {
        isDarkModeEffective ? (Color(hex: "#FBBF24") ?? Color.orange) : (Color(hex: "#E65100") ?? Color.orange)
    }

    /// Màu chữ chính: Trắng ngà #F5F5F7 ở dark mode, #1C1C1E ở light mode
    var textPrimary: Color {
        isDarkModeEffective ? (Color(hex: "#F5F5F7") ?? Color.white) : (Color(hex: "#1A1A1A") ?? Color.black)
    }

    /// Màu chữ phụ: #A1A1A6 ở dark mode, #757575 ở light mode
    var textSecondary: Color {
        isDarkModeEffective ? (Color(hex: "#A1A1A6") ?? Color.gray) : (Color(hex: "#757575") ?? Color.gray)
    }

    /// Đường viền phân cách mỏng
    var separator: Color {
        isDarkModeEffective ? Color(white: 0.22) : (Color(hex: "#EAE5DC") ?? Color(white: 0.9))
    }

    // MARK: - Geometry & Spring Tokens

    let cardCornerRadius: CGFloat = 22
    let chipCornerRadius: CGFloat = 14
    let dockCornerRadius: CGFloat = 36

    /// Animation spring tiêu chuẩn theo chỉ dẫn SnapSpend
    var defaultSpring: Animation {
        .spring(response: 0.35, dampingFraction: 0.8)
    }
}

// MARK: - Color Hex Initializer

extension Color {
    init?(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")

        var rgb: UInt64 = 0

        guard Scanner(string: hexSanitized).scanHexInt64(&rgb) else {
            return nil
        }

        let length = hexSanitized.count
        guard length == 6 || length == 8 else {
            return nil
        }

        let r, g, b, a: Double
        if length == 6 {
            r = Double((rgb & 0xFF0000) >> 16) / 255.0
            g = Double((rgb & 0x00FF00) >> 8) / 255.0
            b = Double(rgb & 0x0000FF) / 255.0
            a = 1.0
        } else {
            r = Double((rgb & 0xFF000000) >> 24) / 255.0
            g = Double((rgb & 0x00FF0000) >> 16) / 255.0
            b = Double((rgb & 0x0000FF00) >> 8) / 255.0
            a = Double(rgb & 0x000000FF) / 255.0
        }

        self.init(red: r, green: g, blue: b, opacity: a)
    }
}
