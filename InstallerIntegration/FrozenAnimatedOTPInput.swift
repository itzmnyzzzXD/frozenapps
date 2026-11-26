import SwiftUI

/// Six animated OTP slots backed by one real TextField, preserving iOS AutoFill.
struct FrozenAnimatedOTPInput: View {
    @Binding private var code: String
    @FocusState.Binding private var isFocused: Bool

    let isDisabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency

    private static let accent = Color(hue: 0.37, saturation: 0.82, brightness: 0.88)

    init(
        code: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        isDisabled: Bool
    ) {
        self._code = code
        self._isFocused = isFocused
        self.isDisabled = isDisabled
    }

    private var digits: [Character] { Array(code) }
    private var activeIndex: Int { min(digits.count, 5) }
    private var isComplete: Bool { digits.count == 6 }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                slot(at: index)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Six-digit verification code")
        .accessibilityValue("\(digits.count) of 6 digits entered")
        .accessibilityHint("Enter the code Apple sent. The six slots display the digits you enter.")
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
                .padding(.horizontal, 8)
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
        .onChange(of: code) { _, value in
            let sanitized = String(value.filter(\.isNumber).prefix(6))
            if sanitized != value { code = sanitized }
        }
        .onChange(of: isDisabled) { _, disabled in
            if !disabled { isFocused = true }
        }
        .animation(reduceMotion ? nil : .spring(response: 0.32, dampingFraction: 0.76), value: code)
        .animation(reduceMotion ? nil : .easeOut(duration: 0.2), value: isFocused)
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        let digit = index < digits.count ? String(digits[index]) : nil
        let isActive = index == activeIndex && isFocused && !isDisabled
        let isFilled = digit != nil

        ZStack {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(
                    isActive
                        ? Self.accent.opacity(reduceTransparency ? 0.13 : 0.105)
                        : Color.white.opacity(isFilled ? 0.075 : 0.025)
                )

            if let digit {
                Text(digit)
                    .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(isComplete ? Self.accent : .white)
                    .transition(
                        reduceMotion
                            ? .identity
                            : .asymmetric(
                                insertion: .scale(scale: 0.62).combined(with: .offset(y: 5)).combined(with: .opacity),
                                removal: .scale(scale: 0.82).combined(with: .opacity)
                            )
                    )
                    .id("\(index)-\(digit)")
            } else {
                Circle()
                    .fill(isActive ? Self.accent.opacity(0.9) : Color.white.opacity(0.18))
                    .frame(width: 4, height: 4)
            }

            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(
                    isComplete
                        ? Self.accent.opacity(0.78)
                        : (isActive ? Self.accent : Color.white.opacity(isFilled ? 0.27 : 0.12)),
                    lineWidth: isActive || isComplete ? 1.35 : 1
                )

            if isActive && !reduceMotion {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .strokeBorder(Self.accent.opacity(0.32), lineWidth: 4)
                    .blur(radius: 5)
                    .padding(-1)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .scaleEffect(isActive && !reduceMotion ? 1.025 : 1)
        .accessibilityHidden(true)
    }
}
