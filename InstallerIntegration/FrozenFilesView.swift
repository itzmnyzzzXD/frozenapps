import Foundation
import SwiftUI
import UniformTypeIdentifiers
import UIKit

private enum FrozenLibrarySort: String, CaseIterable, Identifiable {
    case recent = "Recently added"
    case name = "Name"
    case largest = "Largest first"

    var id: String { rawValue }
}

private struct FrozenLibraryItem: Identifiable, Equatable {
    let url: URL
    let size: Int
    let modified: Date?

    var id: String { url.path }
    var fileName: String { url.lastPathComponent }
    var sizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(size), countStyle: .file)
    }
}

private enum FrozenLibraryStore {
    enum ImportError: LocalizedError {
        case notIPA
        case invalidArchive
        case unreadableAppMetadata

        var errorDescription: String? {
            switch self {
            case .notIPA: return "Choose a file with the .ipa extension."
            case .invalidArchive: return "This file does not look like a complete IPA package."
            case .unreadableAppMetadata:
                return "The archive has no readable Payload/App.app/Info.plist. ZIP64 archives are not supported by this inspector."
            }
        }
    }

    static var directory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("FrozenApps Library", isDirectory: true)
    }

    static func scan() -> [FrozenLibraryItem] {
        let manager = FileManager.default
        try? manager.createDirectory(at: directory, withIntermediateDirectories: true)
        let urls = (try? manager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles]
        )) ?? []

        return urls.compactMap { url in
            guard url.pathExtension.lowercased() == "ipa",
                  let values = try? url.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                  values.isRegularFile == true else { return nil }
            return FrozenLibraryItem(url: url,
                                     size: values.fileSize ?? 0,
                                     modified: values.contentModificationDate)
        }
        .sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
    }

    /// Copies an IPA into its own library directory, preserving previous files.
    /// The original is staged and checked before it is moved into the library.
    static func importIPA(from source: URL) throws -> URL {
        guard source.pathExtension.lowercased() == "ipa" else { throw ImportError.notIPA }

        let manager = FileManager.default
        try manager.createDirectory(at: directory, withIntermediateDirectories: true)

        let scoped = source.startAccessingSecurityScopedResource()
        defer { if scoped { source.stopAccessingSecurityScopedResource() } }
        try? manager.startDownloadingUbiquitousItem(at: source)

        let staging = manager.temporaryDirectory
            .appendingPathComponent("FrozenApps-ipa-\(UUID().uuidString)", isDirectory: true)
        try manager.createDirectory(at: staging, withIntermediateDirectories: true)
        defer { try? manager.removeItem(at: staging) }

        let staged = staging.appendingPathComponent(source.lastPathComponent)
        var copyError: Error?
        var coordinationError: NSError?
        NSFileCoordinator().coordinate(readingItemAt: source, options: [], error: &coordinationError) { readableURL in
            do {
                try manager.copyItem(at: readableURL, to: staged)
            } catch {
                copyError = error
            }
        }
        if let copyError { throw copyError }
        if let coordinationError { throw coordinationError }
        guard IPALibrary.looksLikeIPA(staged) else { throw ImportError.invalidArchive }
        guard IPALibrary.appInfo(at: staged) != nil else { throw ImportError.unreadableAppMetadata }

        let destination = uniqueDestination(named: source.deletingPathExtension().lastPathComponent,
                                           in: directory,
                                           fileManager: manager)
        try manager.moveItem(at: staged, to: destination)
        return destination
    }

    static func delete(_ item: FrozenLibraryItem) throws {
        try FileManager.default.removeItem(at: item.url)
    }

    private static func uniqueDestination(named baseName: String, in directory: URL,
                                          fileManager: FileManager) -> URL {
        let safeBase = baseName.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalized = safeBase.isEmpty ? "Imported App" : safeBase
        var candidate = directory.appendingPathComponent(normalized).appendingPathExtension("ipa")
        var counter = 2
        while fileManager.fileExists(atPath: candidate.path) {
            candidate = directory.appendingPathComponent("\(normalized) (\(counter))").appendingPathExtension("ipa")
            counter += 1
        }
        return candidate
    }
}

/// FrozenApps' persistent IPA library. Imports are kept separately from the
/// signer's temporary custom-IPA slot, so importing multiple files never
/// overwrites the previous library entries.
struct FrozenFilesView: View {
    @EnvironmentObject private var engine: Engine
    @StateObject private var downloads = DownloadsManager()
    @State private var libraryItems: [FrozenLibraryItem] = []
    @State private var showImporter = false
    @State private var isImporting = false
    @State private var importProgress = 0.0
    @State private var importStatus = ""
    @State private var sortOrder: FrozenLibrarySort = .recent
    @State private var loadingID: String?
    @State private var message: String?
    @State private var importError: String?
    @State private var pendingDelete: DeleteTarget?
    @State private var inspectorItem: FrozenLibraryItem?
    @State private var searchText = ""

