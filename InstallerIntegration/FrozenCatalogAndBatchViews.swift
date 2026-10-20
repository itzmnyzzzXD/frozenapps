import Foundation
import SwiftUI
import UniformTypeIdentifiers

private struct FrozenCatalogRelease: Decodable {
    let name: String?
    let tag_name: String
    let html_url: String
    let assets: [FrozenCatalogAsset]
}

private struct FrozenCatalogAsset: Decodable, Identifiable {
    let name: String
    let browser_download_url: String
    let size: Int
    var id: String { browser_download_url }
}

private struct FrozenCatalogReleaseResponse: Decodable {
    let message: String?
}

private struct FrozenCatalogSource: Codable, Identifiable, Equatable {
    var repository: String
    var id: String { repository.lowercased() }
    var owner: String { repository.split(separator: "/").first.map(String.init) ?? "" }
    var repo: String { repository.split(separator: "/").dropFirst().first.map(String.init) ?? "" }
    var title: String { repo.replacingOccurrences(of: "-", with: " ").replacingOccurrences(of: "_", with: " ") }
    var url: URL? { URL(string: "https://github.com/\(repository)") }

    static let builtIn: [FrozenCatalogSource] = [
        .init(repository: "SideStore/SideStore"),
        .init(repository: "LiveContainer/LiveContainer"),
        .init(repository: "utmapp/UTM"),
        .init(repository: "PPSSPPTeam/ppsspp"),
        .init(repository: "RetroArch/RetroArch")
    ]
}

/// A source-first catalog: downloads are offered only when a repository's
/// public GitHub release actually contains an IPA asset. Otherwise the source
/// link remains available without pretending a compatible IPA exists.
struct FrozenAppCatalogView: View {
    @Environment(\.openURL) private var openURL
    @AppStorage("frozenApps.catalog.sources.v1") private var savedSources = ""
    @State private var search = ""
    @State private var newRepository = ""
    @State private var sources: [FrozenCatalogSource] = FrozenCatalogSource.builtIn
    @State private var releases: [String: FrozenCatalogRelease] = [:]
    @State private var loading = Set<String>()
    @State private var downloading = Set<String>()
    @State private var messages: [String: String] = [:]
    @State private var showAddSource = false

