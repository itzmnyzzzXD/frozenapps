import Foundation
import SwiftUI
import UIKit
import UserNotifications

private struct FrozenStatusAsset: Decodable { let name: String }
private struct FrozenStatusRelease: Decodable {
    let tag_name: String
    let html_url: String
    let assets: [FrozenStatusAsset]
}
private struct FrozenStatusRun: Decodable {
    let status: String
    let conclusion: String?
    let html_url: String
}
private struct FrozenStatusRuns: Decodable { let workflow_runs: [FrozenStatusRun] }

private struct FrozenRemoteSnapshot {
    var releaseTag: String?
    var releaseURL: URL?
    var hasIPA = false
    var workflowStatus: String?
    var workflowConclusion: String?
    var workflowURL: URL?
    var releaseError: String?
    var workflowError: String?
    var checkedAt = Date()
}

private enum FrozenRemoteStatusService {
    static func snapshot() async -> FrozenRemoteSnapshot {
        var output = FrozenRemoteSnapshot()
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/itzmnyzzzXD/frozenapps/releases/latest")!)
            request.timeoutInterval = 10
            request.setValue("FrozenApps Status", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let release = try JSONDecoder().decode(FrozenStatusRelease.self, from: data)
            output.releaseTag = release.tag_name
            output.releaseURL = URL(string: release.html_url)
            output.hasIPA = release.assets.contains { $0.name == "FrozenApps-unsigned.ipa" }
        } catch { output.releaseError = error.localizedDescription }

        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/itzmnyzzzXD/frozenapps/actions/runs?branch=main&per_page=1")!)
            request.timeoutInterval = 10
            request.setValue("FrozenApps Status", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let runs = try JSONDecoder().decode(FrozenStatusRuns.self, from: data)
            if let run = runs.workflow_runs.first {
                output.workflowStatus = run.status
                output.workflowConclusion = run.conclusion
                output.workflowURL = URL(string: run.html_url)
            } else {
                output.workflowError = "GitHub returned no workflow runs."
            }
        } catch { output.workflowError = error.localizedDescription }

        output.checkedAt = Date()
        return output
    }

    static func checkHelper(_ rawURL: String) async -> (Bool, String) {
        guard let root = URL(string: rawURL.trimmingCharacters(in: .whitespacesAndNewlines)),
              ["http", "https"].contains(root.scheme?.lowercased() ?? ""),
              root.host != nil, root.query == nil, root.fragment == nil else {
            return (false, "No compatible helper address is configured.")
        }
        var request = URLRequest(url: root.appendingPathComponent("ver"),
                                 cachePolicy: .reloadIgnoringLocalCacheData,
                                 timeoutInterval: 5)
        request.setValue("FrozenApps", forHTTPHeaderField: "User-Agent")
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { return (false, "No HTTP response from helper.") }
            let success = (200..<300).contains(http.statusCode)
            return (success, success ? "Helper responded to its version endpoint." : "Helper returned HTTP \(http.statusCode).")
        } catch { return (false, "Helper unreachable: \(error.localizedDescription)") }
    }
}

private struct FrozenCenterToolCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let tint: Color

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.system(size: 17, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 38, height: 38).background(tint.opacity(0.13), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.53))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.35)).padding(.top, 4)
        }
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .padding(13)
        .frozenGlassSurface(cornerRadius: 17, tint: tint.opacity(0.30))
        .contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
    }
}

