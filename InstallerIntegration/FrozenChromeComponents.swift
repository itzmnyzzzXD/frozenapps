import SwiftUI

/// Animated form feedback follows the actual Apple ID and password bindings.
struct FrozenAnimatedAccountReadiness: View {
    let email: String
    let password: String
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var emailReady: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
    }
    private var passwordReady: Bool { !password.isEmpty }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text("FORM PROGRESS")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.3).foregroundStyle(.white.opacity(0.52))
                Spacer()
                Text(emailReady && passwordReady ? "READY" : "INCOMPLETE")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.0)
                    .foregroundStyle(emailReady && passwordReady ? .white : .white.opacity(0.42))
                    .contentTransition(.opacity)
            }
            HStack(spacing: 7) {
                statusChip("Apple ID", isComplete: emailReady)
                statusChip("Password", isComplete: passwordReady)
            }
        }
        .padding(12)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(.white.opacity(0.10), lineWidth: 1)
        }
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.78), value: emailReady)
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.78), value: passwordReady)
    }

    private func statusChip(_ title: String, isComplete: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
            Text(title).font(.system(size: 9, weight: .semibold, design: .rounded)).lineLimit(1)
        }
        .foregroundStyle(isComplete ? Color.white : Color.white.opacity(0.54))
        .frame(maxWidth: .infinity, minHeight: 30)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isComplete ? 0.12 : 0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(isComplete ? 0.22 : 0.08), lineWidth: 1)
        }
    }
}

/// Word-by-word native reveal shown on app launch.
struct FrozenLaunchWelcome: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedCount = 0
    @State private var didComplete = false
    private let words = ["welcome", "to", "frozenapps"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.42).ignoresSafeArea()
            HStack(spacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let visible = index < revealedCount
                    Text(word)
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .tracking(-0.7).foregroundStyle(.white)
                        .opacity(visible ? 1 : 0.08)
                        .blur(radius: visible || reduceMotion ? 0 : 10)
                        .offset(y: visible ? 0 : 9)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.38), value: revealedCount)
                }
            }
            .padding(.horizontal, 18)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Welcome to FrozenApps")
        }
        .task {
            for index in words.indices {
                guard !Task.isCancelled else { return }
                withAnimation(reduceMotion ? nil : .easeOut(duration: 0.38)) {
                    revealedCount = index + 1
                }
                try? await Task.sleep(for: .milliseconds(reduceMotion ? 120 : 260))
            }
            try? await Task.sleep(for: .milliseconds(reduceMotion ? 280 : 850))
            guard !Task.isCancelled, !didComplete else { return }
            didComplete = true
            onComplete()
        }
    }
}

/// Three visible stages, driven only by the install engine's current StepState values.
struct FrozenInstallProgressStack: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleSteps: [Step] {
        let all = Array(Step.allCases)
        guard !all.isEmpty else { return [] }
        let current = all.firstIndex { step in
            switch engine.stepStates[step] ?? .pending {
            case .active, .waiting: true
            case .pending, .done, .failed: false
            }
        } ?? 0
        let start = max(0, min(current - 1, all.count - 3))
        return Array(all.dropFirst(start).prefix(3))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack {
                Text("INSTALL PIPELINE")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.25).foregroundStyle(.white.opacity(0.48))
                Spacer()
                Text("\(Step.allCases.filter { engine.stepStates[$0] == .done }.count)/\(Step.allCases.count)")
                    .font(.system(size: 9, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.66))
            }
            ForEach(visibleSteps, id: \.self) { step in
                stepCard(step)
            }
        }
        .animation(
            reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.82),
            value: visibleSteps.map(\.id)
        )
    }

    private func stepCard(_ step: Step) -> some View {
        let state = engine.stepStates[step] ?? .pending
        let (symbol, label, emphasis): (String, String, Double) = {
            switch state {
            case .pending: ("circle", "Queued", 0.40)
            case .active: ("arrow.triangle.2.circlepath", "In progress", 1.0)
            case .waiting: ("pause.circle.fill", "Waiting", 0.86)
            case .done: ("checkmark.circle.fill", "Complete", 0.72)
            case .failed: ("exclamationmark.circle.fill", "Failed", 1.0)
            }
        }()
        return HStack(spacing: 9) {
            Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(emphasis)).frame(width: 20, height: 20)
            Text(step.title(for: engine.installSource))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(state == .pending ? 0.48 : 0.92)).lineLimit(1)
            Spacer(minLength: 4)
            Text(label.uppercased())
                .font(.system(size: 7, weight: .heavy, design: .rounded))
                .tracking(0.8).foregroundStyle(.white.opacity(emphasis * 0.78))
        }
        .padding(.horizontal, 10).frame(minHeight: 35)
        .background(
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(Color.white.opacity(state == .active ? 0.12 : 0.035))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .strokeBorder(.white.opacity(state == .active ? 0.24 : 0.07), lineWidth: 1)
        }
        .accessibilityElement(children: .combine)
    }
}
