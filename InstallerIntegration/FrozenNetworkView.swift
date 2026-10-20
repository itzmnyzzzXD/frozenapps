import SwiftUI
import Network
import Darwin
import UIKit

/// A FrozenApps-owned local-network diagnostics screen. It reports the active
/// system path, local IPv4 addresses and Bonjour discovery state. It does not
/// bypass iOS privacy controls or replace the install engine's pairing steps.
struct FrozenNetworkView: View {
    @StateObject private var diagnostics = FrozenNetworkDiagnostics()
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    intro
                    connectionCard
                    localAccessCard
                    discoveryCard
                    privacyNote
                }
                .padding(20)
                .padding(.bottom, 18)
            }
            .background(AppBackground())
            .navigationTitle("Network")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        diagnostics.refresh()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .buttonStyle(FrozenGlassPressStyle())
                    .accessibilityLabel("Refresh network details")
                }
            }
        }
        .tint(Theme.accent2)
        .onDisappear { diagnostics.stopDiscovery() }
    }

    private var intro: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(Theme.brand)
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .font(.system(size: 21, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 48, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text("PAIRING SETUP")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(Theme.accent2)
                    Text("Pair with FrozenApps")
                        .font(.system(size: 23, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                }
            }
            Text("Prepare this iPad for pairing. Check Local Network access, confirm Wi-Fi, and inspect local addresses before connecting a device.")
                .font(.system(size: 13))
                .foregroundStyle(.white.opacity(0.56))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .frozenGlassSurface(cornerRadius: 24, tint: Theme.accent, elevated: true)
    }

    private var connectionCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 15) {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill((diagnostics.isConnected ? Color.green : Color.orange).opacity(0.13))
                            .frame(width: 48, height: 48)
                        Image(systemName: diagnostics.isConnected ? "network" : "wifi.slash")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(diagnostics.isConnected ? .green : .orange)
                    }
                    VStack(alignment: .leading, spacing: 4) {
                        Text(diagnostics.pathStatus)
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                        Text(diagnostics.interfaceDescription)
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    Spacer(minLength: 0)
                    Circle()
                        .fill(diagnostics.isConnected ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)
                }

                Rectangle()
                    .fill(.white.opacity(0.08))
                    .frame(height: 1)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    metricTile(title: "Wi-Fi", value: diagnostics.wifiConnected ? "Connected" : "Not active", icon: "wifi")
                    metricTile(title: "Cellular", value: diagnostics.cellularConnected ? "Available path" : "Not in use", icon: "antenna.radiowaves.left.and.right")
                    metricTile(title: "IPv6", value: diagnostics.supportsIPv6 ? "Supported" : "Not reported", icon: "number")
                    metricTile(title: "Data mode", value: diagnostics.isConstrained ? "Low Data Mode" : (diagnostics.isExpensive ? "Metered" : "Standard"), icon: "gauge.with.dots.needle.67percent")
                }

                if !diagnostics.interfaceNames.isEmpty {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("ACTIVE INTERFACES")
                            .font(.system(size: 9, weight: .bold))
                            .tracking(1.2)
                            .foregroundStyle(.white.opacity(0.4))
                        Text(diagnostics.interfaceNames.joined(separator: "  ·  "))
                            .font(.system(size: 11, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.62))
                            .textSelection(.enabled)
                    }
                }
            }
        }
    }

    private var localAccessCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 13) {
                HStack(spacing: 9) {
                    Image(systemName: "lock.shield")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accent2)
                    Text("Local Network access")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                }

                Text("iOS controls whether FrozenApps can discover devices on your network. Start a scan to trigger the system permission prompt when access has not been decided yet.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.56))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    diagnostics.startDiscovery()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: diagnostics.isBrowsing ? "dot.radiowaves.left.and.right" : "shield.lefthalf.filled")
                        Text(diagnostics.isBrowsing ? "Checking nearby devices…" : "Check pairing access")
                        Spacer()
                        if diagnostics.isBrowsing {
                            ProgressView().tint(.white).controlSize(.small)
                        } else {
                            Image(systemName: "arrow.right")
                        }
                    }
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(14)
                    .frame(maxWidth: .infinity)
                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                }
                .buttonStyle(.plain)
                .disabled(diagnostics.isBrowsing)

                Button {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        openURL(url)
                    }
                } label: {
                    Label("Open FrozenApps settings", systemImage: "arrow.up.right.square")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Theme.accent2)
                }
                .buttonStyle(.plain)

                Text(diagnostics.accessMessage)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(diagnostics.accessFailed ? .orange : .white.opacity(0.54))
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 1)
            }
        }
    }

    private var discoveryCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 9) {
                    Image(systemName: "dot.radiowaves.left.and.right")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accent)
                    Text("Nearby services")
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                    Spacer()
                    if diagnostics.isBrowsing {
                        Button("Stop") { diagnostics.stopDiscovery() }
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.orange)
                            .buttonStyle(.plain)
                    }
                }

                if diagnostics.discoveredServices.isEmpty {
                    Text(diagnostics.isBrowsing
                         ? "Searching for local HTTP services. It is normal to find none if your devices do not advertise Bonjour."
                         : "No scan is running yet. Run the access check above to search for nearby HTTP Bonjour services.")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.52))
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.vertical, 4)
                } else {
                    ForEach(Array(diagnostics.discoveredServices.enumerated()), id: \.offset) { _, service in
                        HStack(spacing: 10) {
                            Image(systemName: "server.rack")
                                .foregroundStyle(Theme.accent2)
                            Text(service)
                                .font(.system(size: 12, weight: .medium))
                                .lineLimit(2)
                                .textSelection(.enabled)
                            Spacer(minLength: 0)
                        }
                        .padding(11)
                        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }

                if !diagnostics.localAddresses.isEmpty {
                    Rectangle().fill(.white.opacity(0.08)).frame(height: 1)
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("LOCAL IPv4")
                                .font(.system(size: 9, weight: .bold))
                                .tracking(1.2)
                                .foregroundStyle(.white.opacity(0.4))
                            ForEach(diagnostics.localAddresses, id: \.self) { address in
                                Text(address)
                                    .font(.system(size: 12, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.78))
                                    .textSelection(.enabled)
                            }
                        }
                        Spacer()
                        Button {
                            UIPasteboard.general.string = diagnostics.localAddresses.joined(separator: "\n")
                        } label: {
                            Image(systemName: "doc.on.doc")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundStyle(Theme.accent2)
                                .padding(9)
                                .background(Theme.accent2.opacity(0.12), in: RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Copy local IP addresses")
                    }
                }
            }
        }
    }

    private var privacyNote: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "hand.raised")
                .foregroundStyle(Theme.accent2)
            VStack(alignment: .leading, spacing: 5) {
                Text("Privacy first")
                    .font(.system(size: 13, weight: .semibold))
                Text("This screen reads the system network path and searches only for local HTTP Bonjour services. It does not upload your IP address or scan arbitrary ports. Pairing and LocalDevVPN requirements still depend on your iPadOS version.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.48))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frozenGlassSurface(cornerRadius: 17, tint: Theme.accent2.opacity(0.20))
    }

    private func metricTile(title: String, value: String, icon: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: icon)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.white.opacity(0.47))
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(12)
        .frozenGlassSurface(cornerRadius: 15, tint: Theme.accent.opacity(0.18))
    }
}