struct FrozenControlCenterView: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack(spacing: 12) {
                                ZStack {
                                    RoundedRectangle(cornerRadius: 19, style: .continuous).fill(Theme.brand)
                                    Circle().strokeBorder(.white.opacity(0.18), lineWidth: 1).padding(6)
                                    Image(systemName: "snowflake").font(.system(size: 27, weight: .semibold)).foregroundStyle(.white)
                                }
                                .frame(width: 62, height: 62)
                                .shadow(color: Theme.accent.opacity(0.3), radius: 12, y: 4)
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("FROZENAPPS · CONTROL CENTER")
                                        .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                    Text("Your toolkit. One place.")
                                        .font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                }
                            }
                            Text("Browse app sources, preflight multiple IPAs, inspect signing material, monitor installs and diagnose pairing.")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.62))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(17)
                        .frozenGlassSurface(cornerRadius: 25, tint: Theme.accent, elevated: true)
                        PanelCard {
                            HStack(spacing: 12) {
                                Image(systemName: engine.isRunning ? "arrow.trianglehead.2.clockwise.rotate.90" : (engine.lastError != nil ? "exclamationmark.triangle.fill" : "checkmark.circle.fill"))
                                    .font(.system(size: 20, weight: .semibold))
                                    .foregroundStyle(engine.isRunning ? Theme.accent2 : (engine.lastError != nil ? .orange : .green))
                                    .frame(width: 43, height: 43).background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(engine.isRunning ? "Install pipeline active" : (engine.lastError != nil ? "Last operation failed" : (engine.finished ? "Last operation completed" : "Ready for a task")))
                                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    Text("The tracker reads real engine state and logs; it does not invent percentages.")
                                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                                }
                                Spacer(minLength: 0)
                            }
                        }
                        LazyVGrid(
                            columns: Array(
                                repeating: GridItem(.flexible(), spacing: 12),
                                count: horizontalSizeClass == .regular ? 3 : 2
                            ),
                            spacing: 12
                        ) {
                            NavigationLink { FrozenCertificateHealthView() } label: {
                                FrozenCenterToolCard(title: "Certificate Health", subtitle: "Expiry & profile check", icon: "checkmark.shield.fill", tint: .green)
                            }
                            NavigationLink { FrozenJITView() } label: {
                                FrozenCenterToolCard(title: "JIT Center", subtitle: "Pair & request JIT", icon: "bolt.fill", tint: Theme.accent2)
                            }
                            NavigationLink { FrozenInstallationTrackerView() } label: {
                                FrozenCenterToolCard(title: "Install Tracker", subtitle: "Live steps & engine logs", icon: "chart.bar.xaxis", tint: .cyan)
                            }
                            NavigationLink { FrozenFilesView() } label: {
                                FrozenCenterToolCard(title: "IPA Library", subtitle: "Search, inspect & hash", icon: "shippingbox.fill", tint: .purple)
                            }
                            NavigationLink { FrozenDeviceCenterView() } label: {
                                FrozenCenterToolCard(title: "Device Center", subtitle: "Connection recovery & reports", icon: "iphone.gen3.radiowaves.left.and.right", tint: .orange)
                            }
                            NavigationLink { FrozenNetworkView() } label: {
                                FrozenCenterToolCard(title: "Pairing & Network", subtitle: "Network & discovery tools", icon: "point.3.connected.trianglepath.dotted", tint: .yellow)
                            }
                            NavigationLink { FrozenSmartAlertsView() } label: {
                                FrozenCenterToolCard(title: "Smart Alerts", subtitle: "Expiry & failure warnings", icon: "bell.badge.fill", tint: .orange)
                            }
                            NavigationLink { FrozenStatusView() } label: {
                                FrozenCenterToolCard(title: "Frozen Status", subtitle: "Release & CI health", icon: "waveform.path.ecg", tint: .mint)
                            }
                            NavigationLink { FrozenSetupGuideView() } label: {
                                FrozenCenterToolCard(title: "Setup Guide", subtitle: "Interactive checklist", icon: "list.number", tint: .pink)
                            }
                            NavigationLink { FrozenAppCatalogView() } label: {
                                FrozenCenterToolCard(title: "App Catalog", subtitle: "GitHub sources & IPA releases", icon: "square.grid.2x2.fill", tint: .indigo)
                            }
                            NavigationLink { FrozenBatchActionsView() } label: {
                                FrozenCenterToolCard(title: "Batch Actions", subtitle: "Multi-IPA preflight & queues", icon: "checklist", tint: .teal)
                            }
                        }
                        Text("Signing, JIT and installation depend on iOS restrictions, device pairing, a compatible helper and valid signing material.")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.43))
                    }
                    .padding(20).frame(maxWidth: 680).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Frozen Center")
            .navigationBarTitleDisplayMode(.inline)
        }
        .preferredColorScheme(.dark)
    }
}

