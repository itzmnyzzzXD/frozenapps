import SwiftUI

/// Six animated OTP slots backed by one real AutoFill-enabled TextField.
struct FrozenAnimatedOTPInput: View {
    @Binding private var code: String
    @FocusState.Binding private var isFocused: Bool

    let isDisabled: Bool
    let isWorking: Bool
    let statusMessage: String?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    init(
        code: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        isDisabled: Bool,
        isWorking: Bool = false,
        statusMessage: String? = nil
    ) {
        self._code = code
        self._isFocused = isFocused
        self.isDisabled = isDisabled
        self.isWorking = isWorking
        self.statusMessage = statusMessage
    }

    private var digits: [Character] { Array(code) }
    private var activeIndex: Int { min(digits.count, 5) }
    private var isComplete: Bool { digits.count == 6 }
    private var cleanStatus: String? {
        guard let statusMessage, !statusMessage.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return nil
        }
        return statusMessage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                Text("SECURE ACCESS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.25).foregroundStyle(.white)
                Spacer()
                Text("APPLE ID")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(0.9).foregroundStyle(.white.opacity(0.48))
            }

            HStack(spacing: 12) {
                FrozenOTPSecurityOrb().frame(width: 74, height: 74)
                VStack(alignment: .leading, spacing: 5) {
                    Text("Verify it's you")
                        .font(.system(size: 15, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    Text("Enter the six-digit code Apple sent to your trusted device or phone.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.56))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 7) {
                ForEach(0..<6, id: \.self) { index in slot(at: index) }
            }
            .accessibilityHidden(true)
            .overlay {
                TextField("", text: $code)
                    .keyboardType(.numberPad)
                    .textContentType(.oneTimeCode)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.plain)
                    .focused($isFocused)
                    .disabled(isDisabled)
                    .foregroundStyle(.clear)
                    .tint(.clear)
                    .opacity(0.02)
                    .padding(.horizontal, 2)
                    .frame(maxWidth: .infinity, minHeight: 58, maxHeight: 58)
                    .accessibilityLabel("6-digit verification code")
                    .accessibilityIdentifier("frozenapps.verificationCode")
            }
            .frame(height: 58)
            .contentShape(Rectangle())
            .onTapGesture {
                guard !isDisabled else { return }
                isFocused = true
            }

            HStack(spacing: 7) {
                if isWorking {
                    ProgressView().controlSize(.small).tint(.white)
                    Text("Verifying code…")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.72))
                } else if let cleanStatus {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                    Text(cleanStatus)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.84))
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Image(systemName: isComplete ? "checkmark.circle.fill" : "info.circle")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(isComplete ? 0.92 : 0.48))
                    Text(isComplete ? "Code ready to verify" : "Your code is kept in this sheet only.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.54))
                }
                Spacer(minLength: 0)
                Text("\(digits.count)/6")
                    .font(.system(size: 9, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white.opacity(0.48))
            }
        }
        .padding(14)
        .background(Color.black.opacity(0.72), in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .strokeBorder(
                    LinearGradient(colors: [.white.opacity(0.24), .white.opacity(0.06), .white.opacity(0.12)],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    lineWidth: 1
                )
        }
        .accessibilityElement(children: .contain)
        .onChange(of: code) { _, value in
            let sanitized = String(value.filter { $0.isASCII && $0.isNumber }.prefix(6))
            if sanitized != value { code = sanitized }
        }
        .onChange(of: isDisabled) { _, disabled in
            if !disabled { isFocused = true }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.76), value: code)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFocused)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.18), value: isWorking)
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        let digit = index < digits.count ? String(digits[index]) : nil
        let isActive = index == activeIndex && isFocused && !isDisabled
        let isFilled = digit != nil

        ZStack {
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(isActive
                    ? Color.white.opacity(reduceTransparency ? 0.24 : 0.12)
                    : Color.white.opacity(isFilled ? 0.12 : 0.03))
            if let digit {
                Text(digit)
                    .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .transition(
                        reduceMotion ? .identity :
                            .asymmetric(
                                insertion: .scale(scale: 0.62).combined(with: .offset(y: 5)).combined(with: .opacity),
                                removal: .scale(scale: 0.82).combined(with: .opacity)
                            )
                    )
                    .id("\(index)-\(digit)")
            } else {
                Circle().fill(Color.white.opacity(isActive ? 0.72 : 0.18)).frame(width: 4, height: 4)
            }
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .strokeBorder(
                    isActive || isComplete ? .white.opacity(0.84) : Color.white.opacity(isFilled ? 0.24 : 0.12),
                    lineWidth: isActive || isComplete ? 1.35 : 1
                )
        }
        .frame(maxWidth: .infinity).frame(height: 58)
        .scaleEffect(isActive && !reduceMotion ? 1.025 : 1)
    }
}

/// Native orbital mark that pauses with Reduce Motion.
struct FrozenOTPSecurityOrb: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 30.0, paused: reduceMotion)) { timeline in
            let cycle = timeline.date.timeIntervalSinceReferenceDate
                .truncatingRemainder(dividingBy: 32) / 32
            let angle = reduceMotion ? 0 : cycle * 360
            ZStack {
                Circle()
                    .fill(RadialGradient(
                        colors: [.white.opacity(0.24), .white.opacity(0.06), .clear],
                        center: .center, startRadius: 8, endRadius: 40
                    ))
                    .padding(-7)
                Circle()
                    .strokeBorder(.white.opacity(0.16), style: StrokeStyle(lineWidth: 1, dash: [2, 5]))
                    .rotationEffect(.degrees(angle * 0.55))
                Ellipse()
                    .stroke(.white.opacity(0.78), lineWidth: 1.15)
                    .frame(width: 68, height: 28)
                    .rotation3DEffect(.degrees(62), axis: (x: 1, y: 0, z: 0))
                    .rotationEffect(.degrees(angle))
                Ellipse()
                    .stroke(.white.opacity(0.32), lineWidth: 0.8)
                    .frame(width: 68, height: 28)
                    .rotation3DEffect(.degrees(-62), axis: (x: 1, y: 0, z: 0))
                    .rotationEffect(.degrees(-angle * 0.72))
                Circle()
                    .fill(RadialGradient(
                        colors: [.white, .white.opacity(0.72), .white.opacity(0.18)],
                        center: .init(x: 0.34, y: 0.28), startRadius: 1, endRadius: 22
                    ))
                    .frame(width: 36, height: 36)
                    .overlay { Circle().strokeBorder(.white.opacity(0.72), lineWidth: 0.8) }
                    .shadow(color: .white.opacity(0.24), radius: 11)
            }
        }
        .frame(width: 74, height: 74)
        .accessibilityHidden(true)
    }
}
