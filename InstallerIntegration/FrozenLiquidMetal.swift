// From Uiverse.io by dexter-st - https://uiverse.io/dexter-st/breezy-zebra-94
// MIT License, Copyright (c) dexter-st
import SwiftUI
import CoreMotion
import Combine

enum FrozenMetalVariant: Float {
    case chrome = 0
    case gunmetal = 1
    case mercury = 2

    var staticColors: [Color] {
        switch self {
        case .chrome:
            [Color(red: 0.29, green: 0.35, blue: 0.45),
             Color(red: 0.68, green: 0.73, blue: 0.82),
             Color(red: 0.20, green: 0.25, blue: 0.34)]
        case .gunmetal:
            [Color(red: 0.035, green: 0.05, blue: 0.085),
             Color(red: 0.12, green: 0.16, blue: 0.23),
             Color(red: 0.045, green: 0.06, blue: 0.10)]
        case .mercury:
            [Color(red: 0.38, green: 0.44, blue: 0.55),
             Color(red: 0.86, green: 0.89, blue: 0.94),
             Color(red: 0.46, green: 0.51, blue: 0.62)]
        }
    }
}

@MainActor
private enum FrozenMetalSurfaceBudget {
    private static var activeIDs = Set<UUID>()
    private static let maximumLiveSurfaces = 3

    static func acquire(_ id: UUID) -> Bool {
        if activeIDs.contains(id) { return true }
        guard activeIDs.count < maximumLiveSurfaces else { return false }
        activeIDs.insert(id)
        return true
    }

    static func release(_ id: UUID) {
        activeIDs.remove(id)
    }
}

@MainActor
final class FrozenDeviceMotion: ObservableObject {
    static let shared = FrozenDeviceMotion()

    @Published private(set) var tilt: CGSize = .zero

    private let manager = CMMotionManager()
    private var activeClients = 0

    private init() {}

    func acquire() {
        activeClients += 1
        guard activeClients == 1, manager.isDeviceMotionAvailable else { return }

        manager.deviceMotionUpdateInterval = 1.0 / 20.0
        manager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
            guard let motion else { return }
            let nextTilt = CGSize(
                width: CGFloat(max(-0.38, min(0.38, motion.attitude.roll))),
                height: CGFloat(max(-0.38, min(0.38, motion.attitude.pitch)))
            )
            Task { @MainActor [weak self] in
                self?.tilt = nextTilt
            }
        }
    }

    func release() {
        activeClients = max(0, activeClients - 1)
        guard activeClients == 0 else { return }
        manager.stopDeviceMotionUpdates()
        tilt = .zero
    }
}

