import SwiftUI
import UIKit

private struct FrozenInstallProgressTrace: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: rect.minX, y: rect.height * 0.72))
        path.addCurve(to: CGPoint(x: rect.width * 0.42, y: rect.height * 0.24),
            control1: CGPoint(x: rect.width * 0.18, y: rect.height * 0.12),
            control2: CGPoint(x: rect.width * 0.31, y: rect.height * 0.95))
        path.addCurve(to: CGPoint(x: rect.width * 0.74, y: rect.height * 0.40),
            control1: CGPoint(x: rect.width * 0.52, y: rect.height * 0.02),
            control2: CGPoint(x: rect.width * 0.62, y: rect.height * 0.85))
        path.addCurve(to: CGPoint(x: rect.maxX, y: rect.height * 0.55),
            control1: CGPoint(x: rect.width * 0.85, y: rect.height * 0.02),
            control2: CGPoint(x: rect.width * 0.91, y: rect.height * 0.98))
        return path
    }
}

/// A real install-only stats card: source icon/name, Engine percentage and current step.
struct FrozenInstallProgressPopup: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var glowIsMoving = false

    private var appName: String {
        if let name = engine.signedDisplayName, !name.isEmpty { return name }
        if engine.installSource == .custom, let filename = engine.customIPAName {
            return (filename as NSString).deletingPathExtension
        }
        return engine.installedSourceName
    }

    private var appIcon: UIImage? {
        guard let path = engine.signedAppPath, let bundle = Bundle(path: path) else { return nil }
        let info = bundle.infoDictionary ?? [:]
        var names: [String] = []
        if let name = info["CFBundleIconName"] as? String { names.append(name) }
        for key in ["CFBundleIcons~ipad", "CFBundleIcons"] {
            if let icons = info[key] as? [String: Any],
               let primary = icons["CFBundlePrimaryIcon"] as? [String: Any],
               let files = primary["CFBundleIconFiles"] as? [String] {
                names.append(contentsOf: files.reversed())
            }
        }
        if let files = info["CFBundleIconFiles"] as? [String] {
            names.append(contentsOf: files.reversed())
        }
        for name in names where !name.isEmpty {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) { return image }
            for ext in ["png", "jpg", "jpeg"] {
                let url = bundle.bundleURL.appendingPathComponent(name).appendingPathExtension(ext)
                if let image = UIImage(contentsOfFile: url.path) { return image }
            }
        }
        return nil
    }

    private var activeStep: Step? {
        Step.allCases.first { step in
            switch engine.stepStates[step] ?? .pending {
            case .active, .waiting: true
            case .pending, .done, .failed: false
            }
        }
    }
    private var failedStep: Step? {
        Step.allCases.first { (engine.stepStates[$0] ?? .pending) == .failed }
    }

    private var stepLabel: String {
        if engine.isCancelling { return "Stopping installation" }
        if let step = activeStep {
            let title = step.title(for: engine.installSource)
            return engine.stepStates[step] == .waiting ? "Waiting · \(title)" : title
        }
        if let step = failedStep { return "Failed · \(step.title(for: engine.installSource))" }
        return engine.isRunning ? "Finalizing installation" : "Preparing installation"
    }
    private var progress: Double { min(max(engine.overallProgress, 0), 1) }
    private var percentage: Int { Int((progress * 100).rounded()) }

    var body: some View {
        HStack(spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 15, style: .continuous).fill(Color.white.opacity(0.06))
                if let appIcon {
                    Image(uiImage: appIcon).resizable().scaledToFill()
                } else {
                    Image(systemName: "app.fill")
                        .font(.system(size: 25, weight: .medium)).foregroundStyle(.white.opacity(0.82))
                }
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.17), lineWidth: 1)
            }
            .frame(width: 54, height: 54)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 7) {
                HStack(spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("INSTALLATION STATS")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .tracking(1.45).foregroundStyle(.white.opacity(0.56))
                        Text(appName)
                            .font(.system(size: 14, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white).lineLimit(1).truncationMode(.middle)
                    }
                    Spacer(minLength: 4)
                    Text("\(percentage)%")
                        .font(.system(size: 23, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white)
                        .contentTransition(.numericText(value: Double(percentage)))
                }

                HStack(spacing: 6) {
                    Circle().fill(.white).frame(width: 5, height: 5)
                    Text(stepLabel).font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62)).lineLimit(1).truncationMode(.tail)
                    Spacer(minLength: 4)
                    Text("LIVE").font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(1.1).foregroundStyle(.white.opacity(0.82))
                }

                GeometryReader { proxy in
                    let width = proxy.size.width * progress
                    ZStack(alignment: .leading) {
                        Capsule().fill(Color.white.opacity(0.10))
                        Capsule().fill(Color.white.opacity(0.88))
                            .frame(width: max(progress > 0 ? 3 : 0, width))
                            .animation(.smooth(duration: 0.38), value: progress)
                        Circle().fill(.white).frame(width: 12, height: 12)
                            .blur(radius: 5).offset(x: max(0, width - 6))
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 5)

                GeometryReader { proxy in
                    ZStack(alignment: .leading) {
                        FrozenInstallProgressTrace()
                            .stroke(Color.white.opacity(0.28),
                                style: StrokeStyle(lineWidth: 1, lineCap: .round))
                        Circle().fill(.white).frame(width: 4, height: 4).blur(radius: 2)
                            .offset(x: glowIsMoving ? max(0, proxy.size.width - 5) : 0,
                                    y: glowIsMoving ? -1 : 1)
                    }
                }
                .frame(height: 9).clipped()
                FrozenInstallProgressStack()
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
        .frame(maxWidth: 560)
        .background(RoundedRectangle(cornerRadius: 21, style: .continuous).fill(Color.black.opacity(0.93)))
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.23), .white.opacity(0.07)],
                        startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.46), radius: 24, x: 0, y: 13)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Installing \(appName), \(percentage) percent. \(stepLabel).")
        .accessibilityAddTraits(.updatesFrequently)
        .allowsHitTesting(false)
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.linear(duration: 2.6).repeatForever(autoreverses: false)) {
                glowIsMoving = true
            }
        }
    }
}