    private var visibleSources: [FrozenCatalogSource] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return sources }
        return sources.filter { $0.repository.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    HStack(spacing: 10) {
                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent2)
                        TextField("Search apps or GitHub sources", text: $search)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                    }
                    .padding(13)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 14))
                    .overlay { RoundedRectangle(cornerRadius: 14).strokeBorder(.white.opacity(0.09)) }

                    HStack {
                        Text("SOURCES").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.5).foregroundStyle(Theme.accent2)
                        Spacer()
                        Button { showAddSource = true } label: {
                            Label("Add source", systemImage: "plus")
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                    }

                    ForEach(visibleSources) { source in
                        sourceCard(source)
                    }

                    PanelCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("More app categories", systemImage: "square.grid.2x2.fill")
                                .font(.system(size: 13, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("YouTube clients (YTPlus/uYouEnhanced), Spotify clients (EeveeSpotify), Twitch clients, Scarlet, E-Sign, SideStore, emulators, torrent utilities and other projects can be discovered through their maintainers' public repositories. Availability and release assets vary by project.")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.58))
                                .fixedSize(horizontal: false, vertical: true)
                            Button {
                                openURL(URL(string: "https://github.com/search?q=YTPlus&type=repositories")!)
                            } label: {
                                Label("Discover more GitHub projects", systemImage: "arrow.up.right.square")
                                    .font(.system(size: 11, weight: .bold))
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Theme.accent.opacity(0.16), in: RoundedRectangle(cornerRadius: 12))
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }
                    }

                    Text("FrozenApps does not host third-party apps. Source links point to GitHub; only actual IPA release assets are downloadable here. Verify maintainers, licences and file hashes before installing. Signing and installation still require the supported engine and valid device/signing setup.")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.43))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(18)
                .frame(maxWidth: 700)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("App Catalog")
        .navigationBarTitleDisplayMode(.inline)
        .task(perform: restoreSources)
        .alert("Add GitHub source", isPresented: $showAddSource) {
            TextField("owner/repository", text: $newRepository)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) { newRepository = "" }
            Button("Add") { addSource() }
        } message: {
            Text("Enter a public GitHub repository as owner/repository. FrozenApps checks its latest public release for IPA assets.")
        }
    }

    private var header: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(spacing: 11) {
                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 48, height: 48)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 15))
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FROZENAPPS · DISCOVER")
                            .font(.system(size: 9, weight: .heavy, design: .rounded))
                            .tracking(1.4)
                            .foregroundStyle(Theme.accent2)
                        Text("Apps, sources, releases")
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                Text("Browse public projects, add your own GitHub sources, inspect real release assets and save available IPA files into the FrozenApps library.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourceCard(_ source: FrozenCatalogSource) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "shippingbox.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Theme.accent2)
                        .frame(width: 38, height: 38)
                        .background(Theme.accent.opacity(0.14), in: RoundedRectangle(cornerRadius: 12))
                    VStack(alignment: .leading, spacing: 3) {
                        Text(source.title)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text(source.repository)
                            .font(.system(size: 10, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.48))
                    }
                    Spacer(minLength: 0)
                    if loading.contains(source.id) {
                        ProgressView().tint(Theme.accent2)
                    } else {
                        Button("Check releases") { Task { await loadRelease(for: source) } }
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .buttonStyle(.plain)
                            .foregroundStyle(Theme.accent2)
                    }
                }

                if let release = releases[source.id] {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(release.name?.isEmpty == false ? release.name! : release.tag_name)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.9))
                            Text("\(release.tag_name) · \(release.assets.count) release asset(s)")
                                .font(.system(size: 9, weight: .medium, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Button("Release page") {
                            if let url = URL(string: release.html_url) { openURL(url) }
                        }
                        .font(.system(size: 10, weight: .semibold))
                        .buttonStyle(.plain)
                    }
                    let ipaAssets = release.assets.filter { $0.name.lowercased().hasSuffix(".ipa") }
                    if ipaAssets.isEmpty {
                        Text("No .ipa asset was published in this latest release. Open the source to inspect its official installation instructions.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                    } else {
                        ForEach(ipaAssets) { asset in
                            HStack(spacing: 8) {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(asset.name).font(.system(size: 10, weight: .semibold)).foregroundStyle(.white)
                                    Text(ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file))
                                        .font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.45))
                                }
                                Spacer()
                                if downloading.contains(asset.id) {
                                    ProgressView().tint(Theme.accent2)
                                } else {
                                    Button("Download IPA") { Task { await download(asset, source: source) } }
                                        .font(.system(size: 10, weight: .bold, design: .rounded))
                                        .buttonStyle(.plain)
                                        .foregroundStyle(Theme.accent2)
                                }
                            }
                            .padding(10)
                            .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }

                if let message = messages[source.id] {
                    Text(message)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(message.hasPrefix("Saved") ? Theme.accent2 : .orange)
                        .fixedSize(horizontal: false, vertical: true)
                }

                HStack {
                    Button { Task { await loadRelease(for: source) } } label: {
                        Label("Refresh", systemImage: "arrow.clockwise")
                    }
                    Spacer()
                    Button { if let url = source.url { openURL(url) } } label: {
                        Label("Open GitHub", systemImage: "arrow.up.right.square")
                    }
                }
                .font(.system(size: 10, weight: .semibold))
                .buttonStyle(.plain)
                .foregroundStyle(.white.opacity(0.68))
            }
        }
    }

    private func restoreSources() {
        guard let data = savedSources.data(using: .utf8),
              let stored = try? JSONDecoder().decode([FrozenCatalogSource].self, from: data) else { return }
        sources = Array(Dictionary((FrozenCatalogSource.builtIn + stored).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func addSource() {
        let normalized = newRepository.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "https://github.com/", with: "")
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = normalized.split(separator: "/")
        guard parts.count == 2,
              parts.allSatisfy({ !$0.isEmpty && !$0.contains(".") && !$0.contains(" ") }) else { return }
        let source = FrozenCatalogSource(repository: normalized)
        if !sources.contains(where: { $0.id == source.id }) { sources.append(source) }
        if let data = try? JSONEncoder().encode(sources) { savedSources = String(decoding: data, as: UTF8.self) }
        newRepository = ""
        Task { await loadRelease(for: source) }
    }

    @MainActor
    private func loadRelease(for source: FrozenCatalogSource) async {
        guard !loading.contains(source.id) else { return }
        loading.insert(source.id)
        defer { loading.remove(source.id) }
        do {
            let url = URL(string: "https://api.github.com/repos/\(source.repository)/releases/latest")!
            var request = URLRequest(url: url)
            request.timeoutInterval = 15
            request.setValue("FrozenApps", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard http.statusCode == 200 else {
                throw NSError(domain: "FrozenCatalog", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: http.statusCode == 404 ? "No public latest release was found for this source." : "GitHub returned HTTP \(http.statusCode)."])
            }
            releases[source.id] = try JSONDecoder().decode(FrozenCatalogRelease.self, from: data)
            messages[source.id] = nil
        } catch {
            messages[source.id] = error.localizedDescription
        }
    }

    @MainActor
    private func download(_ asset: FrozenCatalogAsset, source: FrozenCatalogSource) async {
        guard let url = URL(string: asset.browser_download_url),
              url.host == "github.com" || url.host == "objects.githubusercontent.com" || url.host?.hasSuffix(".githubusercontent.com") == true else {
            messages[source.id] = "Download blocked: the asset URL is not a trusted GitHub host."
            return
        }
        guard !downloading.contains(asset.id) else { return }
        downloading.insert(asset.id)
        defer { downloading.remove(asset.id) }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 90
            request.setValue("FrozenApps", forHTTPHeaderField: "User-Agent")
            let (temporary, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }
            let folder = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FrozenApps Library", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeName = asset.name.replacingOccurrences(of: "/", with: "_")
            var destination = folder.appendingPathComponent(safeName)
            if FileManager.default.fileExists(atPath: destination.path) {
                destination = folder.appendingPathComponent("\(destination.deletingPathExtension().lastPathComponent)-\(UUID().uuidString.prefix(6)).ipa")
            }
            try FileManager.default.moveItem(at: temporary, to: destination)
            messages[source.id] = "Saved \(destination.lastPathComponent) to the IPA Library. Validate it before signing or installing."
        } catch {
            messages[source.id] = "Download failed: \(error.localizedDescription)"
        }
    }
}

