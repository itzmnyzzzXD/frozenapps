import SwiftUI

enum FrozenMetalVariant: Float {
    case chrome = 0
    case gunmetal = 1
    case mercury = 2
    var staticColors: [Color] {
        switch self {
        case .chrome: [.black, .white.opacity(0.24), .black]
        case .gunmetal: [.black, .white.opacity(0.12), .black]
        case .mercury: [.black, .white.opacity(0.48), .black]
        }
    }
}

struct FrozenLiquidMetalModifier: ViewModifier {
    let variant: FrozenMetalVariant
    let cornerRadius: CGFloat
    let live: Bool
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
        content
            .overlay {
                shape.fill(LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.18), location: 0),
                        .init(color: .white.opacity(0.06), location: 0.22),
                        .init(color: .clear, location: 0.50),
                        .init(color: .white.opacity(0.035), location: 0.78),
                        .init(color: .white.opacity(0.12), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .blendMode(.screen)
                .opacity(reduceTransparency ? 0.24 : (live ? 0.48 : 0.32))
                .allowsHitTesting(false)
            }
            .overlay {
                shape.strokeBorder(
                    .white.opacity(accessibilityContrast == .increased ? 0.82 : 0.20),
                    lineWidth: accessibilityContrast == .increased ? 1.5 : 1
                )
            }
            .clipShape(shape)
    }
}

extension View {
    func frozenLiquidMetal(
        variant: FrozenMetalVariant = .gunmetal,
        cornerRadius: CGFloat = Theme.Radius.medium,
        live: Bool = true
    ) -> some View {
        modifier(FrozenLiquidMetalModifier(variant: variant, cornerRadius: cornerRadius, live: live))
    }
}

/// Extracted layers keep the button's SwiftUI body small enough for the type-checker.
private struct FrozenNeonLiquidButtonBackground: View {
    private let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)

    var body: some View {
        GeometryReader { proxy in
            let size = proxy.size
            ZStack {
                baseSurface
                spectrumGlow(size: size)
                accentGlow(size: size)
                topReflection(size: size)
            }
            .frame(width: size.width, height: size.height)
            .frozenLiquidMetal(variant: .mercury, cornerRadius: 23, live: true)
        }
    }

    private var baseSurface: some View {
        shape.fill(Color.black)
    }

    private func spectrumGlow(size: CGSize) -> some View {
        let radius = max(size.width, size.height) * 2.6
        return shape
            .fill(
                RadialGradient(
                    colors: [
                        .white,
                        Theme.accent2,
                        .white,
                        Theme.accent,
                        .white,
                        Theme.metalViolet,
                        .white
                    ],
                    center: UnitPoint(x: 0.65, y: 1.8),
                    startRadius: 2,
                    endRadius: radius
                )
            )
            .blendMode(.difference)
    }

    private func accentGlow(size: CGSize) -> some View {
        let radius = max(size.width, size.height) * 1.5
        return shape
            .fill(
                RadialGradient(
                    colors: [.white.opacity(0.42), .clear, .white.opacity(0.22)],
                    center: UnitPoint(x: 0.18, y: 0.08),
                    startRadius: 3,
                    endRadius: radius
                )
            )
            .blendMode(.colorDodge)
    }

    private func topReflection(size: CGSize) -> some View {
        Capsule()
            .fill(.white.opacity(0.24))
            .frame(width: size.width * 0.78, height: 22)
            .blur(radius: 7)
            .offset(y: -size.height * 0.30)
    }
}

/// A native SwiftUI reconstruction of the Uiverse neon-liquid button.
struct FrozenNeonLiquidButtonStyle: ButtonStyle {
    @Binding private var isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var accessibilityContrast
    @Environment(\.isEnabled) private var isEnabled

    init(isPressed: Binding<Bool> = .constant(false)) {
        self._isPressed = isPressed
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)

