import SwiftUI

/// Six visible OTP slots backed by one real TextField, preserving iOS AutoFill.
struct FrozenAnimatedOTPInput: View {
    @Binding private var code: String
    @FocusState.Binding private var isFocused: Bool

    let isDisabled: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    init(
        code: Binding<String>,
        isFocused: FocusState<Bool>.Binding,
        isDisabled: Bool
    ) {
        self._code = code
        self._isFocused = isFocused
        self.isDisabled = isDisabled
    }

    private var digits: [Character] {
        Array(code)
    }

    private var activeIndex: Int {
        min(digits.count, 5)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(0..<6, id: \.self) { index in
                slot(at: index)
            }
        }
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
                .accessibilityHint("Enter the code Apple sent. The six slots display the digits you enter.")
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
            if sanitized != value {
                code = sanitized
            }
        }
        .onChange(of: isDisabled) { _, disabled in
            if !disabled {
                isFocused = true
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func slot(at index: Int) -> some View {
        let digit = index < digits.count ? String(digits[index]) : nil
        let isActive = index == activeIndex && isFocused && !isDisabled

        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(
                    isActive
                        ? Color.white.opacity(0.105)
                        : Color.white.opacity(digit == nil ? 0.025 : 0.075)
                )

            if let digit {
                Text(digit)
                    .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                    .foregroundStyle(.white)
                    .transition(
                        reduceMotion
                            ? .identity
                            : .asymmetric(
                                insertion: .scale(scale: 0.68).combined(with: .opacity),
                                removal: .opacity
                            )
                    )
                    .id("\(index)-\(digit)")
            } else {
                Circle()
                    .fill(Color.white.opacity(isActive ? 0.68 : 0.18))
                    .frame(width: 4, height: 4)
            }

            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .strokeBorder(
                    Color.white.opacity(isActive ? 0.94 : (digit == nil ? 0.12 : 0.27)),
                    lineWidth: isActive ? 1.35 : 1
                )

            if isActive {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.20), lineWidth: 4)
                    .blur(radius: 5)
                    .padding(-1)
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity)
        .frame(height: 58)
        .animation(
            reduceMotion ? nil : .spring(response: 0.30, dampingFraction: 0.72),
            value: code
        )
    }
}
