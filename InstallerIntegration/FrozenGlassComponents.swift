import SwiftUI

/// Solid OLED surfaces that let the shared LiquidChrome renderer remain visible in gutters.
struct FrozenWorkspaceBackdrop: View {
    var body: some View {
        Color.black.ignoresSafeArea().accessibilityHidden(true)
    }
}

/// A monochrome black surface with two restrained white hairlines.
struct FrozenGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background { shape.fill(Color.black) }
            .overlay {
                shape.strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
            .overlay {
                shape.inset(by: 1).strokeBorder(Color.white.opacity(0.06), lineWidth: 1)
            }
    }
}

extension View {
    func frozenGlassSurface(cornerRadius: CGFloat = 20, tint: Color? = nil, elevated: Bool = false) -> some View {
        modifier(FrozenGlassSurfaceModifier(
            cornerRadius: cornerRadius,
            tint: .white,
            elevated: false
        ))
    }
}

/// Shared black workspace panel; content and existing callbacks are unchanged.
struct FrozenWorkspacePanel<Content: View>: View {
    private let content: Content
    var cornerRadius: CGFloat
    var elevated: Bool

    init(cornerRadius: CGFloat = 21, elevated: Bool = false, @ViewBuilder content: () -> Content) {
        self.cornerRadius = cornerRadius
        self.elevated = elevated
        self.content = content()
    }

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frozenGlassSurface(cornerRadius: cornerRadius)
    }
}

/// Black native menu label with a white hairline.
struct FrozenGlassMenuLabel: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                }
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white.opacity(0.48))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.black, in: Capsule())
        .overlay {
            Capsule().strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
        }
        .contentShape(Capsule())
    }
}

struct FrozenGlassPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}
