import SwiftUI

/// A restrained, monochrome account hero for the native iPad/iPhone setup view.
struct FrozenAccountHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 22) {
            brandLine
            artwork

            VStack(alignment: .leading, spacing: 9) {
                Text("YOUR APPS.\nYOUR WORKSPACE.")
                    .font(.system(size: 29, weight: .bold, design: .rounded))
                    .tracking(-0.75)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)

                Text("A private place to pair your device, prepare signing resources and manage installs.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.56))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 12) {
                capabilityRow(
                    "lock.shield",
                    title: "Credential protection",
                    detail: "Passwords are stored in iOS Keychain"
                )
                capabilityRow(
                    "iphone",
                    title: "Device-first workflow",
                    detail: "Pairing, signing and installation tools"
                )
            }

            HStack(spacing: 8) {
                Circle()
                    .fill(Color.white.opacity(0.78))
                    .frame(width: 5, height: 5)

                Text("PRIVATE DEVICE WORKSPACE")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.25)
                    .foregroundStyle(.white.opacity(0.48))

                Spacer(minLength: 0)

                Image(systemName: "checkmark.seal")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.72))
            }
            .padding(.top, 1)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .fill(Color.black)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 27, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 1)
        }
    }

    private var brandLine: some View {
        HStack(spacing: 9) {
            Image("SideStickMark")
                .resizable()
                .scaledToFit()
                .frame(width: 23, height: 23)

            Text("SIDESTICK")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(.white.opacity(0.92))

            Spacer(minLength: 0)

            Text("01 / CONNECT")
                .font(.system(size: 8, weight: .bold, design: .rounded).monospacedDigit())
                .tracking(0.7)
                .foregroundStyle(.white.opacity(0.42))
        }
    }

    private var artwork: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.white.opacity(0.09), lineWidth: 1)
                .frame(width: 214, height: 214)

            Circle()
                .strokeBorder(Color.white.opacity(0.055), lineWidth: 1)
                .frame(width: 168, height: 168)

            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.black)
                .frame(width: 242, height: 166)
                .overlay {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.19), lineWidth: 1)
                }
                .overlay {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack {
                            HStack(spacing: 4) {
                                ForEach(0..<3, id: \.self) { _ in
                                    Circle()
                                        .fill(Color.white.opacity(0.30))
                                        .frame(width: 5, height: 5)
                                }
                            }

                            Spacer()

                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.45))
                        }

                        HStack(spacing: 10) {
                            iconTile("square.and.arrow.down")
                            iconTile("folder")
                            iconTile("lock.shield")
                            iconTile("iphone")
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("SIGNING WORKSPACE")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .tracking(1.1)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Ready when you are")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.44))
                            }

                            Spacer()

                            Image(systemName: "checkmark.circle")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundStyle(.white.opacity(0.85))
                        }
                    }
                    .padding(16)
                }
                .rotationEffect(.degrees(-4))
                .offset(x: -7, y: -5)

            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.black)
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .strokeBorder(Color.white.opacity(0.22), lineWidth: 1)
                    Image(systemName: "key.horizontal")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("KEYCHAIN STORAGE")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.86))
                    Text("Protected on this device")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer(minLength: 0)

                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(.white.opacity(0.78))
            }
            .padding(10)
            .frame(width: 220)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.black)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.17), lineWidth: 1)
                    }
            }
            .rotationEffect(.degrees(3))
            .offset(x: 20, y: 90)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 258)
        .accessibilityElement(children: .combine)
    }

    private func iconTile(_ symbol: String) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(Color.white.opacity(0.035))
            .frame(width: 39, height: 39)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            }
    }

    private func capabilityRow(_ symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(0.04))
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white.opacity(0.82))
            }
            .frame(width: 35, height: 35)
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
    }
}
