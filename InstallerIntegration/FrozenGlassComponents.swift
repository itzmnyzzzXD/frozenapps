import SwiftUI

/// Shared visual primitives for FrozenApps. Content cards use a standard system
/// material; the brighter glass treatment is reserved for controls.
struct FrozenGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape
                    .fill(.regularMaterial)
                    .overlay {
                        shape.fill(
                            LinearGradient(
                                colors: [
                                    .white.opacity(0.035),
                                    tint.opacity(0.075),
                                    Color.black.opacity(0.20)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: [
                            .white.opacity(0.24),
                            tint.opacity(0.25),
                            .white.opacity(0.04)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
            }
            .shadow(
                color: Color.black.opacity(elevated ? 0.22 : 0.12),
                radius: elevated ? 17 : 9,
                x: 0,
                y: elevated ? 7 : 4
            )
    }
}

extension View {
    func frozenGlassSurface(
        cornerRadius: CGFloat = 20,
        tint: Color? = nil,
        elevated: Bool = false
    ) -> some View {
        modifier(
            FrozenGlassSurfaceModifier(
                cornerRadius: cornerRadius,
                tint: tint ?? Theme.accent,
                elevated: elevated
            )
        )
    }
}

/// A custom label for native SwiftUI menus. The system still provides adaptive
/// placement and dismissal, including compact-width devices.
struct FrozenGlassMenuLabel: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
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
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(
                LinearGradient(
                    colors: [.white.opacity(0.24), Theme.accent.opacity(0.22), .white.opacity(0.05)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: 1
            )
        }
        .contentShape(Capsule())
    }
}

/// Lightweight touch feedback that respects the user's Reduce Motion preference.
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