    private enum DeleteTarget: Identifiable {
        case library(FrozenLibraryItem)
        case download(DownloadedIPA)

        var id: String {
            switch self {
            case .library(let item): return "library:\(item.id)"
            case .download(let item): return "download:\(item.id)"
            }
        }

        var fileName: String {
            switch self {
            case .library(let item): return item.fileName
            case .download(let item): return item.fileName
            }
        }
    }

    private var normalizedSearch: String {
        searchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var visibleLibraryItems: [FrozenLibraryItem] {
        let filtered = normalizedSearch.isEmpty
            ? libraryItems
            : libraryItems.filter { $0.fileName.localizedCaseInsensitiveContains(normalizedSearch) }
        switch sortOrder {
        case .recent:
            return filtered.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        case .name:
            return filtered.sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        case .largest:
            return filtered.sorted { $0.size > $1.size }
        }
    }

    private var visibleDownloads: [DownloadedIPA] {
        let filtered = normalizedSearch.isEmpty
            ? downloads.downloads
            : downloads.downloads.filter {
                $0.fileName.localizedCaseInsensitiveContains(normalizedSearch)
                || $0.displayName.localizedCaseInsensitiveContains(normalizedSearch)
            }
        switch sortOrder {
        case .recent:
            return filtered.sorted { ($0.modified ?? .distantPast) > ($1.modified ?? .distantPast) }
        case .name:
            return filtered.sorted { $0.fileName.localizedCaseInsensitiveCompare($1.fileName) == .orderedAscending }
        case .largest:
            return filtered.sorted { $0.size > $1.size }
        }
    }

    private var totalFiles: Int { downloads.downloads.count + libraryItems.count }
    private var totalBytes: Int {
        downloads.downloads.reduce(0) { $0 + $1.size } + libraryItems.reduce(0) { $0 + $1.size }
    }
    private var totalSizeText: String {
        ByteCountFormatter.string(fromByteCount: Int64(totalBytes), countStyle: .file)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Your files")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Keep multiple IPA packages here. Choose one to load into Signer when you are ready to install it.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        summaryTile(value: "\(totalFiles)", label: "IPA files", icon: "doc.zipper")
                        summaryTile(value: totalSizeText, label: "Storage used", icon: "externaldrive")
                    }

                    HStack(spacing: 10) {
                        Label("Sort files", systemImage: "arrow.up.arrow.down")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Menu {
                            Picker("Sort order", selection: $sortOrder) {
                                ForEach(FrozenLibrarySort.allCases) { order in
                                    Text(order.rawValue).tag(order)
                                }
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Text(sortOrder.rawValue)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .bold))
                            }
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(Theme.accent2)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 9)
                            .background(Theme.accent.opacity(0.10), in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }

