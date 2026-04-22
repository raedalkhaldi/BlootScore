import SwiftUI
import UIKit

/// Design tokens for BlootScore — mirrors `DESIGN.md` at the project root.
/// Views should never reference raw hex or point values directly — always go through `Theme`.
/// When you need a value that isn't here, add it to `DESIGN.md` first, then extend this file.
enum Theme {

    // MARK: - Color
    enum Color {
        static let primary   = SwiftUI.Color(hex: 0x1A1A1D)
        static let ink       = SwiftUI.Color(hex: 0x1A1A1D)
        static let muted     = SwiftUI.Color(hex: 0x6B7280)
        static let surface   = SwiftUI.Color(hex: 0xFFFFFF)
        static let canvas    = SwiftUI.Color(hex: 0xFAF8F5)
        static let border    = SwiftUI.Color(hex: 0xE7E3DC)
        static let team1     = SwiftUI.Color(hex: 0x1E3A8A)
        static let team2     = SwiftUI.Color(hex: 0xB1222B)
        static let accent    = SwiftUI.Color(hex: 0x96510C)
        static let onAccent  = SwiftUI.Color(hex: 0xFFFFFF)
        static let success   = SwiftUI.Color(hex: 0x046B48)
        static let warning   = SwiftUI.Color(hex: 0xB85A10)
        static let dobble    = SwiftUI.Color(hex: 0x5A3C91)
        static let micActive = SwiftUI.Color(hex: 0xA62421)
    }

    // MARK: - Font
    enum Font {
        static let displayXL = SwiftUI.Font.system(size: 64, weight: .heavy,    design: .rounded)
        static let displayLG = SwiftUI.Font.system(size: 38, weight: .bold,     design: .rounded)
        static let title     = SwiftUI.Font.system(size: 17, weight: .semibold)
        static let body      = SwiftUI.Font.system(size: 15, weight: .regular)
        static let label     = SwiftUI.Font.system(size: 13, weight: .semibold)
        static let caption   = SwiftUI.Font.system(size: 12, weight: .regular)
        static let micro     = SwiftUI.Font.system(size: 11, weight: .medium)
    }

    // MARK: - Spacing  (8pt grid + 4 and 12 for fine-tuning)
    enum Space {
        static let xxs: CGFloat = 2
        static let xs:  CGFloat = 4
        static let sm:  CGFloat = 8
        static let md:  CGFloat = 12
        static let lg:  CGFloat = 16
        static let xl:  CGFloat = 24
        static let xxl: CGFloat = 32
    }

    // MARK: - Radius
    enum Radius {
        static let xs:   CGFloat = 6
        static let sm:   CGFloat = 10
        static let md:   CGFloat = 14
        static let lg:   CGFloat = 18
        static let xl:   CGFloat = 24
        static let pill: CGFloat = 999
    }

    // MARK: - Haptics  (physical feedback is part of the feel; use sparingly)
    enum Haptic {
        static func light()   { UIImpactFeedbackGenerator(style: .light).impactOccurred() }
        static func medium()  { UIImpactFeedbackGenerator(style: .medium).impactOccurred() }
        static func success() { UINotificationFeedbackGenerator().notificationOccurred(.success) }
        static func warning() { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
    }
}

// MARK: - Color hex initializer
extension Color {
    /// Initialize from a 24-bit hex literal, e.g. `Color(hex: 0x1E3A8A)`.
    init(hex: UInt32, alpha: Double = 1) {
        let r = Double((hex >> 16) & 0xFF) / 255.0
        let g = Double((hex >>  8) & 0xFF) / 255.0
        let b = Double( hex        & 0xFF) / 255.0
        self.init(.sRGB, red: r, green: g, blue: b, opacity: alpha)
    }
}

// MARK: - Convenience view modifiers
extension View {
    /// Soft elevation reserved for primary surfaces (score cards, winner sheet).
    func themeCardShadow() -> some View {
        shadow(color: Color.black.opacity(0.06), radius: 12, x: 0, y: 4)
    }

    /// 1-pt hairline border using the token color.
    func themeHairline(_ color: Color = Theme.Color.border, cornerRadius: CGFloat) -> some View {
        overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(color, lineWidth: 1)
        )
    }
}
