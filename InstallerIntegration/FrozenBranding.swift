import SwiftUI

/// Lightweight white particles drawn into the existing animated background.
struct FrozenParticleOverlay: View {
    let time: TimeInterval

    var body: some View {
        Canvas { context, size in
            guard size.width > 1, size.height > 1 else { return }
            let clock = time.truncatingRemainder(dividingBy: 10_000)
            for index in 0..<34 {
                let seed = Double(index)
                let xUnit = sin(seed * 12.9898) * 0.5 + 0.5
                let yUnit = cos(seed * 78.233) * 0.5 + 0.5
                let speed = 2.0 + Double(index % 5) * 0.55
                let baseY = yUnit * size.height
                var y = (baseY - (clock * speed).truncatingRemainder(dividingBy: size.height))
                    .truncatingRemainder(dividingBy: size.height)
                if y < 0 { y += size.height }
                let diameter = 1.0 + Double(index % 3) * 0.65
                let rect = CGRect(x: xUnit * size.width, y: y, width: diameter, height: diameter)
                let opacity = 0.065 + Double(index % 5) * 0.025
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(opacity)))
            }
        }
        .accessibilityHidden(true)
    }
}


/// A short launch overlay shown before the existing TOS, account and workspace
/// screens. The staggered word reveal is native SwiftUI and respects Reduce Motion.
struct FrozenLaunchWelcome: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private let words = ["Welcome", "to", "FrozenApps"]

    var body: some View {
        ZStack {
            FrozenWorkspaceBackdrop()

            VStack(spacing: 24) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color.black)
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)

                    Image("SideStickMark")
                        .resizable()
                        .scaledToFit()
                        .padding(15)
                }
                .frame(width: 82, height: 82)
                .shadow(color: .white.opacity(0.12), radius: 22, x: 0, y: 8)

                HStack(spacing: 7) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        FrozenRevealWord(
                            value: word,
                            delay: Double(index) * 0.18,
                            reduceMotion: reduceMotion
                        )
                    }
                }
                .font(.system(size: 34, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.72)
                .lineLimit(1)
                .padding(.horizontal, 22)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(Color.black)
        .ignoresSafeArea()
        .task {
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 700 : 1750))
            guard !Task.isCancelled else { return }
            onComplete()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Welcome to FrozenApps")
    }
}

private struct FrozenRevealWord: View {
    let value: String
    let delay: Double
    let reduceMotion: Bool

    @State private var isVisible = false

    var body: some View {
        Text(value)
            .opacity(isVisible ? 1 : 0)
            .blur(radius: isVisible ? 0 : (reduceMotion ? 0 : 8))
            .offset(y: isVisible || reduceMotion ? 0 : 8)
            .onAppear {
                withAnimation(
                    reduceMotion
                        ? nil
                        : .easeOut(duration: 0.5).delay(delay)
                ) {
                    isVisible = true
                }
            }
    }
}
