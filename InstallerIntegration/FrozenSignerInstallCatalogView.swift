import Foundation
import SwiftUI
import UniformTypeIdentifiers

private enum FrozenSignerCatalogCategory: String, CaseIterable, Identifiable {
    case all = "All"
    case signing = "Signing"
    case media = "Media"
    case emulators = "Emulators"
    case games = "Games"
    case utilities = "Utilities"

    var id: String { rawValue }
}

private struct FrozenSignerCatalogApp: Identifiable, Hashable {
    let name: String
    let subtitle: String
    let category: FrozenSignerCatalogCategory
    let icon: String
    let repository: String?
    let searchQuery: String

    var id: String { repository ?? name }
    var repositoryURL: URL? {
        guard let repository else { return nil }
        return URL(string: "https://github.com/\(repository)")
    }

    var searchURL: URL? {
        if let repositoryURL { return repositoryURL }
        var parts = URLComponents(string: "https://github.com/search")!
        parts.queryItems = [
            URLQueryItem(name: "q", value: searchQuery),
            URLQueryItem(name: "type", value: "repositories")
        ]
        return parts.url
    }

    static let all: [FrozenSignerCatalogApp] = [
        .init(name: "SideStore", subtitle: "On-device signing and app management.", category: .signing, icon: "signature", repository: "SideStore/SideStore", searchQuery: "SideStore iOS"),
        .init(name: "LiveContainer", subtitle: "Run compatible apps inside a container.", category: .signing, icon: "shippingbox.fill", repository: "LiveContainer/LiveContainer", searchQuery: "LiveContainer iOS"),
        .init(name: "Madeira", subtitle: "A JIT-focused app and signing workflow.", category: .signing, icon: "bolt.fill", repository: "willfaust/Madeira", searchQuery: "Madeira iOS"),
        .init(name: "Scarlet", subtitle: "Browse the project's public sources.", category: .signing, icon: "scribble.variable", repository: nil, searchQuery: "Scarlet iOS sideload"),
        .init(name: "E-Sign", subtitle: "Explore public releases and setup notes.", category: .signing, icon: "signature", repository: nil, searchQuery: "E-Sign iOS signing app"),
        .init(name: "StikDebug", subtitle: "Developer and device-side utilities.", category: .utilities, icon: "ladybug.fill", repository: nil, searchQuery: "StikDebug iOS"),
        .init(name: "YTPlus / YTLitePlus", subtitle: "YouTube client projects and release notes.", category: .media, icon: "play.rectangle.fill", repository: "YTLitePlus/YTLitePlus", searchQuery: "YTLitePlus iOS"),
        .init(name: "uYouEnhanced", subtitle: "Community YouTube client project.", category: .media, icon: "play.fill", repository: "qnblackcat/uYouPlus", searchQuery: "uYouEnhanced iOS"),
        .init(name: "EeveeSpotify", subtitle: "Browse community Spotify client sources.", category: .media, icon: "music.note", repository: nil, searchQuery: "EeveeSpotify iOS"),
        .init(name: "Twitch clients", subtitle: "Explore compatible client builds and tools.", category: .media, icon: "tv.fill", repository: nil, searchQuery: "Twitch iOS client IPA"),
        .init(name: "UTM", subtitle: "Virtual machines and emulation for iOS.", category: .emulators, icon: "desktopcomputer", repository: "utmapp/UTM", searchQuery: "UTM iOS"),
        .init(name: "PPSSPP", subtitle: "Play PSP games using your own game files.", category: .emulators, icon: "gamecontroller.fill", repository: "hrydgard/ppsspp", searchQuery: "PPSSPP iOS"),
        .init(name: "RetroArch", subtitle: "Multi-system emulation frontend.", category: .emulators, icon: "cpu.fill", repository: "libretro/RetroArch", searchQuery: "RetroArch iOS IPA"),
        .init(name: "PojavLauncher", subtitle: "Java edition launcher project for iOS.", category: .games, icon: "gamecontroller", repository: "PojavLauncherTeam/PojavLauncher_iOS", searchQuery: "PojavLauncher iOS"),
        .init(name: "Balatro ports", subtitle: "Browse community ports and project notes.", category: .games, icon: "suit.spade.fill", repository: nil, searchQuery: "Balatro iOS port"),
        .init(name: "PokeMMO", subtitle: "Explore the project's iOS client options.", category: .games, icon: "gamecontroller.fill", repository: nil, searchQuery: "PokeMMO iOS"),
        .init(name: "iTorrent", subtitle: "Find source information and compatible builds.", category: .utilities, icon: "arrow.down.to.line", repository: nil, searchQuery: "iTorrent iOS IPA"),
        .init(name: "qBitControl", subtitle: "Remote torrent-client control utilities.", category: .utilities, icon: "slider.horizontal.3", repository: nil, searchQuery: "qBitControl iOS"),
        .init(name: "DolphiniOS", subtitle: "GameCube and Wii emulator project.", category: .emulators, icon: "gamecontroller.fill", repository: nil, searchQuery: "DolphiniOS emulator"),
        .init(name: "Delta builds", subtitle: "Browse emulator sources and build instructions.", category: .emulators, icon: "gamecontroller", repository: nil, searchQuery: "Delta emulator iOS IPA")
    ]
}

