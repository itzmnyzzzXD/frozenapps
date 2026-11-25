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
    }

    enum Radius {
        static let small: CGFloat = 12
        static let medium: CGFloat = 20
        static let large: CGFloat = 28
    }

    enum TypeScale {
        static let compact = Font.caption2.weight(.medium)
        static let detail = Font.caption.weight(.medium)
        static let control = Font.headline.weight(.semibold)
        static let title = Font.title3.weight(.bold)
    }

    enum Elevation {
        static let card = Color.black.opacity(0.22)
        static let floating = Color.black.opacity(0.36)
        static let focus = Color.white.opacity(0.72)
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.22, dampingFraction: 0.84)
        static let smooth = Animation.spring(response: 0.34, dampingFraction: 0.90)
        static let floaty = Animation.spring(response: 0.52, dampingFraction: 0.86)
    }
}
