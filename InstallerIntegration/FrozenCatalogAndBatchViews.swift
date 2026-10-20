import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

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
        .init(repository: "hrydgard/ppsspp"),
        .init(repository: "PojavLauncherTeam/PojavLauncher_iOS"),
        .init(repository: "YTLitePlus/YTLitePlus"),
        .init(repository: "qnblackcat/uYouPlus"),
        .init(repository: "libretro/RetroArch")
    ]
}


private struct FrozenCatalogDiscovery: Identifiable {
    let name: String
    let query: String
    let subtitle: String
    var id: String { name }

    static let projects: [FrozenCatalogDiscovery] = [
        .init(name: "StickDebug", query: "StickDebug", subtitle: "Developer and device utilities"),
        .init(name: "Scarlet", query: "Scarlet iOS sideload", subtitle: "Third-party signing/distribution project"),
        .init(name: "E-Sign", query: "E-Sign iOS", subtitle: "Third-party signing app"),
        .init(name: "YTPlus", query: "YTPlus iOS", subtitle: "YouTube client project"),
        .init(name: "uYouEnhanced", query: "uYouEnhanced", subtitle: "YouTube client project"),
        .init(name: "EeveeSpotify", query: "EeveeSpotify", subtitle: "Spotify client project"),
        .init(name: "Twitch Adblock", query: "Twitch adblock iOS", subtitle: "Community client project"),
        .init(name: "Balatro", query: "Balatro iOS port", subtitle: "Game and port discovery"),
        .init(name: "PokeMMO", query: "PokeMMO iOS", subtitle: "Game client discovery"),
        .init(name: "iTorrent", query: "iTorrent iOS", subtitle: "Torrent client discovery"),
        .init(name: "qBitControl", query: "qBitControl", subtitle: "Remote torrent control"),
        .init(name: "Eclipse / emulator builds", query: "iOS emulator IPA", subtitle: "Emulation and gaming")
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
    @State private var sourceBeingEdited: FrozenCatalogSource?
    @State private var sourceSort = "Name"
    @State private var sourceFilter = "All sources"
    @State private var sourceFeedback: String?
    @State private var isRefreshingAll = false
    @State private var sourcePendingRemoval: FrozenCatalogSource?
    @State private var showRemoveSourceConfirmation = false
    @AppStorage("frozenApps.catalog.favorites.v1") private var favoriteSourceIDsRaw = ""

    private var favoriteSourceIDs: Set<String> {
        Set(favoriteSourceIDsRaw.split(separator: "\n").map { String($0) })
    }

    private var visibleSources: [FrozenCatalogSource] {
        let query = search.trimmingCharacters(in: .whitespacesAndNewlines)
        var result = sources.filter {
            query.isEmpty || $0.repository.localizedCaseInsensitiveContains(query)
        }

        switch sourceFilter {
        case "Favorites":
            result = result.filter { favoriteSourceIDs.contains($0.id) }
        case "Has IPA":
            result = result.filter { source in
                guard let release = releases[source.id] else { return false }
                return release.assets.contains { $0.name.lowercased().hasSuffix(".ipa") }
            }
        case "No IPA":
            result = result.filter { source in
                guard let release = releases[source.id] else { return false }
                return !release.assets.contains { $0.name.lowercased().hasSuffix(".ipa") }
            }
        case "Needs attention":
            result = result.filter { source in
                guard let message = messages[source.id] else { return false }
                return !message.hasPrefix("Saved ")
            }
        case "Not checked":
            result = result.filter {
                releases[$0.id] == nil && messages[$0.id] == nil && !loading.contains($0.id)
            }
        default:
            break
        }

        switch sourceSort {
        case "IPA count":
            result.sort {
                let leftCount = ipaAssetCount(for: $0)
                let rightCount = ipaAssetCount(for: $1)
                if leftCount != rightCount { return leftCount > rightCount }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        case "Status":
            result.sort {
                let leftRank = sourceStatusRank($0)
                let rightRank = sourceStatusRank($1)
                if leftRank != rightRank { return leftRank < rightRank }
                return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
            }
        default:
            result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        }
        return result
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
                    .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(LinearGradient(colors: [.white.opacity(0.26), Theme.accent.opacity(0.18), .white.opacity(0.045)], startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1) }
                    .shadow(color: Theme.accent.opacity(0.08), radius: 12, x: 0, y: 5)

                    HStack(spacing: 8) {
                        Text("SOURCES · \(sources.count)").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.2).foregroundStyle(Theme.accent2)
                        Spacer(minLength: 4)
                        Button {
                            Task { await refreshAllSources() }
                        } label: {
                            if isRefreshingAll {
                                ProgressView().tint(Theme.accent2)
                            } else {
                                Label("Refresh all", systemImage: "arrow.clockwise")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(Theme.accent2)
                        .disabled(isRefreshingAll || sources.isEmpty)
                        Button {
                            sourceBeingEdited = nil
                            newRepository = ""
                            showAddSource = true
                        } label: {
                            Label("Add source", systemImage: "plus")
                                .font(.system(size: 10, weight: .bold, design: .rounded))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.white)
                    }

                    Menu {
                        Section("Sort sources") {
                            Picker("Sort by", selection: $sourceSort) {
                                Text("Name").tag("Name")
                                Text("IPA count").tag("IPA count")
                                Text("Status").tag("Status")
                            }
                        }
                        Section("Filter sources") {
                            Picker("Show", selection: $sourceFilter) {
                                Text("All sources").tag("All sources")
                                Text("Favorites").tag("Favorites")
                                Text("Has IPA").tag("Has IPA")
                                Text("No IPA").tag("No IPA")
                                Text("Needs attention").tag("Needs attention")
                                Text("Not checked").tag("Not checked")
                            }
                        }
                    } label: {
                        FrozenGlassMenuLabel(
                            title: sourceFilter == "All sources" ? "Filter & sort" : sourceFilter,
                            icon: "slider.horizontal.3",
                            subtitle: "Sort: \(sourceSort)"
                        )
                    }
                    .buttonStyle(FrozenGlassPressStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)

                    if let sourceFeedback {
                        Label(sourceFeedback,
                              systemImage: sourceFeedbackIsError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(sourceFeedbackIsError ? .orange : Theme.accent2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }

                    if visibleSources.isEmpty {
                        PanelCard {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("No matching sources", systemImage: "line.3.horizontal.decrease.circle")
                                    .font(.system(size: 13, weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                Text("Try a different search or source filter. You can always return to All sources.")
                                    .font(.system(size: 11, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.53))
                                Button("Reset search and filters") {
                                    search = ""
                                    sourceFilter = "All sources"
                                    sourceSort = "Name"
                                }
                                .font(.system(size: 11, weight: .bold, design: .rounded))
                                .buttonStyle(.plain)
                                .foregroundStyle(Theme.accent2)
                            }
                        }
                    } else {
                        ForEach(visibleSources) { source in
                            sourceCard(source)
                        }
                    }

                    HStack {
                        Text("APP DISCOVERY").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.5).foregroundStyle(Theme.accent2)
                        Spacer()
                        Text("GitHub search").font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.4))
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 9), GridItem(.flexible(), spacing: 9)], spacing: 9) {
                        ForEach(FrozenCatalogDiscovery.projects) { item in
                            Button {
                                var components = URLComponents(string: "https://github.com/search")!
                                components.queryItems = [URLQueryItem(name: "q", value: item.query), URLQueryItem(name: "type", value: "repositories")]
                                if let url = components.url { openURL(url) }
                            } label: {
                                VStack(alignment: .leading, spacing: 7) {
                                    HStack {
                                        Image(systemName: "magnifyingglass").foregroundStyle(Theme.accent2)
                                        Spacer()
                                        Image(systemName: "arrow.up.right").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.4))
                                    }
                                    Text(item.name).font(.system(size: 11, weight: .bold, design: .rounded)).foregroundStyle(.white)
                                    Text(item.subtitle).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.48)).lineLimit(2)
                                }
                                .padding(12).frame(maxWidth: .infinity, minHeight: 78, alignment: .leading)
                                .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 13))
                                .overlay { RoundedRectangle(cornerRadius: 13).strokeBorder(.white.opacity(0.07)) }
                            }
                            .buttonStyle(.plain)
                        }
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
        .task { restoreSources() }
        .alert(Text(sourceBeingEdited == nil ? "Add GitHub source" : "Edit GitHub source"), isPresented: $showAddSource) {
            TextField("owner/repository", text: $newRepository)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button("Cancel", role: .cancel) {
                newRepository = ""
                sourceBeingEdited = nil
            }
            Button {
                addSource()
            } label: {
                Text(sourceBeingEdited == nil ? "Add" : "Save changes")
            }
        } message: {
            Text(sourceBeingEdited == nil
                 ? "Enter a public GitHub repository as owner/repository. FrozenApps checks its latest public release for IPA assets."
                 : "Update the repository used by this custom source. Existing downloaded IPA files will remain in your library.")
        }
        .confirmationDialog("Remove custom source?", isPresented: $showRemoveSourceConfirmation, titleVisibility: .visible) {
            Button("Remove source", role: .destructive) {
                if let source = sourcePendingRemoval { removeSource(source) }
                sourcePendingRemoval = nil
            }
            Button("Cancel", role: .cancel) { sourcePendingRemoval = nil }
        } message: {
            Text("This removes the repository from your saved source list. IPA files already downloaded to your library will not be deleted.")
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
                        Text("FROZENAPPS  /  APP DISCOVERY")
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

                    Button {
                        toggleFavorite(source)
                    } label: {
                        Image(systemName: favoriteSourceIDs.contains(source.id) ? "star.fill" : "star")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(favoriteSourceIDs.contains(source.id) ? Theme.accent2 : .white.opacity(0.62))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.055), in: Circle())
                    }
                    .buttonStyle(FrozenGlassPressStyle())
                    .accessibilityLabel(favoriteSourceIDs.contains(source.id) ? "Unpin \(source.title)" : "Pin \(source.title)")

                    Menu {
                        if let url = source.url {
                            Button("Open GitHub", systemImage: "arrow.up.right.square") { openURL(url) }
                        }
                        Button("Copy repository", systemImage: "doc.on.doc") {
                            UIPasteboard.general.string = source.repository
                            sourceFeedback = "Copied \(source.repository)."
                        }
                        if !FrozenCatalogSource.builtIn.contains(source) {
                            Button("Edit source", systemImage: "pencil") {
                                sourceBeingEdited = source
                                newRepository = source.repository
                                showAddSource = true
                            }
                            Divider()
                            Button("Remove source", systemImage: "trash", role: .destructive) {
                                sourcePendingRemoval = source
                                showRemoveSourceConfirmation = true
                            }
                        }
                    } label: {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .bold))
                            .foregroundStyle(.white.opacity(0.72))
                            .frame(width: 32, height: 32)
                            .background(.white.opacity(0.055), in: Circle())
                    }
                    .buttonStyle(FrozenGlassPressStyle())
                    .accessibilityLabel("More actions for \(source.title)")
                }

                HStack(spacing: 6) {
                    Circle().fill(sourceStatusTint(source)).frame(width: 6, height: 6)
                    Text(sourceStatusTitle(source))
                        .font(.system(size: 9, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.58))
                    Spacer()
                    if favoriteSourceIDs.contains(source.id) {
                        Text("PINNED")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .tracking(1)
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

    private var sourceFeedbackIsError: Bool {
        guard let sourceFeedback else { return false }
        return sourceFeedback.localizedCaseInsensitiveContains("already")
            || sourceFeedback.localizedCaseInsensitiveContains("invalid")
            || sourceFeedback.localizedCaseInsensitiveContains("must be")
            || sourceFeedback.localizedCaseInsensitiveContains("could not")
    }

    private func ipaAssetCount(for source: FrozenCatalogSource) -> Int {
        releases[source.id]?.assets.filter { $0.name.lowercased().hasSuffix(".ipa") }.count ?? 0
    }

    private func sourceStatusRank(_ source: FrozenCatalogSource) -> Int {
        if loading.contains(source.id) { return 0 }
        if let message = messages[source.id], !message.hasPrefix("Saved ") { return 1 }
        guard let release = releases[source.id] else { return 4 }
        return release.assets.contains { $0.name.lowercased().hasSuffix(".ipa") } ? 2 : 3
    }

    private func sourceStatusTitle(_ source: FrozenCatalogSource) -> String {
        if loading.contains(source.id) { return "CHECKING RELEASE" }
        if let message = messages[source.id], !message.hasPrefix("Saved ") { return "NEEDS ATTENTION" }
        guard releases[source.id] != nil else { return "NOT CHECKED" }
        let count = ipaAssetCount(for: source)
        return count > 0 ? "\(count) IPA ASSET\(count == 1 ? "" : "S")" : "NO IPA IN LATEST RELEASE"
    }

    private func sourceStatusTint(_ source: FrozenCatalogSource) -> Color {
        if loading.contains(source.id) { return Theme.accent2 }
        if let message = messages[source.id], !message.hasPrefix("Saved ") { return .orange }
        guard releases[source.id] != nil else { return .white.opacity(0.45) }
        return ipaAssetCount(for: source) > 0 ? .green : .white.opacity(0.52)
    }

    private func toggleFavorite(_ source: FrozenCatalogSource) {
        var favorites = favoriteSourceIDs
        if favorites.contains(source.id) {
            favorites.remove(source.id)
            sourceFeedback = "Unpinned \(source.title)."
        } else {
            favorites.insert(source.id)
            sourceFeedback = "Pinned \(source.title)."
        }
        favoriteSourceIDsRaw = favorites.sorted().joined(separator: "\n")
    }

    private func persistSources() {
        let customSources = sources.filter { !FrozenCatalogSource.builtIn.contains($0) }
        guard let data = try? JSONEncoder().encode(customSources) else { return }
        savedSources = String(decoding: data, as: UTF8.self)
    }

    private func restoreSources() {
        guard let data = savedSources.data(using: .utf8),
              let stored = try? JSONDecoder().decode([FrozenCatalogSource].self, from: data) else { return }
        sources = Array(Dictionary((FrozenCatalogSource.builtIn + stored).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first }).values)
            .sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
    }

    private func addSource() {
        sourceFeedback = nil
        let input = newRepository.trimmingCharacters(in: .whitespacesAndNewlines)
        var normalized = input
        if normalized.hasPrefix("https://github.com/") {
            normalized = String(normalized.dropFirst("https://github.com/".count))
        } else if normalized.contains("://") || normalized.hasPrefix("www.") {
            sourceFeedback = "Invalid source. Enter owner/repository or a public https://github.com/owner/repository URL."
            return
        }
        normalized = normalized.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let parts = normalized.split(separator: "/")
        let allowed = CharacterSet(charactersIn: "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789-_.")
        guard parts.count == 2,
              parts.allSatisfy({ !$0.isEmpty && $0.unicodeScalars.allSatisfy { allowed.contains($0) } }) else {
            sourceFeedback = "Invalid source. Use only a public GitHub owner/repository path."
            return
        }

        let source = FrozenCatalogSource(repository: normalized)
        guard !FrozenCatalogSource.builtIn.contains(source),
              !sources.contains(where: { $0.id == source.id && $0.id != sourceBeingEdited?.id }) else {
            sourceFeedback = "\(source.repository) is already in your sources, or is a built-in source."
            return
        }

        if let original = sourceBeingEdited {
            if original.id != source.id {
                releases[original.id] = nil
                messages[original.id] = nil
                var favorites = favoriteSourceIDs
                if favorites.remove(original.id) != nil { favorites.insert(source.id) }
                favoriteSourceIDsRaw = favorites.sorted().joined(separator: "\n")
            }
            sources.removeAll { $0.id == original.id }
            sourceFeedback = "Updated \(source.repository). Checking its latest public release…"
        } else {
            sourceFeedback = "Added \(source.repository). Checking its latest public release…"
        }

        sources.append(source)
        sources.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        persistSources()
        newRepository = ""
        sourceBeingEdited = nil
        Task { await loadRelease(for: source) }
    }

    private func removeSource(_ source: FrozenCatalogSource) {
        guard !FrozenCatalogSource.builtIn.contains(source) else { return }
        sources.removeAll { $0.id == source.id }
        releases[source.id] = nil
        messages[source.id] = nil
        var favorites = favoriteSourceIDs
        favorites.remove(source.id)
        favoriteSourceIDsRaw = favorites.sorted().joined(separator: "\n")
        persistSources()
        sourceFeedback = "Removed \(source.repository). Existing downloaded IPA files were kept."
    }

    @MainActor
    private func refreshAllSources() async {
        guard !isRefreshingAll else { return }
        isRefreshingAll = true
        defer { isRefreshingAll = false }
        for source in sources {
            await loadRelease(for: source)
        }
        sourceFeedback = "Finished checking \(sources.count) source(s). Review any source marked Needs attention."
    }

    @MainActor
    private func loadRelease(for source: FrozenCatalogSource) async {
        guard !loading.contains(source.id) else { return }
        loading.insert(source.id)
        messages[source.id] = nil
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
    @State private var retryFailedPreflightOnce = true
    @AppStorage("frozenApps.batch.queue.v1") private var persistedQueue = ""

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
                            Toggle("Retry a failed preflight once", isOn: $retryFailedPreflightOnce)
                                .font(.system(size: 11, weight: .medium)).tint(Theme.accent2)
                                .foregroundStyle(.white.opacity(0.78))
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
        .onAppear { restoreQueue() }
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
                      allowsMultipleSelection: true) { result in
            switch result {
            case .success(let urls):
                selectedFiles = urls.filter { $0.pathExtension.lowercased() == "ipa" }
                reports = []
                queue = []
                persistQueue()
            case .failure(let error):
                reports = ["Picker failed: \(error.localizedDescription)"]
            }
        }
        .confirmationDialog("Clear selected files and reports?", isPresented: $confirmation, titleVisibility: .visible) {
            Button("Clear everything", role: .destructive) {
                selectedFiles = []
                reports = []
                queue = []
                persistQueue()
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
            var report = inspectFile(file)
            if report.hasPrefix("FAILED PRECHECK") && retryFailedPreflightOnce {
                report = inspectFile(file)
            }
            reports.append(report)
            if report.hasPrefix("READY FOR IMPORT") {
                queue.append(file.lastPathComponent)
            }
        }
        persistQueue()
    }

    private func inspectFile(_ file: URL) -> String {
        let scoped = file.startAccessingSecurityScopedResource()
        defer { if scoped { file.stopAccessingSecurityScopedResource() } }
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: file.path)
            let size = (attributes[.size] as? NSNumber)?.int64Value ?? 0
            let isReadable = FileManager.default.isReadableFile(atPath: file.path)
            guard isReadable, size > 0 else { throw NSError(domain: "FrozenBatch", code: 1, userInfo: [NSLocalizedDescriptionKey: "File is empty or unreadable."]) }
            guard file.pathExtension.lowercased() == "ipa" else { throw NSError(domain: "FrozenBatch", code: 2, userInfo: [NSLocalizedDescriptionKey: "Not an IPA extension."]) }
            return "READY FOR IMPORT · \(file.lastPathComponent)\nSize: \(ByteCountFormatter.string(fromByteCount: size, countStyle: .file))\nArchive contents and app metadata must still pass FrozenApps Library validation."
        } catch {
            return "FAILED PRECHECK · \(file.lastPathComponent)\n\(error.localizedDescription)"
        }
    }

    private func restoreQueue() {
        guard let data = persistedQueue.data(using: .utf8),
              let restored = try? JSONDecoder().decode([String].self, from: data) else { return }
        queue = restored
    }

    private func persistQueue() {
        guard let data = try? JSONEncoder().encode(queue) else { return }
        persistedQueue = String(decoding: data, as: UTF8.self)
    }
}