                    Button { showImporter = true } label: {
                        HStack(spacing: 9) {
                            if isImporting { ProgressView().tint(.black) }
                            else { Image(systemName: "plus") }
                            Text(isImporting ? "Importing IPA files…" : "Import IPA from Files")
                        }
                        .font(.system(size: 15, weight: .semibold))
                        .frame(maxWidth: .infinity)
                        .padding(16)
                        .foregroundStyle(.black)
                        .background(Theme.brand, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .disabled(isImporting)

                    if isImporting {
                        VStack(alignment: .leading, spacing: 7) {
                            ProgressView(value: importProgress)
                                .tint(Theme.accent)
                            Text(importStatus.isEmpty ? "Checking selected files…" : importStatus)
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                        .padding(13)
                        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(13)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if totalFiles == 0 {
                        emptyState
                    } else if visibleLibraryItems.isEmpty && visibleDownloads.isEmpty {
                        noResultsState
                    } else {
                        if !visibleLibraryItems.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("MY IPA LIBRARY")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3)

                                ForEach(visibleLibraryItems) { item in
                                    fileRow(name: item.fileName,
                                            detail: "\(item.sizeText) · Saved locally",
                                            icon: "doc.badge.plus",
                                            identity: item.id,
                                            isLoading: loadingID == item.id,
                                            inspectAction: { inspectorItem = item },
                                            useAction: { loadForSigning(url: item.url, name: item.fileName, id: item.id) },
                                            deleteAction: { pendingDelete = .library(item) })
                                }
                            }
                        }

                        if !visibleDownloads.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SIGNER DOWNLOADS")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3)

                                ForEach(visibleDownloads) { item in
                                    fileRow(name: item.displayName,
                                            detail: "\(item.sizeText) · \(item.fileName)",
                                            icon: item.isImported ? "doc.badge.plus" : "doc.zipper",
                                            identity: item.id,
                                            isLoading: loadingID == item.id,
                                            inspectAction: {
                                                inspectorItem = FrozenLibraryItem(url: item.url, size: item.size, modified: item.modified)
                                            },
                                            useAction: { loadForSigning(url: item.url, name: item.fileName, id: item.id) },
                                            deleteAction: { pendingDelete = .download(item) })
                                }
                            }
                        }
                    }

                    Text("Imports are stored in this app's Documents folder under FrozenApps Library. Loading a file for signing creates a separate working copy.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 3)
                }
                .padding(20)
                .padding(.bottom, 20)
            }
            .scrollIndicators(.hidden)
            .background(AppBackground())
            .navigationTitle("Files")
            .navigationBarTitleDisplayMode(.inline)
            .refreshable { refresh() }
            .searchable(text: $searchText,
                        placement: .navigationBarDrawer(displayMode: .always),
                        prompt: "Search IPA files")
        }
        .sheet(item: $inspectorItem) { item in
            FrozenIPAInspectorView(item: item)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .fileImporter(
            isPresented: $showImporter,
            allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data],
            allowsMultipleSelection: true
        ) { result in
            switch result {
            case .failure(let error):
                importError = error.localizedDescription
            case .success(let urls):
                guard !urls.isEmpty else { return }
                isImporting = true
                importProgress = 0
                importStatus = "Preparing selected files…"
                message = nil
                Task.detached(priority: .userInitiated) {
                    var imported = 0
                    var failures: [String] = []
                    let total = urls.count
                    for (index, url) in urls.enumerated() {
                        await MainActor.run {
                            importStatus = "Validating \(index + 1) of \(total): \(url.lastPathComponent)"
                            importProgress = Double(index) / Double(max(total, 1))
                        }
                        do {
                            _ = try FrozenLibraryStore.importIPA(from: url)
                            imported += 1
                        } catch {
                            failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        }
                        await MainActor.run {
                            importProgress = Double(index + 1) / Double(max(total, 1))
                        }
                    }
                    await MainActor.run {
                        isImporting = false
                        importProgress = 1
                        importStatus = ""
                        refresh()
                        if failures.isEmpty {
                            message = "Imported \(imported) IPA file(s). They are saved separately from the Signer working copy."
                        } else {
                            let prefix = imported > 0 ? "Imported \(imported). " : ""
                            importError = prefix + failures.joined(separator: "\n")
                        }
                    }
                }
            }
        }
        .alert("Import failed", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "The selected file could not be imported.")
        }
        .confirmationDialog("Delete this IPA?", isPresented: Binding(
            get: { pendingDelete != nil },
            set: { if !$0 { pendingDelete = nil } }
        ), titleVisibility: .visible) {
            Button("Delete", role: .destructive) { deletePending() }
            Button("Cancel", role: .cancel) { pendingDelete = nil }
        } message: {
            Text(pendingDelete?.fileName ?? "")
        }
        .task { refresh() }
    }

    private var noResultsState: some View {
        VStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 26, weight: .medium))
                .foregroundStyle(.secondary)
            Text("No matching IPA files").font(.headline)
            Text("Try another filename or clear the search field.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private var emptyState: some View {
        VStack(spacing: 13) {
            Image(systemName: "folder.badge.plus")
                .font(.system(size: 30, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 68, height: 68)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
            Text("Nothing here yet").font(.headline)
            Text("Import one or more IPA files, or download SideStore from Signer. Your files will remain saved separately until you delete them.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
    }

    private func fileRow(name: String, detail: String, icon: String, identity: String,
                         isLoading: Bool, inspectAction: @escaping () -> Void,
                         useAction: @escaping () -> Void,
                         deleteAction: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(Theme.accent2)
                    .frame(width: 44, height: 44)
                    .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                VStack(alignment: .leading, spacing: 4) {
                    Text(name)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(2)
                    Text(detail)
                        .font(.system(size: 11))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
                Spacer(minLength: 4)
                Button(action: inspectAction) {
                    Image(systemName: "info.circle")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Theme.accent2)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Inspect \(name)")

                Button(role: .destructive, action: deleteAction) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.secondary)
                        .padding(8)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Delete \(name)")
            }

            Button(action: useAction) {
                HStack(spacing: 7) {
                    if isLoading { ProgressView().controlSize(.small) }
                    else { Image(systemName: "signature") }
                    Text(isLoading ? "Loading into Signer…" : "Load into Signer")
                }
                .font(.footnote.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .foregroundStyle(Theme.accent2)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(isLoading || isImporting)
        }
        .padding(12)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.065), lineWidth: 1))
        .accessibilityIdentifier(identity)
    }

    private func summaryTile(value: String, label: String, icon: String) -> some View {
        HStack(spacing: 11) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .medium))
                .foregroundStyle(Theme.accent)
                .frame(width: 38, height: 38)
                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 3) {
                Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).lineLimit(1).minimumScaleFactor(0.75)
                Text(label).font(.system(size: 11)).foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(13)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    private func refresh() {
        downloads.refresh()
        libraryItems = FrozenLibraryStore.scan()
    }

    @MainActor
    private func loadForSigning(url: URL, name: String, id: String) {
        guard loadingID == nil else { return }
        loadingID = id
        message = nil
        Task {
            await engine.importCustomIPA(from: url)
            if engine.customIPAName == name {
                engine.installSource = .custom
                message = "Loaded \(name) into Signer. Switch to the Signer tab to review and install it."
            } else {
                message = "Could not load \(name) into Signer. Switch to Signer to see the import error."
            }
            loadingID = nil
        }
    }

    private func deletePending() {
        guard let target = pendingDelete else { return }
        switch target {
        case .library(let item):
            do {
                try FrozenLibraryStore.delete(item)
                message = "Deleted \(item.fileName) from your IPA library."
            } catch {
                importError = "Couldn't delete \(item.fileName): \(error.localizedDescription)"
            }
        case .download(let item):
            downloads.delete(item)
        }
        pendingDelete = nil
        refresh()
    }
}