/// Batch preflight for IPA archives. Signing is deliberately handed off to the
/// existing engine instead of fabricating a batch-sign result.
struct FrozenBatchActionsView: View {
    @State private var showImporter = false
    @State private var selectedFiles: [URL] = []
    @State private var reports: [String] = []
    @State private var working = false
    @State private var queue: [String] = []
    @State private var confirmation = false

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    PanelCard {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("FROZENAPPS · AUTOMATION")
                                .font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                            Text("Batch Actions")
                                .font(.system(size: 23, weight: .bold, design: .rounded)).foregroundStyle(.white)
                            Text("Select several IPA files, run archive preflight checks, and build a reviewable queue. Signing and installation remain engine-controlled actions.")
                                .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                            Button { showImporter = true } label: {
                                Label("Select IPA files", systemImage: "doc.badge.plus")
                                    .font(.system(size: 12, weight: .bold, design: .rounded))
                                    .frame(maxWidth: .infinity).padding(12)
                                    .background(Theme.brand, in: RoundedRectangle(cornerRadius: 13))
                            }
                            .buttonStyle(.plain).foregroundStyle(.white)
                        }
                    }
                    if !selectedFiles.isEmpty {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 9) {
                                HStack {
                                    Text("\(selectedFiles.count) selected IPA(s)")
                                        .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    Spacer()
                                    Button("Clear") { confirmation = true }
                                        .font(.system(size: 10, weight: .semibold)).buttonStyle(.plain).foregroundStyle(.orange)
                                }
                                Button {
                                    Task { await validateSelection() }
                                } label: {
                                    HStack {
                                        if working { ProgressView().tint(.white) }
                                        Text(working ? "Checking packages…" : "Validate selected packages")
                                            .font(.system(size: 11, weight: .bold, design: .rounded))
                                        Spacer()
                                        Image(systemName: "checkmark.shield.fill")
                                    }
                                    .padding(12).background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 12))
                                }
                                .buttonStyle(.plain).foregroundStyle(.white).disabled(working)
                                ForEach(selectedFiles, id: \.path) { file in
                                    Label(file.lastPathComponent, systemImage: "doc.zipper")
                                        .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.7)).lineLimit(1)
                                }
                            }
                        }
                    }
                    if !reports.isEmpty {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 10) {
                                HStack {
                                    Text("PREFLIGHT REPORT").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                    Spacer()
                                    Button { UIPasteboard.general.string = reports.joined(separator: "\n\n") } label: {
                                        Label("Copy", systemImage: "doc.on.doc").font(.system(size: 10, weight: .bold))
                                    }.buttonStyle(.plain).foregroundStyle(Theme.accent2)
                                }
                                ForEach(Array(reports.enumerated()), id: \.offset) { _, report in
                                    Text(report).font(.system(size: 10, weight: .medium, design: .monospaced))
                                        .foregroundStyle(.white.opacity(0.72)).fixedSize(horizontal: false, vertical: true)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .padding(10).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                    }
                    if !queue.isEmpty {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("INSTALL QUEUE").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.4).foregroundStyle(Theme.accent2)
                                Text("Queue prepared for manual handoff. This screen does not claim that queued files have been signed or installed.")
                                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.5))
                                ForEach(Array(queue.enumerated()), id: \.offset) { index, item in
                                    HStack(spacing: 8) {
                                        Text(String(format: "%02d", index + 1)).foregroundStyle(Theme.accent2)
                                        Text(item).foregroundStyle(.white.opacity(0.75)).lineLimit(1)
                                        Spacer()
                                    }.font(.system(size: 10, weight: .medium, design: .monospaced))
                                }
                            }
                        }
                    }
                }
                .padding(18).frame(maxWidth: 700).frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .navigationTitle("Batch Actions")
        .navigationBarTitleDisplayMode(.inline)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                selectedFiles = urls.filter { $0.pathExtension.lowercased() == "ipa" }
                reports = []
                queue = []
            case .failure(let error):
                reports = ["Picker failed: \(error.localizedDescription)"]
            }
        }
        .confirmationDialog("Clear selected files and reports?", isPresented: $confirmation, titleVisibility: .visible) {
            Button("Clear everything", role: .destructive) {
                selectedFiles = []
                reports = []
                queue = []
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This clears the current selection and local report only. It does not delete IPA files.")
        }
    }

    @MainActor
    private func validateSelection() async {
        guard !working else { return }
        working = true
        defer { working = false }
        reports = []
        queue = []
        for file in selectedFiles {
            let scoped = file.startAccessingSecurityScopedResource()
            defer { if scoped { file.stopAccessingSecurityScopedResource() } }
            do {
                let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
                let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
                let isReadable = FileManager.default.isReadableFile(atPath: file.path)
                guard isReadable, size > 0 else { throw NSError(domain: "FrozenBatch", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is empty or unreadable."]) }
                guard file.pathExtension.lowercased() == "ipa" else { throw NSError(domain: "FrozenBatch", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not an IPA extension."]) }
                reports.append("READY FOR IMPORT · \(file.lastPathComponent)\nSize: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))\nArchive contents and app metadata must still pass FrozenApps Library validation.")
                queue.append(file.lastPathComponent)
            } catch {
                reports.append("FAILED PRECHECK · \(file.lastPathComponent)\n\(error.localizedDescription)")
            }
        }
    }
}
