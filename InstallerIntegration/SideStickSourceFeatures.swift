import CryptoKit
import Foundation
import SwiftUI
import UIKit
import UserNotifications

private let sideStickDefaultSourceURL =
    "https://raw.githubusercontent.com/itzmnyzzzXD/frozenapps/main/catalog/apps.json"

// MARK: - AltStore / SideStore-compatible source models

private struct SideStickSourceManifest: Decodable, Sendable {
    let name: String?
    let apps: [SideStickSourceApp]

    enum CodingKeys: String, CodingKey { case name, apps }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try? c.decode(String.self, forKey: .name)
        apps = (try? c.decode([SideStickSourceApp].self, forKey: .apps)) ?? []
    }
}

private struct SideStickSourceApp: Decodable, Identifiable, Sendable {
    let name: String
    let bundleIdentifier: String?
    let developerName: String?
    let subtitle: String?
    let localizedDescription: String?
    let iconURL: String?
    let category: String?
    let screenshots: [String]
    let versions: [SideStickSourceVersion]

    var id: String { bundleIdentifier ?? name }

    enum CodingKeys: String, CodingKey {
        case name, bundleIdentifier, developerName, subtitle, localizedDescription
        case iconURL, category, screenshots, screenshotURLs, versions
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        name = try c.decode(String.self, forKey: .name)
        bundleIdentifier = try? c.decode(String.self, forKey: .bundleIdentifier)
        developerName = try? c.decode(String.self, forKey: .developerName)
        subtitle = try? c.decode(String.self, forKey: .subtitle)
        localizedDescription = try? c.decode(String.self, forKey: .localizedDescription)
        iconURL = try? c.decode(String.self, forKey: .iconURL)
        category = try? c.decode(String.self, forKey: .category)
        screenshots = (try? c.decode([String].self, forKey: .screenshotURLs)) ?? (try? c.decode([String].self, forKey: .screenshots)) ?? []
        versions = (try? c.decode([SideStickSourceVersion].self, forKey: .versions)) ?? []
    }
}

private struct SideStickSourceVersion: Decodable, Identifiable, Sendable {
    let version: String
    let date: String?
    let downloadURL: String
    let size: Int?
    let minOSVersion: String?
    let localizedDescription: String?
    let changelog: String?

    var id: String { "\(version)|\(downloadURL)" }

    enum CodingKeys: String, CodingKey {
        case version, date, downloadURL, size, minOSVersion, localizedDescription, changelog
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        version = try c.decode(String.self, forKey: .version)
        downloadURL = try c.decode(String.self, forKey: .downloadURL)
        date = try? c.decode(String.self, forKey: .date)
        size = try? c.decode(Int.self, forKey: .size)
        minOSVersion = try? c.decode(String.self, forKey: .minOSVersion)
        localizedDescription = try? c.decode(String.self, forKey: .localizedDescription)
        changelog = try? c.decode(String.self, forKey: .changelog)
    }

    var fileSizeText: String? {
        guard let size, size > 0 else { return nil }
        return ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }

    var safeDownloadURL: URL? {
        guard let url = URL(string: downloadURL),
              url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        return url
    }
}

private struct SideStickSourceLoadResult: Sendable {
    let url: String
    let manifest: SideStickSourceManifest?
    let error: String?
}

private enum SideStickSourceLoader {
    static func load(_ rawURL: String) async -> SideStickSourceLoadResult {
        guard let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https", url.host != nil else {
            return .init(url: rawURL, manifest: nil, error: "Use a valid HTTPS source URL.")
        }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 18
            request.setValue("SideStick Live Sources", forHTTPHeaderField: "User-Agent")
            request.setValue("application/json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse,
                  (200..<300).contains(http.statusCode) else {
                return .init(url: rawURL, manifest: nil,
                             error: "The source returned HTTP \((response as? HTTPURLResponse)?.statusCode ?? -1).")
            }
            guard data.count <= 5_000_000 else {
                return .init(url: rawURL, manifest: nil, error: "Manifest is larger than the 5 MB limit.")
            }
            return .init(url: rawURL, manifest: try JSONDecoder().decode(SideStickSourceManifest.self, from: data), error: nil)
        } catch {
            return .init(url: rawURL, manifest: nil, error: "Could not load apps.json: \(error.localizedDescription)")
        }
    }
}

