import SwiftUI

// The app's eight accents, copied verbatim from ACCENTS in the prototype.
// The page pushes the user's pick to Swift, which stores the hex in the App Group —
// so the widget uses the same value the app is using rather than a second copy that
// can drift out of sync.
enum FlashAccent: String, CaseIterable {
    case green, teal, sky, indigo, violet, rose, ember, gold

    var hex: String {
        switch self {
        case .green:  return "#3AB54A"
        case .teal:   return "#0E9E93"
        case .sky:    return "#2E7CF6"
        case .indigo: return "#5B54E8"
        case .violet: return "#8B45D6"
        case .rose:   return "#D4409A"
        case .ember:  return "#E0602E"
        case .gold:   return "#D19A0E"
        }
    }

    /// The lighter tint used for the change pill and gradient tops.
    var lightHex: String {
        switch self {
        case .green:  return "#5CD46C"
        case .teal:   return "#3CC7BB"
        case .sky:    return "#5C9BFF"
        case .indigo: return "#8079FF"
        case .violet: return "#AC72EC"
        case .rose:   return "#EE6FBB"
        case .ember:  return "#F58A5C"
        case .gold:   return "#EDBB3C"
        }
    }

    var color: Color { Color(hex: hex) }
    var light: Color { Color(hex: lightHex) }

    /// CTA_INK is always white in the app, on every accent.
    var ink: Color { .white }
}

enum FlashTheme {
    static let bg      = Color(hex: "#050505")
    static let surface = Color(hex: "#141416")
    static let ink     = Color.white
    static let inkDim  = Color.white.opacity(0.45)
    static let down    = Color(hex: "#E5484D")   // a falling price is always red
    static let hairline = Color.white.opacity(0.10)

    /// Sora and Figtree are the app's faces. Add the .ttf files to the widget target
    /// (and list them under UIAppFonts in the EXTENSION's Info.plist) and these resolve.
    /// Without them SwiftUI falls back to the system face at the same weight.
    static func display(_ size: CGFloat) -> Font {
        Font.custom("Sora-ExtraBold", size: size, relativeTo: .headline)
    }
    static func body(_ size: CGFloat, weight: Font.Weight = .semibold) -> Font {
        Font.custom("Figtree-SemiBold", size: size, relativeTo: .body).weight(weight)
    }
}

extension Color {
    /// Numeric form, e.g. Color(hex: 0x050505).
    init(hex: UInt32) {
        self.init(
            .sRGB,
            red:   Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue:  Double(hex & 0xFF) / 255,
            opacity: 1
        )
    }

    /// Accepts "#RRGGBB" or "RRGGBB".
    init(hex: String) {
        let cleaned = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        let v = UInt32(cleaned, radix: 16) ?? 0
        self.init(
            .sRGB,
            red:   Double((v >> 16) & 0xFF) / 255,
            green: Double((v >> 8) & 0xFF) / 255,
            blue:  Double(v & 0xFF) / 255,
            opacity: 1
        )
    }
}
