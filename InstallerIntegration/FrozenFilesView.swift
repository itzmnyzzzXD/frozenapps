import Foundation
import SwiftUI
import UniformTypeIdentifiers

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

        var errorDescription: String? {
            switch self {
            case .notIPA: return "Choose a file with the .ipa extension."
            case .invalidArchive: return "This file does not look like a complete IPA package."
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
    @State private var loadingID: String?
    @State private var message: String?
    @State private var importError: String?
    @State private var pendingDelete: DeleteTarget?

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

                    if let message {
                        Text(message)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(13)
                            .background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 14))
                    }

                    if downloads.downloads.isEmpty && libraryItems.isEmpty {
                        emptyState
                    } else {
                        if !libraryItems.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("MY IPA LIBRARY")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3)

                                ForEach(libraryItems) { item in
                                    fileRow(name: item.fileName,
                                            detail: "\(item.sizeText) · Saved locally",
                                            icon: "doc.badge.plus",
                                            identity: item.id,
                                            isLoading: loadingID == item.id,
                                            useAction: { loadForSigning(url: item.url, name: item.fileName, id: item.id) },
                                            deleteAction: { pendingDelete = .library(item) })
                                }
                            }
                        }

                        if !downloads.downloads.isEmpty {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("SIGNER DOWNLOADS")
                                    .font(.system(size: 10, weight: .bold))
                                    .tracking(1.5)
                                    .foregroundStyle(.secondary)
                                    .padding(.horizontal, 3)

                                ForEach(downloads.downloads) { item in
                                    fileRow(name: item.displayName,
                                            detail: "\(item.sizeText) · \(item.fileName)",
                                            icon: item.isImported ? "doc.badge.plus" : "doc.zipper",
                                            identity: item.id,
                                            isLoading: loadingID == item.id,
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
                message = nil
                Task.detached(priority: .userInitiated) {
                    var imported = 0
                    var failures: [String] = []
                    for url in urls {
                        do {
                            _ = try FrozenLibraryStore.importIPA(from: url)
                            imported += 1
                        } catch {
                            failures.append("\(url.lastPathComponent): \(error.localizedDescription)")
                        }
                    }
                    await MainActor.run {
                        isImporting = false
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
                         isLoading: Bool, useAction: @escaping () -> Void,
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