// Icons are downloaded once and cached on disk. The cache key is a SHA-256
// digest of the source URL, so list scrolling never decodes the same icon again.
private actor SideStickSourceIconCache {
    static let shared = SideStickSourceIconCache()

    func data(for rawURL: String) async -> Data? {
        guard let url = URL(string: rawURL),
              url.scheme?.lowercased() == "https", url.host != nil else { return nil }
        let key = SHA256.hash(data: Data(rawURL.utf8))
            .map { String(format: "%02x", $0) }.joined()
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let directory = base.appendingPathComponent("SideStickSourceIcons", isDirectory: true)
        guard (try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)) != nil else { return nil }
        let cachedURL = directory.appendingPathComponent(key).appendingPathExtension("image")
        if let cached = try? Data(contentsOf: cachedURL), UIImage(data: cached) != nil { return cached }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 12
            request.setValue("SideStick", forHTTPHeaderField: "User-Agent")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode),
                  data.count <= 8_000_000, UIImage(data: data) != nil else { return nil }
            try? data.write(to: cachedURL, options: .atomic)
            return data
        } catch { return nil }
    }
}

private struct SideStickSourceIcon: View {
    let rawURL: String?
    var size: CGFloat = 52
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill()
            } else {
                Image(systemName: "app.fill")
                    .font(.system(size: size * 0.4, weight: .medium))
                    .foregroundStyle(.white.opacity(0.7))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Theme.accent.opacity(0.18))
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: min(15, size * 0.25), style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: min(15, size * 0.25)).strokeBorder(.white.opacity(0.12), lineWidth: 1) }
        .task(id: rawURL) {
            guard let rawURL else { image = nil; return }
            let bytes = await SideStickSourceIconCache.shared.data(for: rawURL)
            image = bytes.flatMap { UIImage(data: $0) }
        }
    }
}

private struct SideStickSourceAppReference: Identifiable {
    let sourceURL: String
    let sourceName: String
    let app: SideStickSourceApp
    var id: String { "\(sourceURL)|\(app.id)" }
    var latestVersion: SideStickSourceVersion? { app.versions.first }
}

