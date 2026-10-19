import CryptoKit
import Foundation
import Security
import SwiftUI
import UniformTypeIdentifiers

private struct FrozenProfileInfo {
    let fileName: String
    let uuid: String
    let teamID: String
    let bundlePattern: String
    let expiry: Date
    let certificateCount: Int
}

private enum FrozenProfileReader {
    enum ReadError: LocalizedError {
        case invalidProfile
        case missingExpiry

        var errorDescription: String? {
            switch self {
            case .invalidProfile:
                return "The file did not contain a readable provisioning-profile plist. Choose a valid .mobileprovision file."
            case .missingExpiry:
                return "The profile was decoded but did not contain an expiration date."
            }
        }
    }

    static func read(_ data: Data, fileName: String) throws -> FrozenProfileInfo {
        guard let start = data.range(of: Data("<?xml".utf8))?.lowerBound,
              let end = data.range(of: Data("</plist>".utf8), options: [], in: start..<data.endIndex)?.upperBound,
              let plist = try PropertyListSerialization.propertyList(
                from: data.subdata(in: start..<end), options: [], format: nil
              ) as? [String: Any] else {
            throw ReadError.invalidProfile
        }
        guard let expiry = plist["ExpirationDate"] as? Date else { throw ReadError.missingExpiry }
        let team = (plist["TeamIdentifier"] as? [String])?.first ?? ""
        let entitlements = plist["Entitlements"] as? [String: Any] ?? [:]
        let appID = entitlements["application-identifier"] as? String ?? ""
        let pattern = (!team.isEmpty && appID.hasPrefix(team + "."))
            ? String(appID.dropFirst(team.count + 1)) : appID
        return FrozenProfileInfo(
            fileName: fileName,
            uuid: plist["UUID"] as? String ?? "Unknown",
            teamID: team,
            bundlePattern: pattern.isEmpty ? "Unknown" : pattern,
            expiry: expiry,
            certificateCount: (plist["DeveloperCertificates"] as? [Data])?.count ?? 0
        )
    }

    static func matches(bundleID: String, pattern: String) -> Bool {
        let bundle = bundleID.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !bundle.isEmpty, !pattern.isEmpty, pattern != "Unknown" else { return false }
        if pattern == "*" { return true }
        if pattern.hasSuffix(".*") { return bundle.hasPrefix(String(pattern.dropLast())) }
        return bundle == pattern
    }
}

