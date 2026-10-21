import SwiftUI

/// Calm, refraction-led workspace backdrop; the account/login artwork is unchanged.
struct FrozenWorkspaceBackdrop: View {
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.13, green: 0.13, blue: 0.145),
                        Color(red: 0.065, green: 0.068, blue: 0.078),
                        Color(red: 0.018, green: 0.020, blue: 0.026)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                )
                RadialGradient(
                    colors: [Color(red: 1.0, green: 0.91, blue: 0.80).opacity(0.15), .clear],
                    center: .topLeading, startRadius: 8, endRadius: max(440, proxy.size.width * 0.84)
                )
                RadialGradient(
                    colors: [Theme.accent2.opacity(0.085), .clear],
                    center: UnitPoint(x: 0.96, y: 0.43), startRadius: 0,
                    endRadius: max(360, proxy.size.width * 0.72)
                )
                Rectangle()
                    .fill(LinearGradient(
                        colors: [.clear, Color.white.opacity(0.022), Color.white.opacity(0.065), Color.white.opacity(0.018), .clear],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: proxy.size.width * 1.8)
                    .rotationEffect(.degrees(-27))
                    .offset(x: proxy.size.width * 0.13, y: -proxy.size.height * 0.14)
                    .blur(radius: 52)
                LinearGradient(colors: [.clear, Color.black.opacity(0.16)], startPoint: .top, endPoint: .bottom)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .clipped()
        }
        .ignoresSafeArea()
        .accessibilityHidden(true)
    }
}

/// Reusable frosted glass: translucent surfaces, restrained tint and a fine specular edge.
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
                                .init(color: Color.white.opacity(0.145), location: 0),
                                .init(color: tint.opacity(0.075), location: 0.29),
                                .init(color: Color(red: 0.78, green: 0.82, blue: 0.91).opacity(0.035), location: 0.63),
                                .init(color: Color.black.opacity(0.16), location: 1)
                            ],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    }
                    .overlay(alignment: .topLeading) {
                        shape.fill(LinearGradient(
                            colors: [Color.white.opacity(0.075), Color.white.opacity(0.018), .clear],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ))
                    }
            }
            .overlay {
                shape.strokeBorder(LinearGradient(
                    stops: [
                        .init(color: Color.white.opacity(0.38), location: 0),
                        .init(color: Color(red: 1.0, green: 0.91, blue: 0.82).opacity(0.17), location: 0.17),
                        .init(color: tint.opacity(0.22), location: 0.43),
                        .init(color: Color.white.opacity(0.055), location: 0.76),
                        .init(color: Color.white.opacity(0.19), location: 1)
                    ],
                    startPoint: .topLeading, endPoint: .bottomTrailing
                ), lineWidth: 1)
            }
            .overlay {
                shape.inset(by: 1).strokeBorder(Color.white.opacity(0.045), lineWidth: 1)
            }
            .shadow(color: Color.black.opacity(elevated ? 0.24 : 0.15),
                    radius: elevated ? 22 : 12, x: 0, y: elevated ? 10 : 5)
    }
}

extension View {
    func frozenGlassSurface(cornerRadius: CGFloat = 20, tint: Color? = nil, elevated: Bool = false) -> some View {
        modifier(FrozenGlassSurfaceModifier(cornerRadius: cornerRadius, tint: tint ?? Theme.accent, elevated: elevated))
    }
}

/// Consistent workspace cards. Login cards intentionally keep their existing component.
struct FrozenWorkspacePanel<Content: View>: View {
    private let content: Content
    init(@ViewBuilder content: () -> Content) { self.content = content() }
    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .frozenGlassSurface(cornerRadius: 21, tint: Theme.accent.opacity(0.13))
    }
}

struct FrozenGlassMenuLabel: View {
    let title: String
    var icon: String? = nil
    var subtitle: String? = nil

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon).font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accent2)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                if let subtitle {
                    Text(subtitle).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.54)).lineLimit(1)
                }
            }
            Image(systemName: "chevron.down").font(.system(size: 9, weight: .heavy)).foregroundStyle(.white.opacity(0.60))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.regularMaterial, in: Capsule())
        .overlay {
            Capsule().strokeBorder(LinearGradient(
                colors: [Color.white.opacity(0.36), Color(red: 1.0, green: 0.91, blue: 0.82).opacity(0.15),
                         Theme.accent.opacity(0.13), Color.white.opacity(0.075)],
                startPoint: .topLeading, endPoint: .bottomTrailing
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
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78), value: configuration.isPressed)
    }
}