struct FrozenLiveSourcesView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("sidestick.liveSources.customURLs.v1") private var savedCustomSources = ""

    @State private var customSourceURLs: [String] = []
    @State private var manifests: [String: SideStickSourceManifest] = [:]
    @State private var sourceErrors: [String: String] = [:]
    @State private var installedVersions: [String: String] = [:]
    @State private var searchText = ""
    @State private var debouncedSearch = ""
    @State private var categoryFilter = "All categories"
    @State private var sourceFilter = "All sources"
    @State private var showAddSource = false
    @State private var newSourceURL = ""
    @State private var feedback: String?
    @State private var refreshing = false
    @State private var pendingRemoval: String?
    @State private var showRemovalConfirmation = false
    @State private var selectedApp: SideStickSourceAppReference?

    private var sourceURLs: [String] { [sideStickDefaultSourceURL] + customSourceURLs }

    private var apps: [SideStickSourceAppReference] {
        sourceURLs.flatMap { rawURL -> [SideStickSourceAppReference] in
            guard let manifest = manifests[rawURL] else { return [] }
            let candidate = manifest.name?.trimmingCharacters(in: .whitespacesAndNewlines)
            let sourceName = (candidate?.isEmpty == false ? candidate : nil) ?? URL(string: rawURL)?.host ?? rawURL
            return manifest.apps.map { .init(sourceURL: rawURL, sourceName: sourceName, app: $0) }
        }
    }

    private var categories: [String] {
        Array(Set(apps.compactMap { $0.app.category }.filter { !$0.isEmpty })).sorted()
    }

    private var visibleApps: [SideStickSourceAppReference] {
        let query = debouncedSearch.trimmingCharacters(in: .whitespacesAndNewlines)
        return apps.filter { item in
            let app = item.app
            let matchesSource = sourceFilter == "All sources" || item.sourceURL == sourceFilter
            let matchesText = query.isEmpty
                || app.name.localizedCaseInsensitiveContains(query)
                || (app.subtitle ?? "").localizedCaseInsensitiveContains(query)
                || (app.developerName ?? "").localizedCaseInsensitiveContains(query)
                || (app.bundleIdentifier ?? "").localizedCaseInsensitiveContains(query)
                || item.sourceName.localizedCaseInsensitiveContains(query)
            return matchesSource && matchesText && (categoryFilter == "All categories"
                || (app.category ?? "Other").localizedCaseInsensitiveCompare(categoryFilter) == .orderedSame)
        }.sorted { $0.app.name.localizedCaseInsensitiveCompare($1.app.name) == .orderedAscending }
    }

    var body: some View {
        ZStack {
            FrozenWorkspaceBackdrop()
            ScrollView {
                VStack(alignment: .leading, spacing: 15) {
                    FrozenWorkspacePageHeader(
                        eyebrow: "SideStick / Sources",
                        title: "Live App Sources",
                        description: "Import AltStore- and SideStore-compatible apps.json catalogs, inspect versions and save validated IPAs into your existing library.",
                        symbol: "square.stack.3d.up.fill"
                    )
                    sourceManager
                    VStack(alignment: .leading, spacing: 11) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("AVAILABLE APPS").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(.white.opacity(0.55))
                                Text("\(visibleApps.count) apps").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            }
                            Spacer()
                            Button { Task { await refreshSources() } } label: {
                                Label(refreshing ? "Refreshing…" : "Refresh", systemImage: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                    .padding(.horizontal, 11).padding(.vertical, 9)
                                    .background(.white.opacity(0.09), in: Capsule())
                            }.buttonStyle(.plain).disabled(refreshing)
                        }
                        FrozenWorkspaceSearchField(placeholder: "Search apps, developers or bundle IDs", text: $searchText)
                        if sourceURLs.count > 1 {
                            Picker("Source", selection: $sourceFilter) {
                                Text("All sources").tag("All sources")
                                ForEach(sourceURLs, id: \.self) { rawURL in
                                    Text(manifests[rawURL]?.name ?? URL(string: rawURL)?.host ?? rawURL).tag(rawURL)
                                }
                            }
                            .pickerStyle(.menu).tint(.white)
                            .padding(10).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if !categories.isEmpty {
                            Picker("Category", selection: $categoryFilter) {
                                Text("All categories").tag("All categories")
                                ForEach(categories, id: \.self) { Text($0).tag($0) }
                            }
                            .pickerStyle(.menu).tint(.white)
                            .padding(10).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if visibleApps.isEmpty {
                            FrozenWorkspacePanel {
                                VStack(alignment: .leading, spacing: 7) {
                                    Label(apps.isEmpty ? "No apps loaded" : "No matching apps", systemImage: "square.grid.2x2")
                                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    Text(apps.isEmpty ? "Refresh the default source or add an HTTPS apps.json URL." : "Clear the search or select another category.")
                                        .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                                    Button("Retry / clear filters") {
                                        if apps.isEmpty { Task { await refreshSources() } }
                                        else { searchText = ""; debouncedSearch = ""; categoryFilter = "All categories"; sourceFilter = "All sources" }
                                    }.buttonStyle(.plain).foregroundStyle(Theme.accent2).font(.system(size: 11, weight: .bold))
                                }
                            }
                        } else {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 235), spacing: 11)], spacing: 11) {
                                ForEach(visibleApps) { item in
                                    appCard(item).transition(.move(edge: .leading).combined(with: .opacity))
                                }
                            }
                        }
                    }
                    Text("Sources are user-controlled HTTPS manifests. SideStick does not host third-party apps. Review publishers, licences and IPA metadata before signing or installing.")
                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.42))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18).frame(maxWidth: 1120).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
            .refreshable { await refreshSources() }
        }
        .navigationTitle("Live App Sources")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            restoreCustomSources()
            await refreshSources()
            await loadInstalledVersions()
        }
        .task(id: searchText) {
            do { try await Task.sleep(for: .milliseconds(240)) } catch { return }
            debouncedSearch = searchText
        }
        .sheet(item: $selectedApp) { item in
            SideStickSourceAppDetailView(reference: item, installedVersion: installedVersion(for: item.app))
        }
        .alert("Add app source", isPresented: $showAddSource) {
            TextField("https://example.com/apps.json", text: $newSourceURL)
                .textInputAutocapitalization(.never).autocorrectionDisabled().keyboardType(.URL)
            Button("Cancel", role: .cancel) { newSourceURL = "" }
            Button("Add source") { addSource() }
        } message: {
            Text("Enter a direct HTTPS URL to an AltStore/SideStore-compatible apps.json manifest. The default source is locked.")
        }
        .confirmationDialog("Remove custom source?", isPresented: $showRemovalConfirmation, titleVisibility: .visible) {
            Button("Remove source", role: .destructive) {
                if let pendingRemoval { removeSource(pendingRemoval) }
                pendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { pendingRemoval = nil }
        } message: {
            Text("Removing a source does not remove IPAs already saved to your library.")
        }
    }

    private var sourceManager: some View {
        FrozenWorkspacePanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text("APP SOURCES").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                        Text("Default source and your URLs").font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    }
                    Spacer(minLength: 4)
                    Button { newSourceURL = ""; showAddSource = true } label: {
                        Label("Add URL", systemImage: "plus").font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white).padding(.horizontal, 11).padding(.vertical, 9)
                            .background(.white.opacity(0.11), in: Capsule())
                            .overlay { Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
                    }.buttonStyle(.plain)
                }
                ForEach(sourceURLs, id: \.self) { rawURL in
                    sourceRow(rawURL, locked: rawURL == sideStickDefaultSourceURL)
                        .transition(.move(edge: .leading).combined(with: .opacity))
                }
                if let feedback {
                    Text(feedback).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.72))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button {
                    if let url = URL(string: "https://faq.altstore.io/altstore-classic/how-to-use-altstore/sources") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Label("How to make your own app source", systemImage: "book.closed")
                        .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accent2)
                        .frame(maxWidth: .infinity, alignment: .leading).padding(.top, 4)
                }.buttonStyle(.plain)
            }
        }
    }

    private func sourceRow(_ rawURL: String, locked: Bool) -> some View {
        HStack(spacing: 10) {
            Image(systemName: locked ? "lock.fill" : "link")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(locked ? Theme.accent2 : .white.opacity(0.7))
                .frame(width: 34, height: 34).background(.white.opacity(0.07), in: RoundedRectangle(cornerRadius: 10))
            VStack(alignment: .leading, spacing: 3) {
                Text(manifests[rawURL]?.name ?? (locked ? "SideStick Default Catalog" : URL(string: rawURL)?.host ?? "Custom source"))
                    .font(.system(size: 11, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                Text(rawURL).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                if let error = sourceErrors[rawURL] {
                    Text(error).font(.system(size: 9, weight: .medium)).foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true)
                } else if let manifest = manifests[rawURL] {
                    Text("\(manifest.apps.count) app(s) · Loaded").font(.system(size: 9, weight: .medium)).foregroundStyle(.green.opacity(0.82))
                }
            }
            Spacer(minLength: 0)
            if locked {
                Text("DEFAULT").font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(0.8)
                    .foregroundStyle(Theme.accent2).padding(.horizontal, 8).padding(.vertical, 6)
                    .background(Theme.accent2.opacity(0.12), in: Capsule())
            } else {
                Button {
                    pendingRemoval = rawURL
                    showRemovalConfirmation = true
                } label: {
                    Image(systemName: "minus.circle.fill").font(.system(size: 18)).foregroundStyle(.red.opacity(0.85))
                }.buttonStyle(.plain).accessibilityLabel("Remove \(rawURL)")
            }
        }
        .padding(10).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.07), lineWidth: 1) }
    }

    private func appCard(_ item: SideStickSourceAppReference) -> some View {
        Button { selectedApp = item } label: {
            FrozenWorkspacePanel {
                HStack(alignment: .top, spacing: 10) {
                    SideStickSourceIcon(rawURL: item.app.iconURL, size: 52)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(item.app.name).font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                        Text(item.app.subtitle ?? item.app.developerName ?? item.sourceName)
                            .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.56)).lineLimit(2)
                        if let version = item.latestVersion {
                            Text("v\(version.version)\(version.fileSizeText.map { " · \($0)" } ?? "")")
                                .font(.system(size: 9, weight: .semibold, design: .rounded)).foregroundStyle(Theme.accent2)
                        } else {
                            Text("No release listed").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.42))
                        }
                    }
                    Spacer(minLength: 0)
                    Image(systemName: "chevron.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.34)).padding(.top, 4)
                }
            }.contentShape(RoundedRectangle(cornerRadius: 17, style: .continuous))
        }.buttonStyle(FrozenWorkspacePressStyle())
    }

    private func restoreCustomSources() {
        var seen = Set<String>()
        customSourceURLs = savedCustomSources.split(whereSeparator: \.isNewline).map(String.init)
            .filter { $0 != sideStickDefaultSourceURL && seen.insert($0).inserted }
    }

    private func persistCustomSources() {
        savedCustomSources = customSourceURLs.joined(separator: "\n")
    }

    private func addSource() {
        let raw = newSourceURL.trimmingCharacters(in: .whitespacesAndNewlines)
        newSourceURL = ""
        guard let url = URL(string: raw), url.scheme?.lowercased() == "https", url.host != nil else {
            feedback = "Source not added. Use a complete HTTPS URL."
            return
        }
        guard raw != sideStickDefaultSourceURL, !customSourceURLs.contains(raw) else {
            feedback = "That source is already saved."
            return
        }
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) { customSourceURLs.append(raw) }
        persistCustomSources()
        feedback = "Source added. Refreshing…"
        Task { await refreshSources() }
    }

    private func removeSource(_ rawURL: String) {
        withAnimation(reduceMotion ? nil : .easeOut(duration: 0.2)) {
            customSourceURLs.removeAll { $0 == rawURL }
            if sourceFilter == rawURL { sourceFilter = "All sources" }
            manifests.removeValue(forKey: rawURL)
            sourceErrors.removeValue(forKey: rawURL)
        }
        persistCustomSources()
        feedback = "Custom source removed. Saved library files were kept."
    }

    @MainActor
    private func refreshSources() async {
        guard !refreshing else { return }
        refreshing = true
        defer { refreshing = false }
        sourceErrors = [:]
        await withTaskGroup(of: SideStickSourceLoadResult.self) { group in
            for rawURL in sourceURLs { group.addTask { await SideStickSourceLoader.load(rawURL) } }
            for await result in group {
                if let manifest = result.manifest { manifests[result.url] = manifest }
                else { sourceErrors[result.url] = result.error ?? "Source failed to load." }
            }
        }
        feedback = sourceErrors.isEmpty ? "All sources refreshed." : "\(sourceErrors.count) source(s) need attention."
    }

    private func loadInstalledVersions() async {
        let directory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FrozenApps Library", isDirectory: true)
        installedVersions = await Task.detached(priority: .utility) { () -> [String: String] in
            guard let files = try? FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil) else { return [:] }
            var versions: [String: String] = [:]
            for file in files where file.pathExtension.lowercased() == "ipa" {
                if let info = IPALibrary.appInfo(at: file), !info.bundleID.isEmpty { versions[info.bundleID] = info.version }
            }
            return versions
        }.value
    }

    private func installedVersion(for app: SideStickSourceApp) -> String? {
        guard let bundleID = app.bundleIdentifier, !bundleID.isEmpty else { return nil }
        return installedVersions[bundleID]
    }
}

