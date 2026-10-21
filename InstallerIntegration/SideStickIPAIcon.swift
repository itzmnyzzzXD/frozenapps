import CryptoKit
import Foundation
import SwiftUI
import UIKit

/// Extracts a real app icon from an IPA and caches it by archive SHA-256.
/// A compact path/size/mtime index means unchanged IPAs are not rehashed after
/// every library reopen; all archive and image work runs on this actor.
private actor SideStickIPAIconCache {
    static let shared = SideStickIPAIconCache()

    private func directory() -> URL? {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("SideStickIPAIcons", isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            return dir
        } catch {
            return nil
        }
    }

    func iconData(for ipaURL: URL) -> Data? {
        guard let dir = directory(),
              let attrs = try? FileManager.default.attributesOfItem(atPath: ipaURL.path),
              let size = attrs[.size] as? NSNumber, size.int64Value > 0 else { return nil }
        let modified = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        let fingerprint = "\(ipaURL.standardizedFileURL.path)|\(size.int64Value)|\(Int64(modified))"
        let indexKey = SHA256.hash(data: Data(fingerprint.utf8)).map { String(format: "%02x", $0) }.joined()
        let indexURL = dir.appendingPathComponent("index-\(indexKey).txt")

        if let cachedDigest = try? String(contentsOf: indexURL, encoding: .utf8)
            .trimmingCharacters(in: .whitespacesAndNewlines) {
            if cachedDigest == "missing" { return nil }
            let cachedURL = dir.appendingPathComponent("\(cachedDigest).png")
            if let bytes = try? Data(contentsOf: cachedURL), UIImage(data: bytes) != nil { return bytes }
        }

        guard let digest = IPALibrary.sha256(of: ipaURL) else { return nil }
        let imageURL = dir.appendingPathComponent("\(digest).png")
        if let cached = try? Data(contentsOf: imageURL), UIImage(data: cached) != nil {
            try? digest.write(to: indexURL, atomically: true, encoding: .utf8)
            return cached
        }

        guard let image = extractIcon(from: ipaURL),
              let png = image.pngData(), !png.isEmpty else {
            try? "missing".write(to: indexURL, atomically: true, encoding: .utf8)
            return nil
        }
        try? png.write(to: imageURL, options: .atomic)
        try? digest.write(to: indexURL, atomically: true, encoding: .utf8)
        return png
    }

    private func extractIcon(from ipaURL: URL) -> UIImage? {
        guard let files = IPALibrary.archiveFiles(at: ipaURL),
              let infoEntry = files.first(where: {
                  let p = $0.path.split(separator: "/", omittingEmptySubsequences: false)
                  return p.count == 3 && p[0] == "Payload" && p[1].hasSuffix(".app") && p[2] == "Info.plist"
              }),
              let infoData = IPALibrary.contents(of: infoEntry, in: ipaURL),
              let plist = try? PropertyListSerialization.propertyList(from: infoData, format: nil),
              let info = plist as? [String: Any] else { return nil }

        let root = infoEntry.path.components(separatedBy: "/").dropLast().joined(separator: "/") + "/"
        let names = iconNames(from: info)
        let imageFiles = files.filter { file in
            guard file.path.hasPrefix(root), !names.isEmpty,
                  file.path.hasSuffix(".png") || file.path.hasSuffix(".PNG")
                    || file.path.hasSuffix(".jpg") || file.path.hasSuffix(".jpeg") else { return false }
            let relative = String(file.path.dropFirst(root.count))
            guard !relative.contains("/") else { return false }
            let stem = (relative as NSString).deletingPathExtension
            return names.contains { rawName in
                let base = (rawName as NSString).lastPathComponent
                return stem == base || stem == base + "@2x" || stem == base + "@3x"
                    || stem == (base as NSString).deletingPathExtension
            }
        }.sorted { $0.size > $1.size }

        for file in imageFiles where file.size > 0 && file.size <= 8_000_000 {
            if let bytes = IPALibrary.contents(of: file, in: ipaURL), let image = UIImage(data: bytes) {
                return image
            }
        }

        // For modern apps whose icon exists only in Assets.car, use an isolated
        // temporary bundle. If UIKit cannot decode it, the row keeps its normal
        // generic fallback rather than inventing an icon.
        guard let asset = files.first(where: {
            $0.path == root + "Assets.car" && $0.size > 0 && $0.size <= 64 * 1024 * 1024
        }), let assetData = IPALibrary.contents(of: asset, in: ipaURL) else { return nil }

        let bundleURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("SideStick-Icon-\(UUID().uuidString).app", isDirectory: true)
        defer { try? FileManager.default.removeItem(at: bundleURL) }
        do {
            try FileManager.default.createDirectory(at: bundleURL, withIntermediateDirectories: true)
            try infoData.write(to: bundleURL.appendingPathComponent("Info.plist"), options: .atomic)
            try assetData.write(to: bundleURL.appendingPathComponent("Assets.car"), options: .atomic)
        } catch {
            return nil
        }
        guard let bundle = Bundle(path: bundleURL.path) else { return nil }
        var candidateNames = names
        if let name = info["CFBundleIconName"] as? String { candidateNames.insert(name, at: 0) }
        candidateNames.insert("AppIcon", at: 0)
        for name in candidateNames where !name.isEmpty {
            if let image = UIImage(named: name, in: bundle, compatibleWith: nil) { return image }
        }
        return nil
    }

    private func iconNames(from info: [String: Any]) -> [String] {
        var names: [String] = []
        func add(_ value: Any?) {
            if let name = value as? String, !name.isEmpty, !names.contains(name) { names.append(name) }
            if let list = value as? [String] {
                for name in list where !name.isEmpty && !names.contains(name) { names.append(name) }
            }
        }
        add(info["CFBundleIconFile"])
        add(info["CFBundleIconFiles"])
        for key in ["CFBundleIcons", "CFBundleIcons~ipad"] {
            guard let icons = info[key] as? [String: Any],
                  let primary = icons["CFBundlePrimaryIcon"] as? [String: Any] else { continue }
            add(primary["CFBundleIconName"])
            add(primary["CFBundleIconFiles"])
        }
        return names
    }
}

struct SideStickEmbeddedIPAIcon: View {
    let ipaURL: URL
    let fallbackSymbol: String
    var size: CGFloat = 44
    @State private var image: UIImage?

    var body: some View {
        Group {
            if let image {
                Image(uiImage: image).resizable().scaledToFill().transition(.opacity)
            } else {
                Image(systemName: fallbackSymbol)
                    .font(.system(size: size * 0.45, weight: .medium))
                    .foregroundStyle(Theme.accent2)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(width: size, height: size)
        .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 14))
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .task(id: ipaURL.path) {
            let bytes = await SideStickIPAIconCache.shared.iconData(for: ipaURL)
            if let loaded = bytes.flatMap({ UIImage(data: $0) }) {
                withAnimation(.easeOut(duration: 0.18)) { image = loaded }
            }
        }
        .accessibilityLabel("IPA app icon")
    }
}