struct FrozenInstallationTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var engine: Engine

    private var activeStep: Step? {
        for step in Step.allCases {
            guard let state = engine.stepStates[step] else { continue }
            switch state {
            case .active, .waiting: return step
            case .pending, .done, .failed: continue
            }
        }
        return nil
    }

    private var headline: String {
        if engine.isRunning { return activeStep?.title(for: engine.installSource) ?? "Pipeline running" }
        if engine.lastError != nil { return "Last operation failed" }
        if engine.finished { return "Last operation completed" }
        return "No active installation"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 11) {
                                Label("LIVE ENGINE STATE", systemImage: "waveform.path")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                Text(headline).font(.system(size: 22, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                if engine.isRunning {
                                    if activeStep == .install {
                                        ProgressView(value: min(max(engine.installProgress, 0), 1)).tint(Theme.accent2)
                                        Text("\(Int(min(max(engine.installProgress, 0), 1) * 100))% — native installation progress")
                                            .font(.system(size: 11, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(.white.opacity(0.62))
                                    } else {
                                        ProgressView().tint(Theme.accent2)
                                        Text("This stage does not report a reliable percentage, so none is displayed.")
                                            .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                                    }
                                } else if let error = engine.lastError {
                                    Text(error).font(.system(size: 11)).foregroundStyle(.orange).textSelection(.enabled)
                                } else {
                                    Text("Start an install from Signer to see the pipeline live.")
                                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                                }
                            }
                        }
                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("PIPELINE STEPS").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                ForEach(Step.allCases) { step in
                                    stepRow(step)
                                    if step != Step.allCases.last { Divider().overlay(.white.opacity(0.05)) }
                                }
                            }
                        }
                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Label("Recent engine log", systemImage: "text.alignleft")
                                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    Spacer()
                                    Text("\(engine.lines.count) entries").font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
                                }
                                if engine.lines.isEmpty {
                                    Text("No log entries yet.").font(.system(size: 11)).foregroundStyle(.white.opacity(0.5))
                                } else {
                                    ForEach(Array(engine.lines.suffix(12))) { entry in
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(entry.stamp).font(.system(size: 9, design: .monospaced)).foregroundStyle(.white.opacity(0.35))
                                            Text(entry.text).font(.system(size: 10, design: .monospaced)).foregroundStyle(.white.opacity(0.72))
                                                .textSelection(.enabled).fixedSize(horizontal: false, vertical: true)
                                        }.frame(maxWidth: .infinity, alignment: .leading).padding(.vertical, 3)
                                    }
                                }
                            }
                        }
                        Text("Review logs for private identifiers, pairing details and account information before sharing them.")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.44))
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Install Tracker")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func stepRow(_ step: Step) -> some View {
        let state = engine.stepStates[step] ?? .pending
        let title: String
        let symbol: String
        let tint: Color
        switch state {
        case .pending: title = "Waiting"; symbol = "circle"; tint = .white.opacity(0.35)
        case .active: title = "Active"; symbol = "arrow.trianglehead.2.clockwise.rotate.90"; tint = Theme.accent2
        case .waiting: title = "Needs your input"; symbol = "hand.tap.fill"; tint = .orange
        case .done: title = "Completed"; symbol = "checkmark.circle.fill"; tint = .green
        case .failed: title = "Failed"; symbol = "xmark.circle.fill"; tint = .red
        }
        return HStack(spacing: 10) {
            Image(systemName: symbol).font(.system(size: 12, weight: .semibold)).foregroundStyle(tint).frame(width: 18)
            VStack(alignment: .leading, spacing: 3) {
                Text(step.title(for: engine.installSource)).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                Text(title).font(.system(size: 10, weight: .medium)).foregroundStyle(tint)
            }
            Spacer()
        }
    }
}