private struct FrozenSignerRelease: Decodable {
    let name: String?
    let tag_name: String
    let html_url: String
    let assets: [FrozenSignerReleaseAsset]
}

private struct FrozenSignerReleaseAsset: Decodable, Identifiable {
    let name: String
    let browser_download_url: String
    let size: Int
    var id: String { browser_download_url }
}

/// A source-first installer catalogue embedded directly in Signer → Install.
/// Direct install actions only appear when GitHub's latest release actually
/// advertises IPA assets; discovery-only projects open their public source page.
struct FrozenSignerInstallCatalogView: View {
    @EnvironmentObject private var engine: Engine
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    @State private var searchText = ""
    @State private var selectedCategory: FrozenSignerCatalogCategory = .all
    @State private var releases: [String: FrozenSignerRelease] = [:]
    @State private var releaseMessages: [String: String] = [:]
    @State private var loadingRepositories = Set<String>()
    @State private var downloadingAsset: String?
    @State private var showFileImporter = false
    @State private var alertText = ""

    private var filteredApps: [FrozenSignerCatalogApp] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        return FrozenSignerCatalogApp.all.filter { app in
            (selectedCategory == .all || app.category == selectedCategory) &&
            (query.isEmpty ||
             app.name.localizedCaseInsensitiveContains(query) ||
             app.subtitle.localizedCaseInsensitiveContains(query) ||
             (app.repository?.localizedCaseInsensitiveContains(query) ?? false) ||
             app.searchQuery.localizedCaseInsensitiveContains(query))
        }
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        hero
                        searchField
                        categoryPicker

                        HStack(alignment: .firstTextBaseline) {
                            Text(selectedCategory == .all ? "APP CATALOG" : selectedCategory.rawValue.uppercased())
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(Theme.accent2)
                            Spacer()
                            Text("\(filteredApps.count) options")
                                .font(.system(size: 10, weight: .semibold, design: .rounded))
                                .foregroundStyle(.white.opacity(0.46))
                        }

