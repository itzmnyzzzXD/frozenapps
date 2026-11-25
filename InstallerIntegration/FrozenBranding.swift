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


/// Native TextReveal-style launch gate. It overlays the existing first screen;
/// it does not gate or delay app initialization, storage restoration or auth.
struct FrozenLaunchWelcome: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .largeTitle) private var titleSize: CGFloat = 44
    @State private var didComplete = false

    private let words = ["Welcome", "to", "FrozenApps"]

    var body: some View {
        Color.clear
            .overlay {
                FrozenWelcomeWordLayout(spacing: 4) {
                    ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                        FrozenRevealWord(
                            value: word,
                            delay: Double(index) * 0.2,
                            reduceMotion: reduceMotion
                        )
                    }
                }
                .font(.system(size: titleSize, weight: .semibold, design: .default))
                .foregroundStyle(Color.white)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .padding(.horizontal, 24)
            }
            .contentShape(Rectangle())
            .ignoresSafeArea()
            .onTapGesture(perform: finish)
            .task(id: reduceMotion) {
                // Standard: last word starts at 0.4s, finishes at 0.9s,
                // then holds for 0.8s. Reduce Motion: 0.3s fade + 0.6s hold.
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 900 : 1_700))
                guard !Task.isCancelled else { return }
                finish()
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Welcome to FrozenApps")
            .accessibilityAddTraits(.isButton)
            .accessibilityHint("Tap to continue")
            .accessibilityAction(.activate, finish)
    }

    private func finish() {
        guard !didComplete else { return }
        didComplete = true
        onComplete()
    }
}

private struct FrozenRevealWord: View {
    let value: String
    let delay: Double
    let reduceMotion: Bool

    @State private var isVisible = false

    var body: some View {
        Text(value)
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .fixedSize(horizontal: true, vertical: false)
            .opacity(isVisible ? 1 : 0)
            .blur(radius: reduceMotion || isVisible ? 0 : 8)
            .onAppear {
                reveal()
            }
            .onChange(of: reduceMotion) { _, reduced in
                if reduced && !isVisible {
                    withAnimation(.easeOut(duration: 0.3)) {
                        isVisible = true
                    }
                }
            }
    }

    private func reveal() {
        guard !isVisible else { return }
        if reduceMotion {
            withAnimation(.easeOut(duration: 0.3)) {
                isVisible = true
            }
        } else {
            withAnimation(.easeOut(duration: 0.5).delay(delay)) {
                isVisible = true
            }
        }
    }
}

/// A small word-wrapping Layout so the display stays centered without forcing
/// the three words onto one line on narrow iPhone widths or large Dynamic Type.
private struct FrozenWelcomeWordLayout: Layout {
    let spacing: CGFloat

    private struct Line {
        var indices: [Int]
        var sizes: [CGSize]
        var width: CGFloat
        var height: CGFloat
    }

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let lines = makeLines(width: proposal.width ?? .infinity, subviews: subviews)
        let contentWidth = proposal.width ?? (lines.map(\.width).max() ?? 0)
        let contentHeight = lines.reduce(CGFloat.zero) { $0 + $1.height }
            + CGFloat(max(0, lines.count - 1)) * spacing
        return CGSize(width: contentWidth, height: contentHeight)
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let lines = makeLines(width: bounds.width, subviews: subviews)
        var y = bounds.minY

        for line in lines {
            var x = bounds.minX + max(0, (bounds.width - line.width) / 2)
            for (offset, index) in line.indices.enumerated() {
                let size = line.sizes[offset]
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    anchor: .topLeading,
                    proposal: ProposedViewSize(width: size.width, height: size.height)
                )
                x += size.width + spacing
            }
            y += line.height + spacing
        }
    }

    private func makeLines(width: CGFloat, subviews: Subviews) -> [Line] {
        let availableWidth = max(1, width)
        var result: [Line] = []
        var current = Line(indices: [], sizes: [], width: 0, height: 0)

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let nextWidth = current.indices.isEmpty
                ? size.width
                : current.width + spacing + size.width

            if !current.indices.isEmpty && nextWidth > availableWidth {
                result.append(current)
                current = Line(indices: [], sizes: [], width: 0, height: 0)
            }

            let lineWidth = current.indices.isEmpty
                ? size.width
                : current.width + spacing + size.width
            current.indices.append(index)
            current.sizes.append(size)
            current.width = lineWidth
            current.height = max(current.height, size.height)
        }

        if !current.indices.isEmpty {
            result.append(current)
        }
        return result
    }
}