struct FrozenStatusView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("frozenApps.jit.helperURL") private var helperURL = ""
    @State private var status = FrozenRemoteSnapshot()
    @State private var helperStatus = "Not checked"
    @State private var isRefreshing = false

    private var installedVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "Unknown"
    }
    private var workflowState: String {
        guard let state = status.workflowStatus else { return "Unavailable" }
        return state == "completed" ? (status.workflowConclusion?.capitalized ?? "Completed") : "Running"
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 11) {
                                HStack {
                                    Label("SERVICE STATUS", systemImage: "waveform.path.ecg")
                                        .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                    Spacer()
                                    if isRefreshing { ProgressView().tint(Theme.accent2) }
                                    else { Button("Refresh") { Task { await refresh() } }.font(.system(size: 11, weight: .semibold)) }
                                }
                                statusRow("GitHub Releases", status.releaseTag == nil ? "Unavailable" : "Reachable", status.releaseTag != nil)
                                statusRow("Unsigned IPA asset", status.releaseTag == nil ? "Not checked" : (status.hasIPA ? "Published" : "Missing"), status.hasIPA)
                                statusRow("Latest main build", workflowState, status.workflowConclusion == "success")
                                statusRow("JIT helper", helperStatus, helperStatus == "Reachable")
                                if let tag = status.releaseTag {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 3) {
                                            Text("Latest release").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                                            Text(tag).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                        }
                                        Spacer()
                                        if let url = status.releaseURL { Link("Open release", destination: url).font(.system(size: 11, weight: .semibold)) }
                                    }
                                }
                                if let url = status.workflowURL { Link("Open main build", destination: url).font(.system(size: 11, weight: .semibold)) }
                                if let message = status.releaseError { Text("Release check: \(message)").font(.system(size: 10)).foregroundStyle(.orange) }
                                if let message = status.workflowError { Text("Build check: \(message)").font(.system(size: 10)).foregroundStyle(.orange) }
                                Text("Last checked: \(status.checkedAt.formatted(date: .abbreviated, time: .shortened))")
                                    .font(.system(size: 9)).foregroundStyle(.white.opacity(0.4))
                            }
                        }
                        PanelCard {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("VERSION CHECK").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                statusRow("Installed app", installedVersion, true)
                                if let latest = status.releaseTag {
                                    let normalized = latest.hasPrefix("v") ? String(latest.dropFirst()) : latest
                                    statusRow("Latest release", normalized, normalized == installedVersion)
                                    if normalized != installedVersion {
                                        Text("A different version exists. Review release notes and compatibility before updating.")
                                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                                    }
                                }
                            }
                        }
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Frozen Status")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task { await refresh() }
        }
        .preferredColorScheme(.dark)
    }

    private func statusRow(_ title: String, _ value: String, _ healthy: Bool) -> some View {
        HStack {
            Text(title).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.64))
            Spacer(minLength: 8)
            Text(value).font(.system(size: 10, weight: .semibold)).foregroundStyle(healthy ? .green : .orange).multilineTextAlignment(.trailing)
        }
    }

    @MainActor private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        status = await FrozenRemoteStatusService.snapshot()
        helperStatus = (await FrozenRemoteStatusService.checkHelper(helperURL)).0 ? "Reachable" : "Not reachable"
    }
}

struct FrozenSmartAlertsView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var engine: Engine
    @AppStorage("frozenApps.profileHealth.expiration") private var profileExpiry = 0.0
    @AppStorage("frozenApps.certificateHealth.expiration") private var certificateExpiry = 0.0
    @AppStorage("frozenApps.jit.helperURL") private var helperURL = ""
    @State private var latestBuildFailed = false
    @State private var helperAvailable: Bool?
    @State private var message: String?

    private var expiries: [(String, Date)] {
        var items: [(String, Date)] = []
        if profileExpiry > 0 { items.append(("Provisioning profile", Date(timeIntervalSince1970: profileExpiry))) }
        if certificateExpiry > 0 { items.append(("Signing certificate", Date(timeIntervalSince1970: certificateExpiry))) }
        return items
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 11) {
                                Label("ATTENTION NEEDED", systemImage: "bell.badge.fill")
                                    .font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                if let failure = engine.lastError {
                                    alertRow("Last signing or installation failure", failure, "xmark.octagon.fill", .red)
                                }
                                if expiries.isEmpty {
                                    alertRow("No expiry data yet", "Inspect a profile and certificate in Certificate Health to enable local warnings.", "calendar.badge.clock", .white.opacity(0.55))
                                } else {
                                    ForEach(Array(expiries.enumerated()), id: \.offset) { _, item in
                                        let days = Calendar.current.dateComponents([.day], from: Date(), to: item.1).day ?? 0
                                        let tint: Color = days < 0 ? .red : (days <= 7 ? .orange : .green)
                                        let detail = days < 0 ? "Expired \(abs(days)) day(s) ago" : (days <= 7 ? "Expires in about \(max(days, 0)) day(s)" : "Expires \(item.1.formatted(date: .abbreviated, time: .omitted))")
                                        alertRow(item.0, detail, days <= 7 ? "exclamationmark.triangle.fill" : "calendar", tint)
                                    }
                                }
                                if latestBuildFailed {
                                    alertRow("Latest main build failed", "Open Frozen Status to review the workflow run.", "hammer.fill", .red)
                                }
                                if let helperAvailable, !helperAvailable {
                                    alertRow("JIT helper disconnected", "Check its address, network connection and pairing.", "network.slash", .orange)
                                } else if helperURL.isEmpty {
                                    alertRow("JIT helper not configured", "Add a compatible helper address in JIT Center to enable checks.", "network", .white.opacity(0.55))
                                }
                                if engine.lastError == nil && expiries.allSatisfy({ $0.1.timeIntervalSinceNow > 7 * 86400 }) && !latestBuildFailed {
                                    Text("No urgent warnings found in the information currently available.")
                                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.green)
                                }
                            }
                        }
                        PanelCard {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("LOCAL EXPIRY REMINDERS").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                Text("Schedules 30-, 7- and 1-day reminders for inspected items. Build and helper status are checked when this page opens; they are not background-monitored.")
                                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                                Button("Enable expiry reminders") { scheduleReminders() }
                                    .font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                                    .frame(maxWidth: .infinity).padding(12).background(Theme.accent2, in: RoundedRectangle(cornerRadius: 12))
                                    .buttonStyle(.plain)
                                if let message { Text(message).font(.system(size: 10)).foregroundStyle(.white.opacity(0.65)) }
                            }
                        }
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Smart Alerts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
            .task {
                let remote = await FrozenRemoteStatusService.snapshot()
                latestBuildFailed = remote.workflowConclusion == "failure"
                helperAvailable = (await FrozenRemoteStatusService.checkHelper(helperURL)).0
            }
        }
        .preferredColorScheme(.dark)
    }

    private func alertRow(_ title: String, _ detail: String, _ icon: String, _ tint: Color) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).foregroundStyle(tint).frame(width: 17).padding(.top, 2)
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                Text(detail).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func scheduleReminders() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                guard granted else {
                    message = error?.localizedDescription ?? "Notifications not allowed. Enable them in iPad Settings."
                    return
                }
                var count = 0
                for (title, expiry) in expiries {
                    for days in [30, 7, 1] {
                        let interval = expiry.timeIntervalSinceNow - Double(days) * 86400
                        guard interval > 60 else { continue }
                        let content = UNMutableNotificationContent()
                        content.title = "FrozenApps expiry reminder"
                        content.body = "\(title) expires in about \(days) day(s). Open Certificate Health to review it."
                        content.sound = .default
                        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false)
                        let request = UNNotificationRequest(identifier: "frozen-expiry-\(title)-\(days)-\(Int(expiry.timeIntervalSince1970))", content: content, trigger: trigger)
                        UNUserNotificationCenter.current().add(request) { _ in }
                        count += 1
                    }
                }
                message = count == 0 ? "No future expiry reminders were needed." : "Scheduled \(count) local reminder(s)."
            }
        }
    }
}