@MainActor
struct FrozenLiquidMetalModifier: ViewModifier {
    let variant: FrozenMetalVariant
    let cornerRadius: CGFloat
    let live: Bool

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.accessibilityContrast) private var accessibilityContrast

    @StateObject private var motion = FrozenDeviceMotion.shared
    @State private var isVisible = false
    @State private var lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
    @State private var ownsShaderSlot = false
    @State private var surfaceID = UUID()

    private var shouldAnimate: Bool {
        live && isVisible && ownsShaderSlot && scenePhase == .active && !lowPowerMode && !reduceMotion
    }

    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)

        content
            .background {
                shape.fill(
                    LinearGradient(
                        colors: variant.staticColors,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
            }
            .overlay {
                GeometryReader { proxy in
                    Group {
                        if shouldAnimate {
                            TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: false)) { timeline in
                                shaderReflection(
                                    size: proxy.size,
                                    time: timeline.date.timeIntervalSinceReferenceDate,
                                    tilt: motion.tilt
                                )
                            }
                        } else {
                            staticReflection
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .clipShape(shape)
                }
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            }
            .overlay {
                shape.strokeBorder(
                    LinearGradient(
                        colors: accessibilityContrast == .increased
                            ? [.white.opacity(0.94), Theme.accent2.opacity(0.85), .white.opacity(0.70)]
                            : [.white.opacity(0.58), Theme.accent2.opacity(0.38), .white.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: accessibilityContrast == .increased ? 1.6 : 1
                )
            }
            .clipShape(shape)
            .shadow(color: Theme.Elevation.floating, radius: 18, x: 0, y: 9)
            .onAppear {
                isVisible = true
                lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                updateShaderActivity()
            }
            .onDisappear {
                isVisible = false
                updateShaderActivity()
            }
            .onChange(of: scenePhase) { _, _ in updateShaderActivity() }
            .onChange(of: reduceMotion) { _, _ in updateShaderActivity() }
            .onChange(of: live) { _, _ in updateShaderActivity() }
            .onReceive(NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)) { _ in
                lowPowerMode = ProcessInfo.processInfo.isLowPowerModeEnabled
                updateShaderActivity()
            }
    }

    private func updateShaderActivity() {
        let shouldOwnSlot = live && isVisible && scenePhase == .active && !lowPowerMode && !reduceMotion

        if shouldOwnSlot && !ownsShaderSlot {
            ownsShaderSlot = FrozenMetalSurfaceBudget.acquire(surfaceID)
            if ownsShaderSlot {
                motion.acquire()
            }
        } else if !shouldOwnSlot && ownsShaderSlot {
            motion.release()
            FrozenMetalSurfaceBudget.release(surfaceID)
            ownsShaderSlot = false
        }
    }

    private func shaderReflection(size: CGSize, time: TimeInterval, tilt: CGSize) -> some View {
        let shader = ShaderLibrary.default.sideStickLiquidMetal(
            .float(Float(time)),
            .float2(SIMD2<Float>(Float(tilt.width), Float(tilt.height))),
            .float(variant.rawValue),
            .float2(SIMD2<Float>(Float(size.width), Float(size.height)))
        )

        return shapeFill
            .colorEffect(shader)
            .blendMode(.screen)
            .opacity(reduceTransparency ? 0.94 : 0.82)
    }

    private var staticReflection: some View {
        shapeFill
            .fill(
                LinearGradient(
                    stops: [
                        .init(color: .white.opacity(0.22), location: 0),
                        .init(color: Theme.accent2.opacity(0.10), location: 0.22),
                        .init(color: .clear, location: 0.48),
                        .init(color: .white.opacity(0.08), location: 0.73),
                        .init(color: .white.opacity(0.18), location: 1)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .blendMode(.screen)
            .opacity(accessibilityContrast == .increased ? 0.95 : 0.72)
    }

    private var shapeFill: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
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

/// A native SwiftUI reconstruction of the Uiverse neon-liquid button.
struct FrozenNeonLiquidButtonStyle: ButtonStyle {
    @Binding private var isPressed: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityContrast) private var accessibilityContrast
    @Environment(\.isEnabled) private var isEnabled

    init(isPressed: Binding<Bool> = .constant(false)) {
        self._isPressed = isPressed
    }

    func makeBody(configuration: Configuration) -> some View {
        let shape = RoundedRectangle(cornerRadius: 23, style: .continuous)

        configuration.label
            .font(Theme.TypeScale.control)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, minHeight: 44)
            .padding(.horizontal, Theme.Space.x6)
            .padding(.vertical, Theme.Space.x3)
            .background {
                GeometryReader { proxy in
                    ZStack {
                        shape.fill(Color(red: 0.55, green: 0.015, blue: 0.075))
                        shape.fill(
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
                                endRadius: max(proxy.size.width, proxy.size.height) * 2.6
                            )
                        )
                        .blendMode(.difference)
                        shape.fill(
                            RadialGradient(
                                colors: [Theme.accent2.opacity(0.72), .clear, Theme.metalViolet.opacity(0.56)],
                                center: UnitPoint(x: 0.18, y: 0.08),
                                startRadius: 3,
                                endRadius: max(proxy.size.width, proxy.size.height) * 1.5
                            )
                        )
                        .blendMode(.colorDodge)
                        Capsule()
                            .fill(.white.opacity(0.24))
                            .frame(width: proxy.size.width * 0.78, height: 22)
                            .blur(radius: 7)
                            .offset(y: -proxy.size.height * 0.30)
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height)
                    .frozenLiquidMetal(variant: .mercury, cornerRadius: 23, live: true)
                }
            }
            .overlay {
                shape.fill(Color.black.opacity(accessibilityContrast == .increased ? 0.42 : 0.30))
            }
            .overlay {
                shape.strokeBorder(.white.opacity(accessibilityContrast == .increased ? 0.95 : 0.68), lineWidth: 1.25)
            }
            .clipShape(shape)
            .shadow(color: Theme.accent.opacity(isEnabled ? 0.28 : 0.08), radius: 16, x: 0, y: 8)
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.95 : 1)
            .brightness(configuration.isPressed ? -0.035 : 0)
            .opacity(isEnabled ? 1 : 0.52)
            .animation(reduceMotion ? nil : Theme.Motion.snappy, value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, pressed in
                isPressed = pressed
            }
            .sensoryFeedback(.selection, trigger: configuration.isPressed)
            .contentShape(shape)
            .accessibilityAddTraits(.isButton)
    }
}

/// Compact liquid toggle for workspace preferences; the label remains native.
struct FrozenLiquidMetalToggleStyle: ToggleStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityContrast) private var accessibilityContrast

    func makeBody(configuration: Configuration) -> some View {
        HStack(spacing: Theme.Space.x4) {
            configuration.label
                .frame(maxWidth: .infinity, alignment: .leading)

            Button {
                withAnimation(reduceMotion ? nil : Theme.Motion.snappy) {
                    configuration.isOn.toggle()
                }
            } label: {
                Capsule()
                    .fill(
                        configuration.isOn
                            ? LinearGradient(colors: [Theme.accent, Theme.metalViolet], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [Theme.matteRaised, Theme.matteSurface], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .overlay(alignment: configuration.isOn ? .trailing : .leading) {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [.white, Theme.metalSilver, Color(red: 0.57, green: 0.62, blue: 0.72)],
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
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Toggle")
            .accessibilityValue(configuration.isOn ? "On" : "Off")
            .accessibilityHint("Double-tap to change this setting.")
            .sensoryFeedback(.selection, trigger: configuration.isOn)
        }
        .contentShape(Rectangle())
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
