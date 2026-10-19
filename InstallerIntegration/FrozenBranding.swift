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
                let opacity = 0.10 + Double(index % 5) * 0.035
                context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(opacity)))
            }
        }
        .accessibilityHidden(true)
    }
}
