import SwiftUI

/// Native, asset-free hero artwork for the responsive FrozenApps account screen.
/// Built from SwiftUI shapes so it remains crisp on iPhone and iPad and works offline.
struct FrozenAccountHero: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 19) {
            HStack(spacing: 8) {
                Image(systemName: "snowflake")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent2)
                Text("FROZENAPPS")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.8)
                    .foregroundStyle(.white.opacity(0.92))
                Spacer(minLength: 0)
                Text("01 / CONNECT")
                    .font(.system(size: 8, weight: .bold, design: .rounded).monospacedDigit())
                    .tracking(0.7)
                    .foregroundStyle(.white.opacity(0.4))
            }

            artwork
                .frame(height: 275)

            VStack(alignment: .leading, spacing: 10) {
                Text("YOUR APPS.\nYOUR WORKSPACE.")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .tracking(-0.7)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.white, Theme.accent2, Theme.violet.opacity(0.95)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .fixedSize(horizontal: false, vertical: true)

                Text("A cleaner place to pair your device, prepare signing resources and manage installs.")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: 10) {
                capabilityRow(
                    "checkmark.shield.fill",
                    title: "Private by design",
                    detail: "Credentials stay in iOS Keychain"
                )
                capabilityRow(
                    "point.3.connected.trianglepath.dotted",
                    title: "Device-first workflow",
                    detail: "Pairing, signing and install tools"
                )
            }

            HStack(spacing: 7) {
                Circle()
                    .fill(Color.green.opacity(0.95))
                    .frame(width: 6, height: 6)
                    .shadow(color: .green.opacity(0.5), radius: 5)
                Text("LOCAL WORKSPACE")
                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                    .tracking(1.35)
                    .foregroundStyle(.white.opacity(0.48))
                Spacer(minLength: 0)
                Image(systemName: "sparkles")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Theme.accent2.opacity(0.7))
            }
            .padding(.top, 1)
        }
        .padding(22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.025, green: 0.03, blue: 0.085),
                            Color(red: 0.025, green: 0.02, blue: 0.065),
                            Color.black.opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        }
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), Theme.accent.opacity(0.3),
                                 Theme.violet.opacity(0.25), .white.opacity(0.045)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Theme.violet.opacity(0.12), radius: 28, x: 0, y: 14)
    }

    private var artwork: some View {
        ZStack {
            Circle()
                .fill(Theme.violet.opacity(0.23))
                .frame(width: 205, height: 205)
                .blur(radius: 36)
                .offset(x: 10, y: -1)

            Circle()
                .fill(Theme.accent.opacity(0.24))
                .frame(width: 165, height: 165)
                .blur(radius: 32)
                .offset(x: -38, y: 32)

            Circle()
                .strokeBorder(Theme.accent2.opacity(0.20), lineWidth: 1)
                .frame(width: 235, height: 235)

            Circle()
                .strokeBorder(.white.opacity(0.07), lineWidth: 1)
                .frame(width: 190, height: 190)

            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.045, green: 0.055, blue: 0.13),
                            Color(red: 0.015, green: 0.02, blue: 0.055)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay {
                    VStack(alignment: .leading, spacing: 13) {
                        HStack {
                            HStack(spacing: 4) {
                                Circle().fill(.white.opacity(0.26)).frame(width: 5, height: 5)
                                Circle().fill(.white.opacity(0.16)).frame(width: 5, height: 5)
                                Circle().fill(.white.opacity(0.1)).frame(width: 5, height: 5)
                            }
                            Spacer()
                            Image(systemName: "ellipsis")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white.opacity(0.36))
                        }

                        HStack(spacing: 8) {
                            appTile("signature", tint: Theme.accent)
                            appTile("folder.fill", tint: Theme.violet)
                            appTile("shield.lefthalf.filled", tint: Theme.accent2)
                            appTile("point.3.connected.trianglepath.dotted", tint: Theme.violet.opacity(0.85))
                        }

                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("SIGNING ENGINE")
                                    .font(.system(size: 8, weight: .heavy, design: .rounded))
                                    .tracking(1.1)
                                    .foregroundStyle(.white.opacity(0.8))
                                Text("Workspace ready")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Theme.accent2)
                        }

                        GeometryReader { bar in
                            ZStack(alignment: .leading) {
                                Capsule().fill(.white.opacity(0.08))
                                Capsule()
                                    .fill(LinearGradient(colors: [Theme.accent, Theme.violet, Theme.accent2],
                                                         startPoint: .leading, endPoint: .trailing))
                                    .frame(width: bar.size.width * 0.78)
                            }
                        }
                        .frame(height: 4)
                    }
                    .padding(16)
                }
                .frame(width: 245, height: 176)
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .strokeBorder(.white.opacity(0.16), lineWidth: 1)
                }
                .shadow(color: Theme.accent.opacity(0.2), radius: 22, x: 0, y: 12)
                .rotationEffect(.degrees(-6))
                .offset(x: -13, y: -16)

            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 11, style: .continuous)
                        .fill(LinearGradient(colors: [Theme.violet, Theme.accent],
                                             startPoint: .topLeading, endPoint: .bottomTrailing))
                    Image(systemName: "lock.shield.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 34, height: 34)

                VStack(alignment: .leading, spacing: 3) {
                    Text("KEYCHAIN PROTECTED")
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .tracking(0.6)
                        .foregroundStyle(.white.opacity(0.86))
                    Text("Stored on this device")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.43))
                }
                Spacer(minLength: 0)
                Image(systemName: "checkmark")
                    .font(.system(size: 9, weight: .heavy))
                    .foregroundStyle(Theme.accent2)
            }
            .padding(10)
            .frame(width: 220)
            .background {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .fill(Color.black.opacity(0.94))
            }
            .overlay {
                RoundedRectangle(cornerRadius: 15, style: .continuous)
                    .strokeBorder(.white.opacity(0.18), lineWidth: 1)
            }
            .shadow(color: .black.opacity(0.35), radius: 14, x: 0, y: 8)
            .rotationEffect(.degrees(4))
            .offset(x: 28, y: 88)

            ZStack {
                Circle()
                    .fill(Color.black.opacity(0.85))
                Circle()
                    .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                    .padding(5)
                Image(systemName: "snowflake")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 50, height: 50)
            .background(Circle().fill(Theme.brand))
            .shadow(color: Theme.violet.opacity(0.35), radius: 15, x: 0, y: 5)
            .offset(x: 112, y: -99)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    private func appTile(_ symbol: String, tint: Color) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(LinearGradient(colors: [tint.opacity(0.95), tint.opacity(0.52)],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 38, height: 38)
            .overlay {
                Image(systemName: symbol)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
            }
    }

    private func capabilityRow(_ symbol: String, title: String, detail: String) -> some View {
        HStack(spacing: 10) {
            ZStack {
                RoundedRectangle(cornerRadius: 11, style: .continuous)
                    .fill(.white.opacity(0.055))
                Image(systemName: symbol)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
            }
            .frame(width: 35, height: 35)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white.opacity(0.88))
                Text(detail)
                    .font(.system(size: 9, weight: .medium))
                    .foregroundStyle(.white.opacity(0.45))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }
}