private struct FrozenIPAInspectorView: View {
    let item: FrozenLibraryItem

    @Environment(\.dismiss) private var dismiss
    @State private var appInfo: IPALibrary.AppInfo?
    @State private var checksum: String?
    @State private var isLoading = true
    @State private var copied = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.zipper")
                            .font(.system(size: 24, weight: .medium))
                            .foregroundStyle(Theme.accent)
                            .frame(width: 58, height: 58)
                            .background(Theme.accent.opacity(0.13), in: RoundedRectangle(cornerRadius: 18))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(appInfo?.name ?? item.fileName)
                                .font(.system(size: 21, weight: .bold, design: .rounded))
                                .lineLimit(3)
                            Text(isLoading ? "Inspecting package…" : (appInfo == nil ? "App metadata could not be read" : "Package metadata loaded"))
                                .font(.subheadline)
                                .foregroundStyle(appInfo == nil && !isLoading ? .orange : .secondary)
                        }
                    }

                    VStack(spacing: 0) {
                        metadataRow("File", item.fileName)
                        Divider().overlay(.white.opacity(0.06))
                        metadataRow("Size", item.sizeText)
                        Divider().overlay(.white.opacity(0.06))
                        metadataRow("Modified", item.modified?.formatted(date: .abbreviated, time: .shortened) ?? "Unknown")
                        Divider().overlay(.white.opacity(0.06))
                        metadataRow("Bundle ID", appInfo?.bundleID ?? (isLoading ? "Reading…" : "Unavailable"))
                        Divider().overlay(.white.opacity(0.06))
                        metadataRow("Version", appInfo?.version ?? (isLoading ? "Reading…" : "Not specified"))
                    }
                    .padding(.horizontal, 14)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 17))
                    .overlay(RoundedRectangle(cornerRadius: 17).stroke(.white.opacity(0.07), lineWidth: 1))

                    VStack(alignment: .leading, spacing: 9) {
                        HStack {
                            Text("SHA-256")
                                .font(.system(size: 13, weight: .semibold))
                            Spacer()
                            if checksum != nil {
                                Button(copied ? "Copied" : "Copy checksum") {
                                    guard let checksum else { return }
                                    UIPasteboard.general.string = checksum
                                    copied = true
                                }
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Theme.accent2)
                            }
                        }
                        Text(isLoading ? "Calculating checksum…" : (checksum ?? "Checksum unavailable"))
                            .font(.system(size: 11, design: .monospaced))
                            .textSelection(.enabled)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(15)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(.white.opacity(0.07), lineWidth: 1))

                    Text("Inspection reads the app's metadata from inside the archive and calculates a local SHA-256 checksum. This does not guarantee Apple will accept the app or that signing will succeed.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .padding(20)
            }
            .background(AppBackground())
            .navigationTitle("IPA details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .task { await inspect() }
    }

    private func metadataRow(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 16) {
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 76, alignment: .leading)
            Spacer(minLength: 0)
            Text(value)
                .font(.system(size: 12, weight: .medium))
                .multilineTextAlignment(.trailing)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .padding(.vertical, 12)
    }

    @MainActor
    private func inspect() async {
        let url = item.url
        let result = await Task.detached(priority: .utility) {
            (IPALibrary.appInfo(at: url), IPALibrary.sha256(of: url))
        }.value
        appInfo = result.0
        checksum = result.1
        isLoading = false
    }
}
