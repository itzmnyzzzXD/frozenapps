import SwiftUI

/// Cached wallpaper plus one inexpensive tint pass replace the old full-screen blur stack.
struct FrozenWorkspaceBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            Image("SideStickBackground")
                .resizable()
                .scaledToFill()
                .frame(width: proxy.size.width, height: proxy.size.height)
                .clipped()
                .overlay {
                    LinearGradient(
                        stops: [
                            .init(color: Color.black.opacity(0.10), location: 0),
                            .init(color: Color.black.opacity(0.16), location: 0.46),
                            .init(color: Color.black.opacity(0.46), location: 1)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Material glass with a directional specular edge, inner hairline and soft shadow.
struct FrozenGlassSurfaceModifier: ViewModifier {
    let cornerRadius: CGFloat
    let tint: Color
    let elevated: Bool

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .background {
                shape.fill(.regularMaterial)
                    .overlay {
                        shape.fill(LinearGradient(
                            stops: [
                                .init(color: Color.white.opacity(0.17), location: 0),
                                .init(color: tint.opacity(0.075), location: 0.28),
                                .init(color: Color.white.opacity(0.025), location: 0.58),
                                .init(color: Color.black.opacity(0.16), location: 1)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    }
                    .overlay(alignment: .topLeading) {
                        shape.fill(LinearGradient(
                            colors: [Color.white.opacity(0.06), Color.white.opacity(0.018), .clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))
                    }
            }
            .overlay {
                shape.strokeBorder(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.42), location: 0),
                        .init(color: Color(red: 1.0, green: 0.91, blue: 0.82).opacity(0.20), location: 0.20),
                        .init(color: tint.opacity(0.17), location: 0.48),
                        .init(color: Color.white.opacity(0.055), location: 0.78),
                        .init(color: Color.white.opacity(0.22), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ), lineWidth: 1)
            }
            .overlay {
                shape.inset(by: 1).strokeBorder(Color.white.opacity(0.045), lineWidth: 1)
            }
            .shadow(
                color: Color.black.opacity(elevated ? 0.23 : 0.13),
                radius: elevated ? 24 : 12,
                x: 0,
                y: elevated ? 10 : 5
            )
    }
}

extension View {
    func frozenGlassSurface(cornerRadius: CGFloat = 20, tint: Color? = nil, elevated: Bool = false) -> some View {
        modifier(FrozenGlassSurfaceModifier(
            cornerRadius: cornerRadius,
            tint: tint ?? Theme.accent.opacity(0.18),
            elevated: elevated
        ))
    }
}

/// One material system for all workspace-owned cards.
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
            .frozenGlassSurface(cornerRadius: cornerRadius, tint: Theme.accent.opacity(0.16), elevated: elevated)
    }
}

/// A glass label for native menus with system-managed placement and dismissal.
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
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(1)
                }
            }
            Image(systemName: "chevron.down")
                .font(.system(size: 9, weight: .heavy))
                .foregroundStyle(.white.opacity(0.60))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(LinearGradient(
                colors: [
                    Color.white.opacity(0.36),
                    Color(red: 1.0, green: 0.91, blue: 0.82).opacity(0.15),
                    Theme.accent.opacity(0.13),
                    Color.white.opacity(0.075)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ), lineWidth: 1)
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