                        LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                            ForEach(filteredApps) { app in
                                appCard(app)
                            }
                        }

                        Button {
                            showFileImporter = true
                        } label: {
                            HStack(spacing: 11) {
                                Image(systemName: "folder.badge.plus")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(Theme.accent2)
                                    .frame(width: 42, height: 42)
                                    .background(Theme.accent.opacity(0.18), in: RoundedRectangle(cornerRadius: 13))
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("Already have an IPA?")
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                    Text("Import any compatible IPA from Files into the existing signing flow.")
                                        .font(.system(size: 10, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.52))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                                Spacer(minLength: 2)
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.45))
                            }
                            .padding(13)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                            .overlay { RoundedRectangle(cornerRadius: 18, style: .continuous).strokeBorder(.white.opacity(0.09), lineWidth: 1) }
                        }
                        .buttonStyle(.plain)

                        Text("FrozenApps does not host these projects. Latest-release checks may find no IPA or may be blocked for some repositories. Only sources that publish an actual .ipa asset show a direct download action. Imported apps still use the existing Custom .ipa signing and install pipeline, and may require their own first-run setup.")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.43))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(18)
                    .frame(maxWidth: 760)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Install catalog")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        engine.installSource = .custom
                        await engine.importCustomIPA(from: url)
                        dismiss()
                    }
                case .failure(let error):
                    alertText = error.localizedDescription
                }
            }
            .alert("App catalog", isPresented: Binding(
                get: { !alertText.isEmpty },
                set: { if !$0 { alertText = "" } }
            )) {
                Button("OK", role: .cancel) { alertText = "" }
            } message: {
                Text(alertText)
            }
            .preferredColorScheme(.dark)
        }
        .task {
            let nativeInstallers = Set(["SideStore", "LiveContainer", "Madeira"])
            for app in FrozenSignerCatalogApp.all where app.repository != nil && !nativeInstallers.contains(app.name) {
                await loadRelease(for: app)
            }
        }
    }

    private var hero: some View {
        ZStack(alignment: .topTrailing) {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(LinearGradient(
                    colors: [Color(red: 0.98, green: 0.92, blue: 0.86), Color(red: 1.0, green: 0.975, blue: 0.92)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Circle()
                .fill(LinearGradient(
                    colors: [Color(red: 1.0, green: 0.59, blue: 0.27), Color(red: 1.0, green: 0.36, blue: 0.18)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .frame(width: 126, height: 126)
                .blur(radius: 1.5)
                .offset(x: 31, y: -17)
            Circle()
                .fill(.white.opacity(0.42))
                .frame(width: 88, height: 88)
                .blur(radius: 10)
                .offset(x: -15, y: 26)
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 6) {
                    Circle().fill(Color(red: 0.18, green: 0.76, blue: 0.39)).frame(width: 6, height: 6)
                    Circle().fill(Color(red: 0.96, green: 0.31, blue: 0.34)).frame(width: 6, height: 6)
                    Circle().fill(Color(red: 0.98, green: 0.68, blue: 0.22)).frame(width: 6, height: 6)
                    Spacer()
                    Text("FROZENAPPS / DISCOVER")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(Color.black.opacity(0.46))
                }
                Text("Make room for\nsomething new.")
                    .font(.system(size: 24, weight: .bold, design: .rounded))
                    .tracking(-0.6)
                    .foregroundStyle(Color(red: 0.14, green: 0.075, blue: 0.085))
                    .fixedSize(horizontal: false, vertical: true)
                Text("A curated place to find apps, builds and tools.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(Color.black.opacity(0.58))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(18)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(height: 174)
        .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(.white.opacity(0.55), lineWidth: 1)
        }
        .shadow(color: Theme.accent.opacity(0.14), radius: 20, x: 0, y: 8)
    }

    private var searchField: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Theme.accent2)
            TextField("Search signers, media, emulators…", text: $searchText)
                .font(.system(size: 12, weight: .medium))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            if !searchText.isEmpty {
                Button { searchText = "" } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.white.opacity(0.38))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 13)
        .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(.white.opacity(0.095), lineWidth: 1) }
    }

    private var categoryPicker: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 7) {
                ForEach(FrozenSignerCatalogCategory.allCases) { category in
                    Button {
                        withAnimation(.smooth(duration: 0.22)) { selectedCategory = category }
                    } label: {
                        Text(category.rawValue)
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(selectedCategory == category ? .white : .white.opacity(0.60))
                            .padding(.horizontal, 13)
                            .padding(.vertical, 9)
                            .background {
                                Capsule().fill(selectedCategory == category ? Theme.accent.opacity(0.86) : .white.opacity(0.045))
                            }
                            .overlay { Capsule().strokeBorder(selectedCategory == category ? Theme.accent2.opacity(0.45) : .white.opacity(0.07), lineWidth: 1) }
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func appCard(_ app: FrozenSignerCatalogApp) -> some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top, spacing: 7) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Theme.accent.opacity(0.96), Theme.accent2.opacity(0.73)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                        Image(systemName: app.icon)
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                    Spacer(minLength: 1)
                    Text(app.category.rawValue.uppercased())
                        .font(.system(size: 7, weight: .heavy, design: .rounded))
                        .tracking(0.55)
                        .foregroundStyle(Theme.accent2)
                        .lineLimit(1)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 5)
                        .background(Theme.accent.opacity(0.13), in: Capsule())
                }
                Text(app.name)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                Text(app.subtitle)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.50))
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                if ["SideStore", "LiveContainer", "Madeira"].contains(app.name) {
                    Button {
                        switch app.name {
                        case "SideStore": engine.installSource = .sideStore
                        case "LiveContainer": engine.installSource = .liveContainer
                        default: engine.installSource = .madeira
                        }
                        dismiss()
                    } label: {
                        actionButton("Use built-in installer", icon: "arrow.right.circle.fill")
                    }
                    Text("Keeps FrozenApps' native pairing, certificate handoff and install steps.")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.45))
                        .fixedSize(horizontal: false, vertical: true)
                } else if let release = releases[app.id] {
                    let ipaAssets = release.assets.filter {
                        $0.name.lowercased().hasSuffix(".ipa") &&
                        !$0.name.localizedCaseInsensitiveContains("visionos") &&
                        !$0.name.localizedCaseInsensitiveContains("tvos")
                    }
                    if !ipaAssets.isEmpty {
                        if ipaAssets.count == 1, let asset = ipaAssets.first {
                            Button {
                                Task { await downloadAndImport(asset, app: app) }
                            } label: {
                                actionButton("Download & prepare", icon: "arrow.down.to.line")
                            }
                            .disabled(downloadingAsset != nil)
                        } else {
                            Menu {
                                ForEach(ipaAssets) { asset in
                                    Button {
                                        Task { await downloadAndImport(asset, app: app) }
                                    } label: {
                                        Text("\(asset.name) · \(ByteCountFormatter.string(fromByteCount: Int64(asset.size), countStyle: .file))")
                                    }
                                }
                            } label: {
                                actionButton("\(ipaAssets.count) IPA builds", icon: "arrow.down.to.line")
                            }
                            .disabled(downloadingAsset != nil)
                        }
                        Text("Release \(release.tag_name)")
                            .font(.system(size: 8, weight: .medium, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.38))
                            .lineLimit(1)
                    } else {
                        Button {
                            if let url = URL(string: release.html_url) { openURL(url) }
                        } label: {
                            actionButton("View release", icon: "arrow.up.right")
                        }
                        Text("No .ipa asset in the latest release.")
                            .font(.system(size: 8, weight: .medium))
                            .foregroundStyle(.white.opacity(0.42))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                } else if loadingRepositories.contains(app.id) {
                    HStack(spacing: 6) {
                        ProgressView().controlSize(.small).tint(Theme.accent2)
                        Text("Checking latest release…")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(0.46))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 7)
                } else if app.repository != nil {
                    Button { Task { await loadRelease(for: app) } } label: {
                        actionButton("Check releases", icon: "arrow.clockwise")
                    }
                } else {
                    Button {
                        if let url = app.searchURL { openURL(url) }
                    } label: {
                        actionButton("Find source", icon: "arrow.up.right")
                    }
                }

                if let message = releaseMessages[app.id], releases[app.id] == nil {
                    Text(message)
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.orange.opacity(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let url = app.repositoryURL {
                    Button { openURL(url) } label: {
                        HStack(spacing: 4) {
                            Text("Open source")
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.43))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func actionButton(_ title: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .bold))
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .rounded))
                .lineLimit(2)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 9)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.accent.opacity(0.27), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(Theme.accent2.opacity(0.22), lineWidth: 1) }
        .contentShape(RoundedRectangle(cornerRadius: 11, style: .continuous))
    }

    @MainActor
    private func loadRelease(for app: FrozenSignerCatalogApp) async {
        guard let repository = app.repository, !loadingRepositories.contains(app.id) else { return }
        loadingRepositories.insert(app.id)
        defer { loadingRepositories.remove(app.id) }
        do {
            var request = URLRequest(url: URL(string: "https://api.github.com/repos/\(repository)/releases/latest")!)
            request.timeoutInterval = 12
            request.setValue("FrozenApps", forHTTPHeaderField: "User-Agent")
            request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else { throw URLError(.badServerResponse) }
            guard http.statusCode == 200 else {
                throw NSError(domain: "FrozenSignerCatalog", code: http.statusCode,
                              userInfo: [NSLocalizedDescriptionKey: http.statusCode == 404
                                  ? "No public latest release."
                                  : "GitHub returned HTTP \(http.statusCode)."])
            }
            releases[app.id] = try JSONDecoder().decode(FrozenSignerRelease.self, from: data)
            releaseMessages[app.id] = nil
        } catch {
            releaseMessages[app.id] = error.localizedDescription
        }
    }

    @MainActor
    private func downloadAndImport(_ asset: FrozenSignerReleaseAsset, app: FrozenSignerCatalogApp) async {
        guard downloadingAsset == nil else { return }
        guard let url = URL(string: asset.browser_download_url) else {
            alertText = "The release returned an invalid download URL."
            return
        }
        let host = (url.host ?? "").lowercased()
        guard host == "github.com" || host == "objects.githubusercontent.com" || host.hasSuffix(".githubusercontent.com") else {
            alertText = "Download blocked because the IPA asset is not hosted on a trusted GitHub domain."
            return
        }

        downloadingAsset = asset.id
        defer { downloadingAsset = nil }
        do {
            var request = URLRequest(url: url)
            request.timeoutInterval = 90
            request.setValue("FrozenApps", forHTTPHeaderField: "User-Agent")
            let (temporary, response) = try await URLSession.shared.download(for: request)
            guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
                throw URLError(.badServerResponse)
            }

            let folder = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("FrozenAppsCatalogImports", isDirectory: true)
            try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
            let safeName = asset.name.replacingOccurrences(of: "/", with: "_")
            let destination = folder.appendingPathComponent("\(UUID().uuidString.prefix(6))-\(safeName)")
            try FileManager.default.moveItem(at: temporary, to: destination)

            let previousName = engine.customIPAName
            engine.installSource = .custom
            await engine.importCustomIPA(from: destination)
            if let importedName = engine.customIPAName, importedName != previousName {
                dismiss()
            } else {
                alertText = engine.lastError ?? "The downloaded file was not accepted as an IPA. You can open the release or choose a different build."
            }
        } catch {
            alertText = "Could not download \(asset.name): \(error.localizedDescription)"
        }
    }
}