private struct SideStickSourceAppDetailView: View {
    let reference: SideStickSourceAppReference
    let installedVersion: String?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var downloadingVersionID: String?
    @State private var statusMessage: String?
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            ZStack {
                FrozenWorkspaceBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        HStack(alignment: .top, spacing: 13) {
                            SideStickSourceIcon(rawURL: reference.app.iconURL, size: 76)
                            VStack(alignment: .leading, spacing: 5) {
                                Text(reference.app.name).font(.system(size: 21, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                Text(reference.app.developerName ?? reference.sourceName).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                                if let subtitle = reference.app.subtitle {
                                    Text(subtitle).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.75)).fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                        if let installedVersion {
                            HStack {
                                Label("Installed: v\(installedVersion)", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                                Spacer(minLength: 5)
                                if let latest = reference.latestVersion {
                                    Text("Latest: v\(latest.version)").foregroundStyle(latest.version == installedVersion ? .green : Theme.accent2)
                                }
                            }
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .padding(12).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12))
                        } else if reference.app.bundleIdentifier == nil {
                            Text("For version comparison, this app's manifest entry must include bundleIdentifier.")
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                        }
                        if let description = reference.app.localizedDescription {
                            Text(description).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.74)).fixedSize(horizontal: false, vertical: true)
                        }
                        if !reference.app.screenshots.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("SCREENSHOTS").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.3).foregroundStyle(.white.opacity(0.55))
                                ScrollView(.horizontal) {
                                    HStack(spacing: 10) {
                                        ForEach(Array(reference.app.screenshots.enumerated()), id: \.offset) { _, raw in
                                            if let url = URL(string: raw), url.scheme?.lowercased() == "https" {
                                                AsyncImage(url: url) { phase in
                                                    if let image = phase.image { image.resizable().scaledToFill() }
                                                    else { RoundedRectangle(cornerRadius: 14).fill(.white.opacity(0.06)).overlay { Image(systemName: "photo").foregroundStyle(.white.opacity(0.4)) } }
                                                }
                                                .frame(width: 220, height: 300)
                                                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                                            }
                                        }
                                    }
                                }.scrollIndicators(.hidden)
                            }
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text("VERSIONS").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.3).foregroundStyle(.white.opacity(0.55))
                            if reference.app.versions.isEmpty {
                                Text("This source has no direct downloadable versions listed.").font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                            }
                            ForEach(reference.app.versions) { version in
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Version \(version.version)").font(.system(size: 12, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                        Spacer()
                                        if let size = version.fileSizeText { Text(size).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.45)) }
                                    }
                                    if let date = version.date { Text(date).font(.system(size: 9, weight: .medium, design: .monospaced)).foregroundStyle(.white.opacity(0.42)) }
                                    if let notes = version.changelog ?? version.localizedDescription {
                                        Text(notes).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.65)).fixedSize(horizontal: false, vertical: true)
                                    }
                                    HStack {
                                        if let minimum = version.minOSVersion {
                                            Text("Minimum OS \(minimum)").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                                        }
                                        Spacer()
                                        Button { Task { await download(version) } } label: {
                                            if downloadingVersionID == version.id { ProgressView().tint(.white) }
                                            else { Label("Download", systemImage: "arrow.down.circle") }
                                        }
                                        .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white).buttonStyle(.plain)
                                        .disabled(downloadingVersionID != nil || version.safeDownloadURL == nil)
                                    }
                                }
                                .padding(12).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                                .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.07), lineWidth: 1) }
                            }
                        }
                        if let statusMessage {
                            Label(statusMessage, systemImage: "checkmark.circle.fill").font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.green).fixedSize(horizontal: false, vertical: true).padding(12)
                                .background(.green.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        if let errorMessage {
                            Label(errorMessage, systemImage: "exclamationmark.triangle.fill").font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.orange).fixedSize(horizontal: false, vertical: true).padding(12)
                                .background(.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                        Button {
                            if let url = URL(string: reference.sourceURL) { openURL(url) }
                        } label: {
                            Label("Open source manifest", systemImage: "arrow.up.right.square")
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(Theme.accent2)
                        }.buttonStyle(.plain)
                    }
                    .padding(18).frame(maxWidth: 800).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
            .navigationTitle(reference.app.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
    }

    @MainActor
    private func download(_ version: SideStickSourceVersion) async {
        guard let url = version.safeDownloadURL else { errorMessage = "Only valid HTTPS IPA download URLs are allowed."; return }
        downloadingVersionID = version.id
        statusMessage = nil
        errorMessage = nil
        defer { downloadingVersionID = nil }

        do {
            let (temporaryURL, response) = try await URLSession.shared.download(from: url)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw SideStickSourceDownloadError.http((response as? HTTPURLResponse)?.statusCode ?? -1)
            }
            let attributes = try FileManager.default.attributesOfItem(atPath: temporaryURL.path)
            let bytes = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            guard bytes > 0, bytes <= 1_000_000_000 else { throw SideStickSourceDownloadError.invalidSize }
            guard IPALibrary.looksLikeIPA(temporaryURL), let metadata = IPALibrary.appInfo(at: temporaryURL) else {
                throw SideStickSourceDownloadError.invalidIPA
            }
            if let expected = reference.app.bundleIdentifier, !expected.isEmpty,
               metadata.bundleID.caseInsensitiveCompare(expected) != .orderedSame {
                throw SideStickSourceDownloadError.bundleMismatch(expected: expected, actual: metadata.bundleID)
            }

            let safeBase = "\(reference.app.name) \(version.version)"
                .components(separatedBy: CharacterSet(charactersIn: "/\\:?%*|\"<>"))
                .joined(separator: "-")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let tempDirectory = FileManager.default.temporaryDirectory
                .appendingPathComponent("SideStick-Source-\(UUID().uuidString)", isDirectory: true)
            try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
            defer { try? FileManager.default.removeItem(at: tempDirectory) }
            let stagedIPA = tempDirectory
                .appendingPathComponent(safeBase.isEmpty ? "Imported App" : safeBase)
                .appendingPathExtension("ipa")
            try FileManager.default.copyItem(at: temporaryURL, to: stagedIPA)
            let importedURL = try FrozenLibraryStore.importIPA(from: stagedIPA)
            statusMessage = "Downloaded and validated \(importedURL.lastPathComponent) (\(metadata.name), v\(metadata.version)). Open IPA Library to load it into Signer."
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

private enum SideStickSourceDownloadError: LocalizedError {
    case http(Int), invalidSize, invalidIPA, bundleMismatch(expected: String, actual: String)

    var errorDescription: String? {
        switch self {
        case .http(let code): return "Download failed with HTTP \(code)."
        case .invalidSize: return "The download was empty or exceeded the 1 GB limit."
        case .invalidIPA: return "The file failed IPA archive or app-metadata validation and was not added to the library."
        case .bundleMismatch(let expected, let actual): return "Manifest bundle ID \(expected) does not match the IPA's \(actual). The file was not imported."
        }
    }
}

// MARK: - Local notification categories and preferences

enum SideStickNotificationKind: String, CaseIterable, Identifiable {
    case signing, installation, certificates, pairing, catalog, batch
    var id: String { rawValue }
    var preferenceKey: String { "sidestick.notifications.\(rawValue).enabled" }

    var title: String {
        switch self {
        case .signing: return "Signing updates"
        case .installation: return "Installation updates"
        case .certificates: return "Certificate and profile expiry"
        case .pairing: return "Pairing status"
        case .catalog: return "Tracked app releases"
        case .batch: return "Batch preflight reports"
        }
    }

    var detail: String {
        switch self {
        case .signing: return "Signing started, succeeded or failed."
        case .installation: return "Install progress, success and failure reason."
        case .certificates: return "Local certificate and provisioning-profile expiry reminders."
        case .pairing: return "Pairing received, completed or expired. Codes are never included."
        case .catalog: return "New releases for tracked apps."
        case .batch: return "A grouped preflight summary, not one banner per IPA."
        }
    }

    var defaultEnabled: Bool { self != .catalog }
}

enum SideStickNotificationService {
    static func registerCategories() {
        let details = UNNotificationAction(identifier: "SIDESTICK_VIEW_DETAILS", title: "View details", options: [.foreground])
        let retry = UNNotificationAction(identifier: "SIDESTICK_RETRY", title: "Retry", options: [])
        UNUserNotificationCenter.current().setNotificationCategories([
            .init(identifier: SideStickNotificationKind.signing.rawValue, actions: [retry, details], intentIdentifiers: []),
            .init(identifier: SideStickNotificationKind.installation.rawValue, actions: [retry, details], intentIdentifiers: []),
            .init(identifier: SideStickNotificationKind.certificates.rawValue, actions: [details], intentIdentifiers: []),
            .init(identifier: SideStickNotificationKind.pairing.rawValue, actions: [details], intentIdentifiers: []),
            .init(identifier: SideStickNotificationKind.catalog.rawValue, actions: [details], intentIdentifiers: []),
            .init(identifier: SideStickNotificationKind.batch.rawValue, actions: [details], intentIdentifiers: [])
        ])
    }

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge])) ?? false
    }

    /// Central gate for event hooks. Pairing bodies are intentionally generic
    /// so a caller cannot accidentally place a one-time code in a notification.
    static func post(_ kind: SideStickNotificationKind, title: String, body: String, identifier: String) async {
        guard UserDefaults.standard.object(forKey: kind.preferenceKey) as? Bool ?? kind.defaultEnabled else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = kind == .pairing ? "Open SideStick to review pairing status." : body
        content.sound = .default
        content.categoryIdentifier = kind.rawValue
        content.threadIdentifier = kind.rawValue
        try? await UNUserNotificationCenter.current().add(
            UNNotificationRequest(identifier: identifier, content: content, trigger: nil)
        )
    }
}

