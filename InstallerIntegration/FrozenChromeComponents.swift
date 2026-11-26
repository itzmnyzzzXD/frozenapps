import SwiftUI

/// Animated account form follows the real credentials and focused field.
struct FrozenAnimatedAccountReadiness: View {
    let email: String
    let password: String
    let focusedField: AccountField?
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var emailReady: Bool {
        let value = email.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = value.split(separator: "@", omittingEmptySubsequences: false)
        return parts.count == 2 && !parts[0].isEmpty && parts[1].contains(".")
    }
    private var passwordReady: Bool { !password.isEmpty }
    private var completedSteps: Int { (emailReady ? 1 : 0) + (passwordReady ? 1 : 0) }
    private var activeTitle: String {
        switch focusedField {
        case .email: "APPLE ID"
        case .password: "PASSWORD"
        case nil: emailReady ? "PASSWORD" : "APPLE ID"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("ACCOUNT SETUP")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(1.35).foregroundStyle(.white.opacity(0.48))
                    Text(activeTitle)
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .tracking(0.65).foregroundStyle(.white)
                        .contentTransition(.opacity)
                }
                Spacer()
                Text(completedSteps == 2 ? "READY" : "STEP \(min(completedSteps + 1, 2)) OF 2")
                    .font(.system(size: 8, weight: .heavy, design: .rounded).monospacedDigit())
                    .tracking(0.9).foregroundStyle(.white.opacity(completedSteps == 2 ? 0.9 : 0.48))
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.12))
                    Capsule().fill(Color.white.opacity(0.72))
                        .frame(width: proxy.size.width * CGFloat(completedSteps) / 2)
                }
            }
            .frame(height: 3)
            HStack(spacing: 8) {
                statusChip("Apple ID", isComplete: emailReady,
                           isActive: focusedField == .email || (!emailReady && focusedField == nil))
                statusChip("Password", isComplete: passwordReady,
                           isActive: focusedField == .password || (emailReady && !passwordReady && focusedField == nil))
            }
            Text(completedSteps == 2
                 ? "Both fields are filled. Credentials are saved only after you continue."
                 : (focusedField == .password
                    ? "Enter the Apple Account password to continue."
                    : "Start with the Apple Account email address."))
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.white.opacity(0.48))
                .fixedSize(horizontal: false, vertical: true)
                .contentTransition(.opacity)
        }
        .padding(13)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 17, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0.06)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1
                )
        }
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.82), value: emailReady)
        .animation(reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.82), value: passwordReady)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.16), value: focusedField)
    }

    private func statusChip(_ title: String, isComplete: Bool, isActive: Bool) -> some View {
        HStack(spacing: 7) {
            Image(systemName: isComplete ? "checkmark.circle.fill" : "circle")
                .font(.system(size: 11, weight: .semibold))
                .contentTransition(.symbolEffect(.replace))
            Text(title).font(.system(size: 9, weight: .semibold, design: .rounded)).lineLimit(1)
            Spacer(minLength: 0)
            if isActive && !isComplete { Circle().fill(.white).frame(width: 4, height: 4) }
        }
        .foregroundStyle(isComplete ? Color.white : Color.white.opacity(isActive ? 0.92 : 0.48))
        .frame(maxWidth: .infinity, minHeight: 31)
        .padding(.horizontal, 9)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(isComplete ? 0.12 : (isActive ? 0.06 : 0.03)))
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(.white.opacity(isComplete || isActive ? 0.24 : 0.08), lineWidth: 1)
        }
    }
}

/// Word-by-word native reveal. Reduce Motion reveals the message in one frame.
struct FrozenLaunchWelcome: View {
    let onComplete: () -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var revealedCount = 0
    @State private var didComplete = false
    private let words = ["welcome", "to", "frozenapps"]

    var body: some View {
        ZStack {
            Color.black.opacity(0.72).ignoresSafeArea()
            HStack(spacing: 8) {
                ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                    let visible = index < revealedCount
                    Text(word)
                        .font(.system(size: 25, weight: .semibold, design: .rounded))
                        .tracking(-0.7).foregroundStyle(.white)
                        .opacity(visible ? 1 : 0)
                        .blur(radius: visible || reduceMotion ? 0 : 10)
                        .offset(y: visible || reduceMotion ? 0 : 9)
                        .animation(reduceMotion ? nil : .easeOut(duration: 0.38), value: revealedCount)
                }
            }
            .padding(.horizontal, 18)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Welcome to FrozenApps")
        }
        .task {
            if reduceMotion {
                revealedCount = words.count
                guard !didComplete else { return }
                didComplete = true
                onComplete()
                return
            }
            for index in words.indices {
                guard !Task.isCancelled else { return }
                withAnimation(.easeOut(duration: 0.38)) { revealedCount = index + 1 }
                try? await Task.sleep(for: .milliseconds(260))
            }
            try? await Task.sleep(for: .milliseconds(650))
            guard !Task.isCancelled, !didComplete else { return }
            didComplete = true
            onComplete()
        }
    }
}

/// Three install stages from live Engine.stepStates; failure and terminal states remain visible.
struct FrozenInstallProgressStack: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var visibleSteps: [Step] {
        let all = Array(Step.allCases)
        guard !all.isEmpty else { return [] }
        let activeIndex = all.firstIndex { step in
            let state = engine.stepStates[step] ?? .pending
            return state == .active || state == .waiting
        }
        let failedIndex = all.firstIndex { (engine.stepStates[$0] ?? .pending) == .failed }
        let unfinishedIndex = all.firstIndex { (engine.stepStates[$0] ?? .pending) != .done }
        let anchor = activeIndex ?? failedIndex ?? unfinishedIndex ?? (all.count - 1)
        let start = max(0, min(anchor - 1, max(0, all.count - 3)))
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
            ForEach(visibleSteps, id: \.self) { step in stepCard(step) }
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
            Image(systemName: symbol)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white.opacity(emphasis))
                .frame(width: 20, height: 20)
            Text(step.title(for: engine.installSource))
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(state == .pending ? 0.48 : 0.92))
                .lineLimit(1)
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