@MainActor
private final class FrozenNetworkDiagnostics: ObservableObject {
    @Published private(set) var pathStatus = "Checking network…"
    @Published private(set) var interfaceDescription = "Waiting for system status"
    @Published private(set) var interfaceNames: [String] = []
    @Published private(set) var isConnected = false
    @Published private(set) var wifiConnected = false
    @Published private(set) var cellularConnected = false
    @Published private(set) var supportsIPv6 = false
    @Published private(set) var isExpensive = false
    @Published private(set) var isConstrained = false
    @Published private(set) var localAddresses: [String] = []
    @Published private(set) var accessMessage = "Not checked yet. iOS may ask for Local Network permission when you start a scan."
    @Published private(set) var accessFailed = false
    @Published private(set) var discoveredServices: [String] = []
    @Published private(set) var isBrowsing = false

    private let pathMonitor = NWPathMonitor()
    private let pathQueue = DispatchQueue(label: "com.itzmnyzzz.frozenapps.network-path")
    private let browseQueue = DispatchQueue(label: "com.itzmnyzzz.frozenapps.network-browser")
    private var browser: NWBrowser?

    init() {
        pathMonitor.pathUpdateHandler = { [weak self] path in
            let connected = path.status == .satisfied
            let wifi = path.usesInterfaceType(.wifi)
            let cellular = path.usesInterfaceType(.cellular)
            let wired = path.usesInterfaceType(.wiredEthernet)
            let pathText: String
            switch path.status {
            case .satisfied: pathText = "Network connected"
            case .requiresConnection: pathText = "Connection required"
            case .unsatisfied: pathText = "No network route"
            @unknown default: pathText = "Network status unknown"
            }
            let interfaceText: String
            if wifi { interfaceText = "Wi-Fi is the active route" }
            else if cellular { interfaceText = "Cellular is the active route" }
            else if wired { interfaceText = "Wired Ethernet is the active route" }
            else if connected { interfaceText = "A network route is available" }
            else { interfaceText = "Connect to Wi-Fi to use local pairing workflows" }
            let names = path.availableInterfaces.map(\.name).sorted()
            let ipv6 = path.supportsIPv6
            let expensive = path.isExpensive
            let constrained = path.isConstrained

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.isConnected = connected
                self.wifiConnected = wifi
                self.cellularConnected = cellular
                self.pathStatus = pathText
                self.interfaceDescription = interfaceText
                self.interfaceNames = names
                self.supportsIPv6 = ipv6
                self.isExpensive = expensive
                self.isConstrained = constrained
                self.refreshAddresses()
            }
        }
        pathMonitor.start(queue: pathQueue)
        refreshAddresses()
    }

    func refresh() {
        refreshAddresses()
    }

    func startDiscovery() {
        browser?.cancel()
        discoveredServices = []
        accessFailed = false
        accessMessage = "Starting a local Bonjour browse. Accept or review the iOS permission prompt if it appears."
        isBrowsing = true

        let parameters = NWParameters.tcp
        parameters.includePeerToPeer = true
        let nextBrowser = NWBrowser(
            for: .bonjour(type: "_http._tcp", domain: nil),
            using: parameters
        )

        nextBrowser.browseResultsChangedHandler = { [weak self] results, _ in
            let labels = results.map { result -> String in
                switch result.endpoint {
                case .service(let name, let type, let domain, _):
                    return "\(name) · \(type) · \(domain)"
                default:
                    return String(describing: result.endpoint)
                }
            }.sorted()

            Task { @MainActor [weak self] in
                guard let self else { return }
                self.discoveredServices = Array(labels.prefix(12))
                if !labels.isEmpty {
                    self.accessMessage = "Discovery is active. Nearby services are visible to FrozenApps."
                    self.accessFailed = false
                }
            }
        }

        nextBrowser.stateUpdateHandler = { [weak self] state in
            let message: String?
            let active: Bool?
            let failed: Bool?
            switch state {
            case .ready:
                message = "Local Network browsing is active. You can leave this running while you check nearby services."
                active = true
                failed = false
            case .waiting(let error):
                message = "Waiting for network access: \(error.localizedDescription)"
                active = true
                failed = false
            case .failed(let error):
                message = "The local browse failed: \(error.localizedDescription). Check Settings → Privacy & Security → Local Network."
                active = false
                failed = true
            case .cancelled:
                message = "Local discovery stopped."
                active = false
                failed = false
            default:
                message = nil
                active = nil
                failed = nil
            }
            guard let message, let active, let failed else { return }
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.accessMessage = message
                self.isBrowsing = active
                self.accessFailed = failed
            }
        }

        browser = nextBrowser
        nextBrowser.start(queue: browseQueue)
    }

    func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isBrowsing = false
        accessMessage = "Local discovery stopped. Your system network connection is unchanged."
    }

    func refreshAddresses() {
        localAddresses = Self.ipv4Addresses()
    }

    private static func ipv4Addresses() -> [String] {
        var first: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&first) == 0, let head = first else { return [] }
        defer { freeifaddrs(head) }

        var cursor: UnsafeMutablePointer<ifaddrs>? = head
        var results: [String] = []
        while let current = cursor {
            let item = current.pointee
            cursor = item.ifa_next
            guard let address = item.ifa_addr,
                  address.pointee.sa_family == sa_family_t(AF_INET),
                  let interfaceName = String(validatingUTF8: item.ifa_name),
                  interfaceName.hasPrefix("en") else { continue }

            var host = [CChar](repeating: 0, count: Int(NI_MAXHOST))
            let code = host.withUnsafeMutableBufferPointer { buffer in
                getnameinfo(
                    address,
                    socklen_t(address.pointee.sa_len),
                    buffer.baseAddress!,
                    socklen_t(buffer.count),
                    nil,
                    0,
                    NI_NUMERICHOST
                )
            }
            if code == 0 {
                results.append("\(interfaceName): \(String(cString: host))")
            }
        }
        return Array(Set(results)).sorted()
    }
}