struct FrozenSetupGuideView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @AppStorage("frozenApps.setup.networkConfirmed") private var networkDone = false
    @AppStorage("frozenApps.setup.developerModeConfirmed") private var developerModeDone = false
    @AppStorage("frozenApps.setup.pairingConfirmed") private var pairingDone = false
    @AppStorage("frozenApps.setup.signingMaterialConfirmed") private var signingDone = false

    private var completeCount: Int { [networkDone, developerModeDone, pairingDone, signingDone].filter { $0 }.count }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("LET'S GET READY").font(.system(size: 10, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                Text("Device setup checklist").font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                Text("iOS/iPadOS \(UIDevice.current.systemVersion) detected.")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                                ProgressView(value: Double(completeCount), total: 4).tint(Theme.accent2)
                                Text("\(completeCount) of 4 checks confirmed").font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.65))
                            }
                        }
                        checklist("Allow Local Network access", "Open Network and start discovery. iOS may ask for permission; review it in Settings.", "wifi", $networkDone)
                        checklist("Review Developer Mode", "Confirm it yourself if the chosen signing method requires it. FrozenApps cannot enable it for you.", "hammer.fill", $developerModeDone)
                        checklist("Complete device pairing", "Finish supported pairing in Signer or your configured helper. Older OS versions may need a pairing file and computer-assisted setup.", "point.3.connected.trianglepath.dotted", $pairingDone)
                        checklist("Inspect signing material", "Use Certificate Health to inspect a certificate/profile and compare its pattern with the intended app bundle ID.", "checkmark.shield.fill", $signingDone)
                        Button { openURL(URL(string: UIApplication.openSettingsURLString)!) } label: {
                            Label("Open FrozenApps Settings", systemImage: "gearshape")
                                .font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity).padding(12)
                                .foregroundStyle(.white).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 12))
                        }.buttonStyle(.plain)
                        Text("These are user confirmations, not hidden system checks. OS support, pairing, helper compatibility and signing limits still determine what works.")
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Setup Guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    private func checklist(_ title: String, _ detail: String, _ icon: String, _ checked: Binding<Bool>) -> some View {
        PanelCard {
            Toggle(isOn: checked) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: icon).foregroundStyle(Theme.accent2).frame(width: 19).padding(.top, 2)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(title).font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                        Text(detail).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.54)).fixedSize(horizontal: false, vertical: true)
                    }
                }
            }.tint(Theme.accent2)
        }
    }
}
