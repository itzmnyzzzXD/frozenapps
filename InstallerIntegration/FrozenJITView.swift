import Foundation
import SwiftUI

private struct FrozenJITDevice: Identifiable, Hashable {
    let name: String
    let udid: String
    var id: String { udid }
}

private struct FrozenJITApp: Identifiable, Hashable {
    let name: String
    let bundle: String
    let pid: Int
    var id: String { bundle }
}

private enum FrozenJITError: LocalizedError {
    case invalidURL
    case invalidResponse
    case helper(String)
    case noDevice
    case noEligibleApps

    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Enter the local address of a compatible JIT helper, for example http://192.168.1.20:8080."
        case .invalidResponse:
            return "The helper returned an unexpected response. Check that this is a compatible JIT helper."
        case .helper(let message):
            return message
        case .noDevice:
            return "The helper is online, but it did not report a paired device. Pair the iPad with the helper first."
        case .noEligibleApps:
            return "The helper did not find any apps eligible for JIT. The app generally needs the get-task-allow entitlement."
        }
    }
}

/// A client for a compatible companion JIT helper. This view never pretends the
/// app can grant JIT on its own: the helper must already be paired with the iPad.
struct FrozenJITView: View {
    @AppStorage("frozenApps.jit.helperURL") private var helperURL = ""

    @State private var devices: [FrozenJITDevice] = []
    @State private var apps: [FrozenJITApp] = []
    @State private var selectedUDID = ""
    @State private var selectedBundle = ""
    @State private var helperVersion = ""
    @State private var isWorking = false
    @State private var resultMessage: String?
    @State private var resultIsSuccess = false

    private var selectedApp: FrozenJITApp? {
        apps.first { $0.bundle == selectedBundle }
    }

