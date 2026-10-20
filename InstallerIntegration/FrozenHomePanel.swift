import SwiftUI

extension Notification.Name {
    static let frozenAppsOpenNetwork = Notification.Name("FrozenApps.OpenNetwork")
}

/// FrozenApps' quick status card on the Signer screen. Actions navigate into
/// FrozenApps-owned tools rather than adding controls to the upstream engine UI.
struct FrozenHomePanel: View {
    let wifiConnected: Bool
    let tunnelConnected: Bool
    let deviceSummary: String?
    let onOpenNetwork: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 15) {
            HStack(spacing: 7) {
                Image(systemName: "sparkles")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent2)
                Text("FROZENAPPS  /  YOUR WORKSPACE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(.white.opacity(0.78))
                Spacer()
                Text("1.0.7")
                    .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.accent2)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.accent2.opacity(0.12), in: Capsule())
            }

            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 7) {
                    Text("Everything,\nin one place.")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-0.65)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Discover apps, pair your device, sign packages and keep your library organised.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.62))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ZStack {
                    Circle()
                        .fill(Theme.accent.opacity(0.20))
                        .frame(width: 78, height: 78)
                    Circle()
                        .strokeBorder(Theme.accent2.opacity(0.25), lineWidth: 1)
                        .frame(width: 78, height: 78)
                    Image(systemName: "snowflake")
                        .font(.system(size: 35, weight: .medium))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Theme.accent2)
                        .shadow(color: Theme.accent2.opacity(0.5), radius: 12)
                }
                .accessibilityHidden(true)
            }

            HStack(spacing: 8) {
                statusChip(wifiConnected ? "Wi-Fi ready" : "Wi-Fi check", icon: wifiConnected ? "wifi" : "wifi.slash", tint: wifiConnected ? .green : .orange)
                statusChip(tunnelConnected ? "Tunnel active" : "Tunnel idle", icon: tunnelConnected ? "shield.lefthalf.filled" : "shield.slash", tint: tunnelConnected ? Theme.accent2 : .white.opacity(0.58))
            }

            if let deviceSummary, !deviceSummary.isEmpty {
                Label(deviceSummary, systemImage: "iphone")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.62))
                    .lineLimit(1)
            }

            Button(action: onOpenNetwork) {
                HStack(spacing: 9) {
                    Image(systemName: "sparkles.rectangle.stack")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Open connection center")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Image(systemName: "arrow.up.right")
                        .font(.system(size: 11, weight: .bold))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 13)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(LinearGradient(colors: [.white.opacity(0.32), Theme.accent.opacity(0.26), .white.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
                }
            }
            .buttonStyle(FrozenGlassPressStyle())
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.025, blue: 0.055),
                        Color(red: 0.22, green: 0.045, blue: 0.085),
                        Color(red: 0.035, green: 0.018, blue: 0.03)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Theme.accent.opacity(0.28))
                    .frame(width: 175, height: 175)
                    .blur(radius: 34)
                    .offset(x: 55, y: -65)
                Circle()
                    .fill(Theme.accent2.opacity(0.14))
                    .frame(width: 130, height: 130)
                    .blur(radius: 28)
                    .offset(x: -90, y: 100)
            }
            .clipShape(RoundedRectangle(cornerRadius: 26, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.24), Theme.accent.opacity(0.45), .white.opacity(0.06)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Theme.accent.opacity(0.16), radius: 22, x: 0, y: 10)
    }

    private func statusChip(_ title: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 10, weight: .bold))
            Text(title)
                .font(.system(size: 10, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.11), in: Capsule())
        .overlay { Capsule().strokeBorder(tint.opacity(0.22), lineWidth: 1) }
    }
}
