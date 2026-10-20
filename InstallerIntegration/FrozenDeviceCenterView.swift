import Foundation
import SwiftUI
import Network
import UIKit

/// Consolidated diagnostics hub. It only reports facts exposed by the OS and
/// explicitly labels pairing/JIT state that cannot be independently confirmed.
struct FrozenDeviceCenterView: View {
    @Environment(\.openURL) private var openURL
    @State private var pathMonitor: NWPathMonitor?
    @State private var networkState = "Checking network…"
    @State private var connectionType = "Not detected"
    @State private var checkedAt: Date?
    @State private var copied = false

    private var report: String {
        let date = ISO8601DateFormatter().string(from: checkedAt ?? Date())
        return """
        FrozenApps Device Diagnostic Report
        Generated: \(date)
        Device model: \(UIDevice.current.model)
        iOS/iPadOS: \(UIDevice.current.systemVersion)
        Network status: \(networkState)
        Connection type: \(connectionType)
        Pairing state: NOT VERIFIED by this report
        JIT state: NOT VERIFIED by this report
        Helper compatibility: Check in JIT Center using the actual helper address
        Recovery: Confirm both devices share the same reachable network; review Local Network permission; reopen the helper; retry pairing in Signer; check the helper's own logs.
        Privacy: This report contains basic device/OS/network diagnostics only. Review before sharing.
        """
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 11) {
                                Image(systemName: "point.3.connected.trianglepath.dotted")
                                    .font(.system(size: 22, weight: .bold))
                                    .foregroundStyle(.white)
                                    .frame(width: 48, height: 48)
                                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 15))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("FROZENAPPS · DEVICE CENTER")
                                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                                        .tracking(1.3).foregroundStyle(Theme.accent2)
                                    Text("Connection diagnostics")
                                        .font(.system(size: 21, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                }
                            }
                            Text("One place for network checks, pairing recovery, helper checks and JIT troubleshooting. This screen never assumes pairing or JIT is active without evidence.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.57))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }

                    PanelCard {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("DEVICE SNAPSHOT")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(1.4).foregroundStyle(Theme.accent2)
                            deviceRow("Device", UIDevice.current.model, "ipad.and.iphone")
                            deviceRow("OS version", "iOS/iPadOS \(UIDevice.current.systemVersion)", "gearshape.2")
                            Divider().overlay(.white.opacity(0.08))
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: networkState == "Connected" ? "wifi" : "wifi.exclamationmark")
                                    .foregroundStyle(networkState == "Connected" ? Theme.accent2 : .orange)
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Network: \(networkState)")
                                        .font(.system(size: 12, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Path type: \(connectionType)")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.52))
                                    if let checkedAt {
                                        Text("Checked \(checkedAt.formatted(date: .omitted, time: .shortened))")
                                            .font(.system(size: 9, weight: .medium))
                                            .foregroundStyle(.white.opacity(0.4))
                                    }
                                }
                                Spacer()
                                Button("Refresh") { startNetworkCheck() }
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .buttonStyle(.plain).foregroundStyle(Theme.accent2)
                            }
                        }
                    }

                    NavigationLink { FrozenNetworkView() } label: {
                        actionCard(title: "Pairing & Network Tools",
                                   subtitle: "Local network checks, discovery and connection information",
                                   icon: "wifi",
                                   tint: .orange)
                    }.buttonStyle(.plain)

                    NavigationLink { FrozenJITView() } label: {
                        actionCard(title: "Check JIT Helper",
                                   subtitle: "Probe the configured helper and inspect its actual response",
                                   icon: "bolt.fill",
                                   tint: Theme.accent2)
                    }.buttonStyle(.plain)

                    PanelCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Recovery checklist", systemImage: "wrench.and.screwdriver.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            recoveryRow("1", "Check the same network", "Keep the iPad and helper on a reachable network; guest Wi-Fi and client isolation can block discovery.")
                            recoveryRow("2", "Review Local Network permission", "Open iPad Settings and allow FrozenApps local-network access if the toggle is shown.")
                            recoveryRow("3", "Restart the helper", "Confirm its documented address and port, then use JIT Center to probe the helper instead of assuming it is online.")
                            recoveryRow("4", "Retry pairing in Signer", "Follow the supported pairing flow. Some iOS versions require an existing pairing file and computer-assisted setup.")
                        }
                    }

                    PanelCard {
                        VStack(alignment: .leading, spacing: 9) {
                            Text("COPYABLE DIAGNOSTICS")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(1.4).foregroundStyle(Theme.accent2)
                            Text("The report intentionally marks pairing and JIT as unverified. It does not include passwords, private keys, Apple Account details or a device UDID.")
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.52))
                            Button {
                                UIPasteboard.general.string = report
                                copied = true
                            } label: {
                                Label(copied ? "Report copied" : "Copy diagnostic report",
                                      systemImage: copied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.system(size: 11, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity).padding(12)
                                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain).foregroundStyle(.white)
                        }
                    }
                }
                .padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Device Center")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear { startNetworkCheck() }
        .onDisappear {
            pathMonitor?.cancel()
            pathMonitor = nil
        }
    }

    private func deviceRow(_ title: String, _ value: String, _ icon: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(Theme.accent2).frame(width: 20)
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.56))
            Spacer()
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
        }
    }

    private func actionCard(title: String, subtitle: String, icon: String, tint: Color) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon).font(.system(size: 18, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 42, height: 42).background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 13))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.54)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
            Image(systemName: "chevron.right").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.35))
        }
        .padding(14)
        .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 17))
        .overlay { RoundedRectangle(cornerRadius: 17).strokeBorder(.white.opacity(0.08)) }
    }

    private func recoveryRow(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number).font(.system(size: 10, weight: .heavy, design: .rounded)).foregroundStyle(Theme.accent2)
                .frame(width: 23, height: 23).background(Theme.accent.opacity(0.14), in: Circle())
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .bold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.53)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func startNetworkCheck() {
        pathMonitor?.cancel()
        let monitor = NWPathMonitor()
        pathMonitor = monitor
        networkState = "Checking network…"
        connectionType = "Checking"
        monitor.pathUpdateHandler = { path in
            DispatchQueue.main.async {
                networkState = path.status == .satisfied ? "Connected" : "Unavailable"
                if path.usesInterfaceType(.wifi) { connectionType = "Wi-Fi" }
                else if path.usesInterfaceType(.wiredEthernet) { connectionType = "Ethernet" }
                else if path.usesInterfaceType(.cellular) { connectionType = "Cellular" }
                else if path.usesInterfaceType(.loopback) { connectionType = "Loopback" }
                else { connectionType = "Other / unknown" }
                checkedAt = Date()
            }
        }
        monitor.start(queue: DispatchQueue(label: "FrozenApps.DeviceCenter.NetworkPath"))
    }
}
