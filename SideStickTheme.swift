import SwiftUI

/// Shared SideStick tokens. The upstream Theme remains the source of the
/// existing brand colors; these additions centralize the workspace system.
extension Theme {
    static let matteSurface = Color(red: 0.025, green: 0.035, blue: 0.065)
    static let matteRaised = Color(red: 0.055, green: 0.070, blue: 0.105)
    static let metalViolet = Color(red: 0.43, green: 0.33, blue: 0.82)
    static let metalSilver = Color(red: 0.78, green: 0.83, blue: 0.92)
    static let metalInk = Color(red: 0.055, green: 0.070, blue: 0.105)

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

    /// Dynamic text styles are preferred over fixed point sizes.
    enum TypeScale {
        static let compact = Font.caption2.weight(.medium)
        static let detail = Font.caption.weight(.medium)
        static let control = Font.headline.weight(.semibold)
        static let title = Font.title3.weight(.bold)
    }

    enum Elevation {
        static let card = Color.black.opacity(0.22)
        static let floating = Color.black.opacity(0.36)
        static let focus = accent.opacity(0.34)
    }

    enum Motion {
        static let snappy = Animation.spring(response: 0.22, dampingFraction: 0.84)
        static let smooth = Animation.spring(response: 0.34, dampingFraction: 0.90)
        static let floaty = Animation.spring(response: 0.52, dampingFraction: 0.86)
    }
}