struct FrozenCertificateHealthView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("frozenApps.profileHealth.expiration") private var profileExpiry = 0.0
    @AppStorage("frozenApps.profileHealth.bundlePattern") private var profilePattern = ""
    @AppStorage("frozenApps.profileHealth.teamID") private var profileTeamID = ""
    @AppStorage("frozenApps.profileHealth.uuid") private var profileUUID = ""
    @AppStorage("frozenApps.profileHealth.fileName") private var profileName = ""
    @AppStorage("frozenApps.profileHealth.certificateCount") private var profileCertCount = 0
    @AppStorage("frozenApps.certificateHealth.expiration") private var certExpiry = 0.0
    @AppStorage("frozenApps.certificateHealth.subject") private var certSubject = ""
    @AppStorage("frozenApps.certificateHealth.fingerprint") private var certFingerprint = ""
    @AppStorage("frozenApps.certificateHealth.fileName") private var certName = ""

    @State private var showImporter = false
    @State private var importKind: ImportKind = .profile
    @State private var p12Data: Data?
    @State private var p12Name = ""
    @State private var p12Password = ""
    @State private var bundleID = ""
    @State private var status: String?
    @State private var error: String?

    private enum ImportKind { case profile, certificate }
    private var profileDate: Date? { profileExpiry > 0 ? Date(timeIntervalSince1970: profileExpiry) : nil }
    private var certificateDate: Date? { certExpiry > 0 ? Date(timeIntervalSince1970: certExpiry) : nil }

    private var matchMessage: String {
        guard !profilePattern.isEmpty else { return "Import a provisioning profile first." }
        guard !bundleID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return "Enter the bundle ID shown in IPA details."
        }
        return FrozenProfileReader.matches(bundleID: bundleID, pattern: profilePattern)
            ? "Bundle ID matches the profile's application identifier pattern."
            : "Bundle ID does not match this profile's application identifier pattern."
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        VStack(alignment: .leading, spacing: 7) {
                            Label("SIGNING MATERIAL", systemImage: "checkmark.shield.fill")
                                .font(.system(size: 10, weight: .heavy, design: .rounded))
                                .tracking(1.5).foregroundStyle(Theme.accent2)
                            Text("Certificate Health")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Inspect expiry dates, team and bundle pattern, and a public certificate fingerprint. Actual signing stays in the existing Signer workflow.")
                                .font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.57))
                        }
                        profileCard
                        certificateCard
                        compatibilityCard
                        PanelCard {
                            VStack(alignment: .leading, spacing: 6) {
                                Label("Expiry is not revocation", systemImage: "info.circle.fill")
                                    .font(.system(size: 13, weight: .bold, design: .rounded)).foregroundStyle(Theme.accent2)
                                Text("This screen reads local profile and certificate metadata. It does not claim a certificate is currently unrevoked. Matching a bundle pattern also does not guarantee Apple will accept a signing request or that an app will install.")
                                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.55))
                            }
                        }
                        if let error { feedback(error, isError: true) }
                        else if let status { feedback(status, isError: false) }
                    }
                    .padding(20).frame(maxWidth: 620).frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Certificate Health")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() } } }
        }
        .preferredColorScheme(.dark)
        .fileImporter(isPresented: $showImporter,
                      allowedContentTypes: importKind == .profile
                        ? [UTType(filenameExtension: "mobileprovision") ?? .data]
                        : [UTType(filenameExtension: "p12") ?? .data],
                      allowsMultipleSelection: false,
                      onCompletion: importFile)
    }

    private var profileCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Provisioning profile", systemImage: "doc.badge.gearshape")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    expiryBadge(profileDate)
                }
                if let profileDate {
                    row("File", profileName)
                    row("Expires", profileDate.formatted(date: .abbreviated, time: .shortened))
                    row("Time remaining", daysLeft(profileDate))
                    row("Team ID", profileTeamID)
                    row("Bundle pattern", profilePattern)
                    row("Profile UUID", profileUUID)
                    row("Embedded certificates", String(profileCertCount))
                } else {
                    Text("Import a .mobileprovision file to inspect its expiry, team, application identifier and embedded certificate count.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
                actionButton("Inspect provisioning profile", icon: "folder.badge.plus") {
                    importKind = .profile
                    showImporter = true
                }
            }
        }
    }

    private var certificateCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label("Signing certificate", systemImage: "person.badge.key")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Spacer()
                    expiryBadge(certificateDate)
                }
                if let certificateDate {
                    row("File", certName)
                    row("Subject", certSubject)
                    row("Expires", certificateDate.formatted(date: .abbreviated, time: .shortened))
                    row("Time remaining", daysLeft(certificateDate))
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Public certificate SHA-256").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                        Text(certFingerprint).font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.72)).textSelection(.enabled)
                    }
                } else {
                    Text("Import a .p12 certificate bundle, then enter its password to inspect the certificate's public metadata. The password is not saved.")
                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.55))
                }
                actionButton("Choose .p12 certificate bundle", icon: "folder.badge.plus") {
                    importKind = .certificate
                    showImporter = true
                }
                if p12Data != nil {
                    SecureField("PKCS#12 password", text: $p12Password)
                        .textContentType(.password).padding(12)
                        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                    Button("Inspect certificate locally") { inspectPKCS12() }
                        .font(.system(size: 12, weight: .semibold)).foregroundStyle(.black)
                        .frame(maxWidth: .infinity).padding(12)
                        .background(Theme.accent2, in: RoundedRectangle(cornerRadius: 12))
                        .buttonStyle(.plain).disabled(p12Password.isEmpty)
                }
            }
        }
    }

    private var compatibilityCard: some View {
        PanelCard {
            VStack(alignment: .leading, spacing: 9) {
                Label("Profile compatibility", systemImage: "checkmark.seal")
                    .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text("Compare the bundle ID from IPA details with this profile's identifier pattern. This is a pre-check, not a complete signing validation.")
                    .font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.54))
                TextField("com.example.app", text: $bundleID)
                    .textInputAutocapitalization(.never).autocorrectionDisabled()
                    .font(.system(size: 12, design: .monospaced)).padding(12)
                    .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 12))
                Label(matchMessage, systemImage: matchMessage.contains("matches") && !matchMessage.contains("does not") ? "checkmark.circle.fill" : "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(matchMessage.contains("does not") ? .orange : .white.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func expiryBadge(_ date: Date?) -> some View {
        let days = date.map { Calendar.current.dateComponents([.day], from: Date(), to: $0).day ?? 0 }
        let label: String
        let tint: Color
        if let days {
            if days < 0 { label = "Expired"; tint = .red }
            else if days <= 7 { label = "\(days)d left"; tint = .orange }
            else if days <= 30 { label = "\(days)d left"; tint = .yellow }
            else { label = "Valid by date"; tint = .green }
        } else { label = "Not checked"; tint = .gray }
        return Text(label).font(.system(size: 9, weight: .bold, design: .rounded))
            .foregroundStyle(tint).padding(.horizontal, 8).padding(.vertical, 6)
            .background(tint.opacity(0.13), in: Capsule())
    }

    private func daysLeft(_ date: Date) -> String {
        let days = Calendar.current.dateComponents([.day], from: Date(), to: date).day ?? 0
        if days < 0 { return "Expired \(abs(days)) day(s) ago" }
        if days == 0 { return "Expires within 24 hours" }
        return "\(days) day(s)"
    }

    private func row(_ title: String, _ value: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text(title).foregroundStyle(.white.opacity(0.45))
            Spacer(minLength: 10)
            Text(value).foregroundStyle(.white.opacity(0.86))
                .multilineTextAlignment(.trailing).textSelection(.enabled)
        }.font(.system(size: 10, weight: .medium))
    }

    private func actionButton(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon).font(.system(size: 12, weight: .semibold))
                .frame(maxWidth: .infinity).padding(12).foregroundStyle(.black)
                .background(Theme.accent2, in: RoundedRectangle(cornerRadius: 12))
        }.buttonStyle(.plain)
    }

    private func feedback(_ message: String, isError: Bool) -> some View {
        Label(message, systemImage: isError ? "exclamationmark.triangle.fill" : "checkmark.circle.fill")
            .font(.system(size: 11, weight: .medium)).foregroundStyle(isError ? .orange : .green)
            .frame(maxWidth: .infinity, alignment: .leading).padding(13)
            .background((isError ? Color.orange : Color.green).opacity(0.1), in: RoundedRectangle(cornerRadius: 13))
    }

    private func importFile(_ result: Result<[URL], Error>) {
        do {
            guard let url = try result.get().first else { return }
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            switch importKind {
            case .profile:
                let info = try FrozenProfileReader.read(Data(contentsOf: url), fileName: url.lastPathComponent)
                profileName = info.fileName
                profileUUID = info.uuid
                profileTeamID = info.teamID
                profilePattern = info.bundlePattern
                profileCertCount = info.certificateCount
                profileExpiry = info.expiry.timeIntervalSince1970
                status = "Provisioning profile inspected. Metadata saved locally."
                error = nil
            case .certificate:
                p12Data = try Data(contentsOf: url)
                p12Name = url.lastPathComponent
                p12Password = ""
                status = "Certificate bundle loaded into temporary app memory. Enter its password to inspect it."
                error = nil
            }
        } catch {
            self.error = error.localizedDescription
            status = nil
        }
    }

    private func inspectPKCS12() {
        guard let data = p12Data else { return }
        var items: CFArray?
        let options = [kSecImportExportPassphrase as String: p12Password] as CFDictionary
        let result = SecPKCS12Import(data as CFData, options, &items)
        guard result == errSecSuccess,
              let rows = items as? [[String: Any]],
              let identity = rows.first?[kSecImportItemIdentity as String] as? SecIdentity else {
            error = SecCopyErrorMessageString(result, nil) as String? ?? "Could not open the certificate bundle with that password."
            status = nil
            return
        }
        var found: SecCertificate?
        guard SecIdentityCopyCertificate(identity, &found) == errSecSuccess, let certificate = found else {
            error = "Could not read the public certificate from this bundle."
            status = nil
            return
        }
        var copyError: Unmanaged<CFError>?
        guard let values = SecCertificateCopyValues(certificate, [kSecOIDX509V1ValidityNotAfter] as CFArray, &copyError) as? [String: Any],
              let expiryValue = values[kSecOIDX509V1ValidityNotAfter as String] as? [String: Any],
              let expiry = expiryValue[kSecPropertyKeyValue as String] as? Date else {
            error = "The certificate was opened, but its expiry date could not be read."
            status = nil
            return
        }
        let der = SecCertificateCopyData(certificate) as Data
        certFingerprint = SHA256.hash(data: der).map { String(format: "%02x", $0) }.joined()
        certSubject = SecCertificateCopySubjectSummary(certificate) as String? ?? "Unknown subject"
        certName = p12Name
        certExpiry = expiry.timeIntervalSince1970
        p12Data = nil
        p12Password = ""
        status = "Certificate inspected locally. Only public metadata was saved."
        error = nil
    }
}
