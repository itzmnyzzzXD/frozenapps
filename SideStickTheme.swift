import SwiftUI

/// Shared OLED monochrome tokens for the SideStick workspace.
extension Theme {
    static let matteSurface = Color.black
    static let matteRaised = Color.black
    static let metalViolet = Color.white
    static let metalSilver = Color.white
    static let metalInk = Color.black

    enum Space {
        static let x1: CGFloat = 4
        static let x2: CGFloat = 8
        static let x3: CGFloat = 12
        static let x4: CGFloat = 16
        static let x6: CGFloat = 24
        static let x8: CGFloat = 32
        static let x12: CGFloat = 48
    }

    enum Radius {
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
    }

    enum Opacity {
        static let full: Double = 1
        static let strong: Double = 0.72
        static let medium: Double = 0.48
        static let subdued: Double = 0.24
        static let faint: Double = 0.12
        static let hairline: Double = 0.06
        static let barely: Double = 0.03
    }

    enum TypeScale {
        static let compact = Font.caption2.weight(.medium)
        static let detail = Font.caption.weight(.medium)
        static let control = Font.headline.weight(.semibold)
        static let title = Font.title3.weight(.bold)
    }

    enum Elevation {
        static let card = Color.black.opacity(0.24)
        static let floating = Color.black.opacity(0.48)
        static let focus = Color.white.opacity(0.72)
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.22, dampingFraction: 0.84)
        static let smooth = Animation.spring(response: 0.34, dampingFraction: 0.90)
        static let floaty = Animation.spring(response: 0.52, dampingFraction: 0.86)
    }
}