    var body: some View {
        ZStack {
            FrozenWorkspaceBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    hero
                    helperCard
                    if !devices.isEmpty {
                        deviceCard
                    }
                    if !apps.isEmpty {
                        appCard
                    }
                    if let resultMessage {
                        resultCard(resultMessage, success: resultIsSuccess)
                    }
                    requirementsCard
                    companionLink
                }
                .padding(20)
                .frame(maxWidth: 560)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("JIT Center")
        .navigationBarTitleDisplayMode(.inline)
        .preferredColorScheme(.dark)
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 21, style: .continuous)
                        .fill(Theme.brand)
                    Circle().strokeBorder(.white.opacity(0.2), lineWidth: 1).padding(6)
                    Image(systemName: "bolt.fill")
                        .font(.system(size: 27, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 66, height: 66)
                .shadow(color: Theme.accent.opacity(0.3), radius: 16, x: 0, y: 7)

                VStack(alignment: .leading, spacing: 5) {
                    Text("FROZENAPPS · DEVELOPER TOOLS")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.3)
                        .foregroundStyle(Theme.accent2)
                    Text("JIT Center")
                        .font(.system(size: 27, weight: .bold, design: .rounded))
                        .tracking(-0.5)
                        .foregroundStyle(.white)
                    Text("Connect to a paired helper to request JIT for supported apps.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }

            HStack(spacing: 7) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(Theme.accent2)
                Text("JIT needs a compatible helper. A switch inside FrozenApps alone cannot unlock it.")
                    .foregroundStyle(.white.opacity(0.68))
            }
            .font(.system(size: 11, weight: .medium))
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.accent.opacity(0.09), in: RoundedRectangle(cornerRadius: 14))
            .overlay {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(Theme.accent.opacity(0.22), lineWidth: 1)
            }
        }
    }

    private var helperCard: some View {
        FrozenWorkspacePanel {
            VStack(alignment: .leading, spacing: 13) {
                Label("Companion helper", systemImage: "network")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Enter the local address shown by a compatible JIT helper. The helper and iPad must be on a trusted network, and the helper must already be paired with this iPad.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)

                TextField("http://192.168.1.20:8080", text: $helperURL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.URL)
                    .font(.system(size: 13, weight: .medium, design: .monospaced))
                    .foregroundStyle(.white)
                    .padding(13)
                    .background(.black.opacity(0.24), in: RoundedRectangle(cornerRadius: 13))
                    .overlay {
                        RoundedRectangle(cornerRadius: 13)
                            .strokeBorder(.white.opacity(0.1), lineWidth: 1)
                    }

                Button {
                    Task { await connectAndDiscover() }
                } label: {
                    HStack(spacing: 9) {
                        if isWorking { ProgressView().tint(.white) }
                        else { Image(systemName: "dot.radiowaves.left.and.right") }
                        Text(isWorking ? "Connecting…" : "Connect & find devices")
                        Spacer()
                        Image(systemName: "arrow.right")
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking || helperURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                if !helperVersion.isEmpty {
                    Label("Helper version \(helperVersion)", systemImage: "checkmark.seal.fill")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.green)
                }
            }
        }
    }

    private var deviceCard: some View {
        FrozenWorkspacePanel {
            VStack(alignment: .leading, spacing: 12) {
                Label("Paired device", systemImage: "ipad.and.iphone")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Picker("Device", selection: $selectedUDID) {
                    ForEach(devices) { device in
                        Text("\(device.name) · \(device.udid.prefix(8))").tag(device.udid)
                    }
                }
                .pickerStyle(.menu)
                .tint(Theme.accent2)
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .frozenGlassSurface(cornerRadius: 14, tint: Theme.accent.opacity(0.18))

                Button {
                    Task { await refreshApps() }
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh JIT-capable apps")
                        Spacer()
                        Image(systemName: "chevron.right")
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
                    .padding(12)
                    .background(Theme.accent.opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
                }
                .buttonStyle(.plain)
                .disabled(isWorking || selectedUDID.isEmpty)
            }
        }
    }

    private var appCard: some View {
        FrozenWorkspacePanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label("Eligible apps", systemImage: "app.badge.checkmark")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Text("\(apps.count)")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.accent2)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.12), in: Capsule())
                }

                ForEach(apps) { app in
                    Button {
                        selectedBundle = app.bundle
                        resultMessage = nil
                    } label: {
                        HStack(spacing: 11) {
                            Image(systemName: "app.fill")
                                .font(.system(size: 16, weight: .medium))
                                .foregroundStyle(Theme.accent2)
                                .frame(width: 39, height: 39)
                                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                            VStack(alignment: .leading, spacing: 3) {
                                Text(app.name)
                                    .font(.system(size: 13, weight: .semibold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                Text(app.bundle)
                                    .font(.system(size: 10, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.45))
                                    .lineLimit(1)
                            }
                            Spacer(minLength: 5)
                            Image(systemName: app.bundle == selectedBundle ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(app.bundle == selectedBundle ? Theme.accent2 : .white.opacity(0.25))
                        }
                        .padding(10)
                        .frozenGlassSurface(
                            cornerRadius: 15,
                            tint: app.bundle == selectedBundle ? Theme.accent2 : Theme.accent.opacity(0.12),
                            elevated: app.bundle == selectedBundle
                        )
                        .animation(.spring(response: 0.25, dampingFraction: 0.80), value: selectedBundle)
                    }
                    .buttonStyle(.plain)
                }

                Button {
                    Task { await enableJIT() }
                } label: {
                    HStack(spacing: 9) {
                        if isWorking { ProgressView().tint(.white) }
                        else { Image(systemName: "bolt.fill") }
                        Text(isWorking ? "Requesting JIT…" : "Enable JIT for selected app")
                        Spacer()
                    }
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                }
                .buttonStyle(PrimaryButtonStyle())
                .disabled(isWorking || selectedApp == nil || selectedUDID.isEmpty)
            }
        }
    }

    private var requirementsCard: some View {
        FrozenWorkspacePanel {
            VStack(alignment: .leading, spacing: 11) {
                Label("Before using JIT", systemImage: "checklist")
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                requirementRow("The helper is already paired with this iPad.", icon: "link")
                requirementRow("Developer Mode is enabled in Settings → Privacy & Security.", icon: "switch.2")
                requirementRow("The app is JIT-capable and appears in the helper's eligible-app list.", icon: "app.badge.checkmark")
                Text("JIT may stop when an app exits, the device restarts, or the helper session ends. FrozenApps does not bypass Apple's security controls.")
                    .font(.system(size: 11))
                    .foregroundStyle(.white.opacity(0.5))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var companionLink: some View {
        Link(destination: URL(string: "https://github.com/nythepegasus/SideJITServer")!) {
            HStack(spacing: 11) {
                Image(systemName: "book.closed.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
                    .frame(width: 39, height: 39)
                    .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text("JIT helper setup guide")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    Text("Setup, requirements and troubleshooting")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
                Spacer()
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Theme.accent2)
            }
            .padding(13)
            .background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(.white.opacity(0.08), lineWidth: 1)
            }
        }
    }

    private func requirementRow(_ title: String, icon: String) -> some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(Theme.accent2)
                .frame(width: 16)
                .padding(.top, 2)
            Text(title)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func resultCard(_ message: String, success: Bool) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: success ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(success ? .green : .orange)
            Text(message)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.white.opacity(0.78))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
            Button {
                resultMessage = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
            }
            .buttonStyle(.plain)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background((success ? Color.green : Color.orange).opacity(0.1), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder((success ? Color.green : Color.orange).opacity(0.22), lineWidth: 1)
        }
    }

    @MainActor
    private func connectAndDiscover() async {
        isWorking = true
        resultMessage = nil
        defer { isWorking = false }
        do {
            let version = try await requestJSON(["ver"])
            if let info = version as? [String: Any] {
                helperVersion = info["SideJITServer"] as? String ?? ""
            } else {
                helperVersion = ""
            }

            let payload = try await requestJSON([])
            guard let rawDevices = payload as? [String: Any] else {
                throw FrozenJITError.invalidResponse
            }
            if let helperError = rawDevices["ERROR"] as? String {
                throw FrozenJITError.helper(helperError)
            }
            let loadedDevices = rawDevices.compactMap { name, value -> FrozenJITDevice? in
                guard let udid = value as? String else { return nil }
                return FrozenJITDevice(name: name, udid: udid)
            }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
            guard !loadedDevices.isEmpty else { throw FrozenJITError.noDevice }

            devices = loadedDevices
            if !devices.contains(where: { $0.udid == selectedUDID }) {
                selectedUDID = devices[0].udid
            }
            try await loadApps()
            resultIsSuccess = true
            resultMessage = "Connected to the helper. Select an eligible app to request JIT."
        } catch {
            resultIsSuccess = false
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func refreshApps() async {
        isWorking = true
        resultMessage = nil
        defer { isWorking = false }
        do {
            try await loadApps()
            resultIsSuccess = true
            resultMessage = apps.isEmpty
                ? "The helper responded, but no JIT-capable apps were listed."
                : "Refreshed the eligible-app list."
        } catch {
            resultIsSuccess = false
            resultMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadApps() async throws {
        guard !selectedUDID.isEmpty else { throw FrozenJITError.noDevice }
        let payload = try await requestJSON([selectedUDID])
        guard let rawApps = payload as? [[String: Any]] else {
            if let raw = payload as? [String: Any], let message = raw["ERROR"] as? String {
                throw FrozenJITError.helper(message)
            }
            throw FrozenJITError.invalidResponse
        }
        let loadedApps = rawApps.compactMap { item -> FrozenJITApp? in
            guard let name = item["name"] as? String,
                  let bundle = item["bundle"] as? String else { return nil }
            return FrozenJITApp(name: name, bundle: bundle, pid: item["pid"] as? Int ?? -1)
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
        apps = loadedApps
        if !apps.contains(where: { $0.bundle == selectedBundle }) {
            selectedBundle = apps.first?.bundle ?? ""
        }
    }

    @MainActor
    private func enableJIT() async {
        guard let app = selectedApp, !selectedUDID.isEmpty else { return }
        isWorking = true
        resultMessage = nil
        defer { isWorking = false }
        do {
            let payload = try await requestJSON([selectedUDID, app.bundle])
            let message = (payload as? String)
                ?? ((payload as? [String: Any])?["ERROR"] as? String)
                ?? "The helper returned a response that FrozenApps could not interpret."
            let normalized = message.lowercased()
            resultIsSuccess = normalized.contains("enabled jit")
                || normalized.contains("jit already enabled")
            resultMessage = message
            if !resultIsSuccess {
                resultMessage = message + " If the helper reports an error, verify pairing and Developer Mode."
            }
        } catch {
            resultIsSuccess = false
            resultMessage = error.localizedDescription
        }
    }

    private func requestJSON(_ path: [String]) async throws -> Any {
        let root = try normalizedHelperURL()
        let url = path.reduce(root) { partial, component in
            partial.appendingPathComponent(component)
        }
        var request = URLRequest(url: url,
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 8)
        request.httpMethod = "GET"

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw FrozenJITError.invalidResponse
        }
        let json = try? JSONSerialization.jsonObject(with: data, options: [.fragmentsAllowed])
        guard (200..<300).contains(http.statusCode) else {
            let bodyMessage = (json as? [String: Any])?["ERROR"] as? String
                ?? String(data: data, encoding: .utf8)
                ?? "No error details returned."
            throw FrozenJITError.helper("Helper returned HTTP \(http.statusCode): \(bodyMessage)")
        }
        guard let json else { throw FrozenJITError.invalidResponse }
        return json
    }

    private func normalizedHelperURL() throws -> URL {
        guard let parts = URLComponents(string: helperURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = parts.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              parts.host != nil,
              parts.query == nil,
              parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/",
              let url = parts.url else {
            throw FrozenJITError.invalidURL
        }
        return url
    }
}
