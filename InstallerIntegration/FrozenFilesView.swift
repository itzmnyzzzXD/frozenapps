import SwiftUI
import UniformTypeIdentifiers

/// Local IPA library backed by the installer engine's on-device file store.
struct FrozenFilesView: View {
    @EnvironmentObject private var engine: Engine
    @StateObject private var downloads = DownloadsManager()
    @State private var showImporter = false
    @State private var importError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 7) {
                        Text("Your files")
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                        Text("Downloaded and imported IPA packages stay in this app's local storage.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 12) {
                        summaryTile(value: "\(downloads.downloads.count)", label: "IPA files", icon: "doc.zipper")
                        summaryTile(value: downloads.totalSizeText, label: "Storage used", icon: "externaldrive")
                    }

                    Button { showImporter = true } label: {
                        Label("Import IPA from Files", systemImage: "plus")
                            .font(.system(size: 15, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .padding(16)
                            .foregroundStyle(.black)
                            .background(Theme.brand, in: RoundedRectangle(cornerRadius: 17, style: .continuous))
                    }
                    .buttonStyle(.plain)

                    if downloads.downloads.isEmpty {
                        VStack(spacing: 13) {
                            Image(systemName: "folder.badge.plus")
                                .font(.system(size: 30, weight: .medium))
                                .foregroundStyle(Theme.accent)
                                .frame(width: 68, height: 68)
                                .background(Theme.accent.opacity(0.12), in: RoundedRectangle(cornerRadius: 22))
                            Text("Nothing here yet").font(.headline)
                            Text("Choose an IPA above, or download SideStore from the Signer tab. Imported files appear here once the engine finishes copying them.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(24)
                        .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 24, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 24, style: .continuous).stroke(.white.opacity(0.08), lineWidth: 1))
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("ON THIS DEVICE")
                                .font(.system(size: 10, weight: .bold))
                                .tracking(1.5)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 3)
                            ForEach(downloads.downloads) { item in
                                HStack(spacing: 12) {
                                    Image(systemName: item.isImported ? "doc.badge.plus" : "doc.zipper")
                                        .font(.system(size: 20, weight: .medium))
                                        .foregroundStyle(item.isImported ? Theme.accent : Theme.accent2)
                                        .frame(width: 46, height: 46)
                                        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.displayName)
                                            .font(.system(size: 14, weight: .semibold))
                                            .lineLimit(2)
                                        Text("\(item.sizeText) · \(item.isImported ? "Imported" : "Downloaded")")
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer(minLength: 4)
                                    Button(role: .destructive) {
                                        downloads.delete(item)
                                    } label: {
                                        Image(systemName: "trash")
                                            .font(.system(size: 14, weight: .medium))
                                            .foregroundStyle(.secondary)
                                            .padding(9)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel("Delete \(item.fileName)")
                                }
                                .padding(12)
                                .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .overlay(RoundedRectangle(cornerRadius: 18, style: .continuous).stroke(.white.opacity(0.065), lineWidth: 1))
                            }
                        }
                    }

                    Text("Files are stored on this device. Signing and installation still require a valid supported signing session.")
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
            .refreshable { downloads.refresh() }
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
                Task {
                    for url in urls {
                        await engine.importCustomIPA(from: url)
                    }
                    downloads.refresh()
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
        .task { downloads.refresh() }
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
}