        configuration.label
            .font(Theme.TypeScale.control)
            .foregroundStyle(.white)
            .padding(.horizontal, Theme.Space.x6)
            .padding(.vertical, Theme.Space.x3)
            .background {
                Capsule()
                    .fill(Color.black.opacity(accessibilityContrast == .increased ? 0.92 : 0.84))
                    .overlay {
                        Capsule().strokeBorder(.white.opacity(0.28), lineWidth: 1)
                    }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.vertical, Theme.Space.x2)
            .background {
                FrozenNeonLiquidButtonBackground()
            }
            .overlay {
                shape.fill(Color.black.opacity(accessibilityContrast == .increased ? 0.42 : 0.30))
            }
            .overlay {
                shape.strokeBorder(.white.opacity(accessibilityContrast == .increased ? 0.95 : 0.68), lineWidth: 1.25)
            }
            .clipShape(shape)
            .shadow(color: .black.opacity(isEnabled ? 0.28 : 0.08), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .opacity(isEnabled ? 1 : 0.52)
            .animation(reduceMotion ? nil : Theme.Motion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
            .contentShape(shape)
            .hoverEffect(.lift)
    }
}

/// Compact liquid toggle for workspace preferences; the label remains native.
struct FrozenLiquidMetalToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var accessibilityContrast

    func makeBody(configuration: Configuration) -> some View {
        Button {
            withAnimation(reduceMotion ? nil : Theme.Motion.snappy) {
                configuration.isOn.toggle()
            }
        } label: {
            HStack(spacing: Theme.Space.x4) {
                configuration.label
                    .frame(maxWidth: .infinity, alignment: .leading)

                Capsule()
                    .fill(
                        configuration.isOn
                            ? LinearGradient(colors: [.white, .white.opacity(0.78)], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.black, .black], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white, .white.opacity(0.82), .white.opacity(0.57)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay { Circle().strokeBorder(.white.opacity(0.88), lineWidth: 0.8) }
                            .shadow(color: .black.opacity(0.32), radius: 3, x: 0, y: 2)
                            .padding(3)
                    }
                    .overlay {
                        Capsule().strokeBorder(
                            .white.opacity(accessibilityContrast == .increased ? 0.90 : 0.36),
                            lineWidth: accessibilityContrast == .increased ? 1.5 : 1
                        )
                    }
                    .frame(width: 54, height: 32)
                    .frame(minWidth: 48, minHeight: 44)
                    .contentShape(Rectangle())
                    .accessibilityHidden(true)
            }
            .frame(minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityValue(configuration.isOn ? "On" : "Off")
        .accessibilityHint("Double-tap to change this setting.")
        .sensoryFeedback(.selection, trigger: configuration.isOn)
    }
}

#Preview("Neon liquid button") {
    VStack {
        Button("Install") {}
            .buttonStyle(FrozenNeonLiquidButtonStyle())
        Button("Disabled") {}
            .buttonStyle(FrozenNeonLiquidButtonStyle())
            .disabled(true)
    }
    .padding(28)
    .background(Theme.matteSurface.ignoresSafeArea())
    .preferredColorScheme(.dark)
}

#Preview("Liquid metal toggle") {
    VStack(alignment: .leading, spacing: 18) {
        Toggle("Enable notifications", isOn: .constant(true))
        Toggle("Use local network", isOn: .constant(false))
    }
    .toggleStyle(FrozenLiquidMetalToggleStyle())
    .padding(24)
    .background(Theme.matteSurface.ignoresSafeArea())
    .preferredColorScheme(.dark)
}


#Preview("Liquid metal finishes") {
    VStack(spacing: 18) {
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.clear)
            .frame(height: 72)
            .frozenLiquidMetal(variant: .chrome, cornerRadius: 20, live: true)
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.clear)
            .frame(height: 72)
            .frozenLiquidMetal(variant: .gunmetal, cornerRadius: 20, live: false)
        RoundedRectangle(cornerRadius: 20, style: .continuous)
            .fill(Color.clear)
            .frame(height: 72)
            .frozenLiquidMetal(variant: .mercury, cornerRadius: 20, live: false)
    }
    .padding(24)
    .background(Theme.matteSurface.ignoresSafeArea())
    .preferredColorScheme(.dark)
}