private struct SideStickNotificationPreferenceRow: View {
    let kind: SideStickNotificationKind
    @State private var enabled: Bool

    init(kind: SideStickNotificationKind) {
        self.kind = kind
        _enabled = State(initialValue: UserDefaults.standard.object(forKey: kind.preferenceKey) as? Bool ?? kind.defaultEnabled)
    }

    var body: some View {
        Toggle(isOn: $enabled) {
            VStack(alignment: .leading, spacing: 4) {
                Text(kind.title).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(kind.detail).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.52)).fixedSize(horizontal: false, vertical: true)
            }
        }
        .tint(Theme.accent2)
        .onChange(of: enabled) { value in UserDefaults.standard.set(value, forKey: kind.preferenceKey) }
    }
}

struct FrozenNotificationPreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var resultMessage: String?
    @State private var didTest = false

    var body: some View {
        NavigationStack {
            ZStack {
                FrozenWorkspaceBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 13) {
                        FrozenWorkspacePageHeader(
                            eyebrow: "SideStick / Preferences",
                            title: "Notifications",
                            description: "Choose which SideStick event categories may notify you. Pairing notifications never contain a pairing code, Apple ID, password or verification code.",
                            symbol: "bell.badge.fill"
                        )
                        FrozenWorkspacePanel {
                            VStack(alignment: .leading, spacing: 15) {
                                ForEach(SideStickNotificationKind.allCases) { kind in
                                    SideStickNotificationPreferenceRow(kind: kind)
                                    if kind != SideStickNotificationKind.allCases.last {
                                        Divider().overlay(.white.opacity(0.08))
                                    }
                                }
                            }
                        }
                        FrozenWorkspacePanel {
                            VStack(alignment: .leading, spacing: 9) {
                                Text("NOTIFICATION PERMISSION").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.35).foregroundStyle(Theme.accent2)
                                Text("iPadOS permission and Focus settings still control whether a local notification is shown.")
                                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                                Button("Request notification permission") {
                                    Task {
                                        let granted = await SideStickNotificationService.requestPermission()
                                        resultMessage = granted ? "Notification permission is enabled." : "Permission was not granted. Check iPad Settings → Notifications → SideStick."
                                    }
                                }
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).buttonStyle(.plain)
                                .padding(11).frame(maxWidth: .infinity).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                Button("Send test notification") {
                                    Task {
                                        guard await SideStickNotificationService.requestPermission() else {
                                            resultMessage = "Enable notifications in iPad Settings first."
                                            return
                                        }
                                        await SideStickNotificationService.post(.batch, title: "SideStick notification test",
                                            body: "Your notification settings are working.", identifier: "sidestick-test-\(UUID().uuidString)")
                                        didTest = true
                                        resultMessage = "A test notification was queued. iPadOS controls its delivery."
                                    }
                                }
                                .font(.system(size: 11, weight: .semibold)).foregroundStyle(.white).buttonStyle(.plain)
                                .padding(11).frame(maxWidth: .infinity).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                                if let resultMessage {
                                    Text(resultMessage).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.74)).fixedSize(horizontal: false, vertical: true)
                                }
                                if didTest {
                                    Text("If no banner appears, review Focus and notification delivery settings.")
                                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.44))
                                }
                            }
                        }
                    }
                    .padding(18).frame(maxWidth: 760).frame(maxWidth: .infinity)
                }.scrollIndicators(.hidden)
            }
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .task { SideStickNotificationService.registerCategories() }
    }
}
