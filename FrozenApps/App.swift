import SwiftUI
import AuthenticationServices
import UniformTypeIdentifiers
import UserNotifications

@main
struct FrozenAppsApp: App {
    var body: some Scene {
        WindowGroup { ContentView().preferredColorScheme(.dark) }
    }
}

struct ContentView: View {
    @AppStorage("termsAccepted") private var termsAccepted = false
    @AppStorage("appleUserID") private var appleUserID = ""
    @AppStorage("appleEmail") private var appleEmail = ""
    @AppStorage("appleName") private var appleName = ""
    @AppStorage("localNotifications") private var localNotifications = false
    @State private var tab = 0
    @State private var showGuide = false
    @State private var showInbox = false
    @State private var showImporter = false
    @State private var notice = ""
    @State private var files: [IPAFile] = []
    @State private var inbox: [InboxItem] = []

    private var signedIn: Bool { !appleUserID.isEmpty }

    var body: some View {
        ZStack {
            ZStack {
                LinearGradient(
                    colors: [
                        Color(red: 0.025, green: 0.07, blue: 0.12),
                        Color(red: 0.025, green: 0.06, blue: 0.09),
                        Color(red: 0.025, green: 0.10, blue: 0.08)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ).ignoresSafeArea()
                ParticleField().ignoresSafeArea().allowsHitTesting(false)
            }
            VStack(spacing: 0) {
                header
                if termsAccepted {
                    Group {
                        if tab == 0 { signer }
                        else if tab == 1 { settings }
                        else { filePage }
                    }.frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                    tabs
                } else { termsPage }
            }
        }
        .sheet(isPresented: $showGuide) { guide }
        .sheet(isPresented: $showInbox) { inboxPage }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [UTType(filenameExtension: "ipa") ?? .data], allowsMultipleSelection: true, onCompletion: importFiles)
        .alert("FrozenApps", isPresented: Binding(get: { !notice.isEmpty }, set: { if !$0 { notice = "" } })) {
            Button("OK", role: .cancel) { notice = "" }
        } message: { Text(notice) }
        .onAppear { refreshFiles() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            Image(systemName: "snowflake").font(.system(size: 22, weight: .semibold))
                .frame(width: 44, height: 44).background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 14))
            VStack(alignment: .leading, spacing: 3) {
                Text("FrozenApps").font(.system(size: 21, weight: .bold))
                Text("ON-DEVICE SIGNING WORKSPACE").font(.system(size: 9, weight: .semibold)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            if termsAccepted {
                Button { showInbox = true } label: {
                    Image(systemName: "bell").frame(width: 42, height: 42).background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                }.buttonStyle(.plain)
            }
        }.padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 22)
    }

    private var termsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                tile("hand.raised.fill", FrozenPalette.green)
                Text("Your device. Your data.").font(.system(size: 30, weight: .bold, design: .rounded))
                Text("Please review and accept these terms before continuing.")
                    .font(.system(size: 15)).foregroundStyle(.white.opacity(0.55))
                policy("lock.fill", "Local storage", "This version saves preferences, Apple sign-in profile details, and imported IPA files on this device. It does not upload them to a FrozenApps database.")
                policy("key.slash", "No passwords or verification codes", "FrozenApps must never ask you to type your Apple Account password or two-factor code into the app. Apple's own system sheet handles Sign in with Apple.")
                policy("apple.logo", "Sign-in is not signing", "Signing in with Apple does not provide a developer certificate, sign an IPA, pair a device, or enable Developer Mode.")
                policy("checkmark.shield", "Use responsibly", "Only use apps and files you are authorized to use. Follow Apple's terms and the requirements of your signing method. Local storage does not guarantee legal immunity.")
                Button {
                    termsAccepted = true
                    inbox.insert(InboxItem(title: "Terms accepted", detail: "Acceptance is saved locally.", date: "Just now"), at: 0)
                } label: {
                    HStack { Text("Accept terms and continue"); Spacer(); Image(systemName: "arrow.right") }
                        .font(.system(size: 15, weight: .semibold)).foregroundStyle(.black)
                        .padding(17).background(.white, in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                Text("Your acceptance is saved on this device. You can review it again in Settings.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            }.padding(.horizontal, 22).padding(.bottom, 28)
        }.scrollIndicators(.hidden)
    }

    private var signer: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading("Signer", "An iPhone and iPad-first signing workspace.")
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 12) {
                        tile("apple.logo", .white)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(signedIn ? "Apple account connected" : "Sign in with Apple").font(.system(size: 16, weight: .semibold))
                            Text(signedIn ? (appleName.isEmpty ? "Signed in on this device" : appleName) : "Apple's official sign-in sheet")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.48))
                        }
                        Spacer()
                        Circle().fill(signedIn ? .green : .orange).frame(width: 8, height: 8)
                    }
                    if signedIn {
                        if !appleEmail.isEmpty { Text(appleEmail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)) }
                        Text("Your saved profile details remain local. No Apple password or verification code is stored.")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.5))
                    } else {
                        SignInWithAppleButton(.signIn, onRequest: { request in
                            request.requestedScopes = [.fullName, .email]
                        }, onCompletion: handleSignIn)
                        .signInWithAppleButtonStyle(.white).frame(height: 48).clipShape(RoundedRectangle(cornerRadius: 13))
                        Text("This authenticates your app session only; it does not sign apps.")
                            .font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                    }
                }.padding(18).background(.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 22))
                VStack(alignment: .leading, spacing: 13) {
                    Text("DEVICE SETUP").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
                    HStack(spacing: 12) {
                        tile("iphone.gen3", FrozenPalette.green)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Developer Mode").font(.system(size: 16, weight: .semibold))
                            Text("Review on-device setup and limitations.")
                                .font(.system(size: 12)).foregroundStyle(.white.opacity(0.48))
                        }
                    }
                    Button { showGuide = true } label: {
                        HStack { Text("Open device setup guide"); Spacer(); Image(systemName: "arrow.up.right") }
                            .font(.system(size: 14, weight: .semibold)).foregroundStyle(.black)
                            .padding(15).background(.white, in: RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain)
                    Text("FrozenApps cannot enable Developer Mode or pair the device by itself. Some Apple development workflows may require additional provisioning, possibly using a computer.")
                        .font(.system(size: 12)).foregroundStyle(.white.opacity(0.43))
                }.padding(18).background(.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 22))
                Button { showImporter = true } label: {
                    Label("Choose IPA from Files", systemImage: "square.and.arrow.down")
                        .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                        .frame(maxWidth: .infinity).padding(16).background(FrozenPalette.blue.opacity(0.13), in: RoundedRectangle(cornerRadius: 16))
                }.buttonStyle(.plain)
                Text("Importing only copies a file into app storage. A compatible on-device signing method is still needed to sign and install it.")
                    .font(.system(size: 12)).foregroundStyle(.white.opacity(0.42))
            }.padding(.horizontal, 22).padding(.bottom, 24)
        }.scrollIndicators(.hidden)
    }

    private var settings: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                heading("Settings", "Preferences and account details saved locally.")
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(get: { localNotifications }, set: { value in
                        if value { enableNotifications() } else { localNotifications = false }
                    })) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Local notifications").font(.system(size: 14, weight: .semibold))
                            Text("Allow FrozenApps to send its own alerts.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                        }
                    }.tint(FrozenPalette.green).padding(17)
                    Divider().overlay(.white.opacity(0.06))
                    actionRow("Send test notification", "Check local alerts.", "bell.badge") { sendTest() }
                    if signedIn {
                        Divider().overlay(.white.opacity(0.06))
                        actionRow("Sign out of FrozenApps", "Clear saved Apple profile details.", "rectangle.portrait.and.arrow.right") {
                            appleUserID = ""; appleEmail = ""; appleName = ""
                            notice = "Saved sign-in details cleared from this app. This does not revoke FrozenApps in your Apple Account settings."
                        }
                    }
                    Divider().overlay(.white.opacity(0.06))
                    actionRow("Review terms", "Return to the local-storage terms.", "doc.text") { termsAccepted = false }
                }.background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
                Text("LOCAL DATA").font(.system(size: 10, weight: .bold)).tracking(1.5).foregroundStyle(.white.opacity(0.4))
                Text("Imported IPA files are copied into the app's Documents folder. This version does not upload profile details or files to a FrozenApps database. Deleting the app may remove its local data.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.5))
            }.padding(.horizontal, 22)
        }.scrollIndicators(.hidden)
    }

    private var filePage: some View {
        VStack(alignment: .leading, spacing: 18) {
            heading("Files", "IPA files saved inside this app.")
            Button { showImporter = true } label: {
                Label("Import IPA from Files", systemImage: "plus").font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.black).frame(maxWidth: .infinity).padding(15).background(.white, in: RoundedRectangle(cornerRadius: 15))
            }.buttonStyle(.plain)
            if files.isEmpty {
                VStack(spacing: 12) {
                    tile("folder", FrozenPalette.green)
                    Text("No IPA files yet").font(.system(size: 17, weight: .semibold))
                    Text("Choose an IPA from the Files app. It will be copied into local app storage.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.43)).multilineTextAlignment(.center)
                }.frame(maxWidth: .infinity).padding(25).frame(minHeight: 210)
                    .background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 23))
            } else {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(files) { file in
                            HStack(spacing: 12) {
                                Image(systemName: "doc.zipper").foregroundStyle(FrozenPalette.blue).font(.system(size: 20))
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name).font(.system(size: 13, weight: .semibold)).lineLimit(1)
                                    Text(ByteCountFormatter.string(fromByteCount: file.size, countStyle: .file))
                                        .font(.system(size: 11)).foregroundStyle(.white.opacity(0.43))
                                }
                                Spacer()
                                Button(role: .destructive) { deleteFile(file) } label: {
                                    Image(systemName: "trash").foregroundStyle(.white.opacity(0.6)).padding(8)
                                }.buttonStyle(.plain)
                            }.padding(13).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }.padding(.horizontal, 22)
    }

    private var tabs: some View {
        HStack(spacing: 5) {
            tabButton("Signer", "signature", 0)
            tabButton("Settings", "slider.horizontal.3", 1)
            tabButton("Files", "folder", 2)
        }.padding(7).background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
            .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
    }

    private var guide: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 19) {
                    tile("iphone.gen3", FrozenPalette.green)
                    Text("Developer Mode").font(.system(size: 24, weight: .bold))
                    step("01", "Open Settings", "On your iPhone or iPad, open Settings, then Privacy & Security.")
                    step("02", "Look for Developer Mode", "Scroll down to Developer Mode if the option is available on your device.")
                    step("03", "Enable it yourself", "Switch it on, restart if iOS asks you to, then confirm Enable and enter your device passcode.")
                    step("04", "If the option is missing", "FrozenApps cannot force it to appear. Depending on iOS and your provisioning method, Apple's supported developer setup may require a computer.")
                    Text("Apple sign-in is not developer provisioning. An app cannot pair an iPad with itself or programmatically bypass Apple's signing requirements.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.55))
                        .padding(14).background(.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                }.padding(20)
            }.background(Color(red: 0.035, green: 0.04, blue: 0.06))
                .navigationTitle("Device setup").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showGuide = false } } }
        }.preferredColorScheme(.dark)
    }

    private var inboxPage: some View {
        NavigationStack {
            List {
                ForEach(inbox) { item in
                    VStack(alignment: .leading, spacing: 5) {
                        Text(item.title).font(.system(size: 15, weight: .semibold))
                        Text(item.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                        Text(item.date).font(.system(size: 11)).foregroundStyle(.tertiary)
                    }.padding(.vertical, 5).listRowBackground(Color.white.opacity(0.035))
                }
            }.scrollContentBackground(.hidden).background(Color(red: 0.035, green: 0.04, blue: 0.06))
                .navigationTitle("Notifications").navigationBarTitleDisplayMode(.inline)
                .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showInbox = false } } }
        }.preferredColorScheme(.dark)
    }

    private func handleSignIn(_ result: Result<ASAuthorization, Error>) {
        switch result {
        case .success(let auth):
            guard let credential = auth.credential as? ASAuthorizationAppleIDCredential else {
                notice = "Apple returned an unsupported credential."; return
            }
            appleUserID = credential.user
            if let email = credential.email { appleEmail = email }
            if let name = credential.fullName {
                let value = PersonNameComponentsFormatter().string(from: name).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { appleName = value }
            }
            inbox.insert(InboxItem(title: "Apple sign-in successful", detail: "Profile details saved locally.", date: "Just now"), at: 0)
            notice = "Signed in. This does not create signing certificates or enable Developer Mode."
        case .failure(let error):
            notice = "Apple sign-in did not complete: \(error.localizedDescription)"
        }
    }

    private func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
            DispatchQueue.main.async {
                localNotifications = granted
                notice = granted ? "Local notifications are enabled. They cannot read Apple's private prompts." : "Notifications were not enabled. You can allow them in iPad Settings."
            }
        }
    }

    private func sendTest() {
        guard localNotifications else { notice = "Turn on Local notifications first."; return }
        let content = UNMutableNotificationContent()
        content.title = "FrozenApps"; content.body = "Test notification — local alerts are working."; content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error { notice = "Could not schedule alert: \(error.localizedDescription)" }
                else { inbox.insert(InboxItem(title: "Test alert scheduled", detail: "A local notification should arrive shortly.", date: "Just now"), at: 0); notice = "Test notification scheduled." }
            }
        }
    }

    private func importFiles(_ result: Result<[URL], Error>) {
        switch result {
        case .failure(let error): notice = "Import failed: \(error.localizedDescription)"
        case .success(let urls):
            let folder = docs().appendingPathComponent("ImportedIPAs", isDirectory: true)
            do {
                try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
                var count = 0
                for source in urls {
                    let access = source.startAccessingSecurityScopedResource()
                    defer { if access { source.stopAccessingSecurityScopedResource() } }
                    guard source.pathExtension.lowercased() == "ipa" else { continue }
                    var dest = folder.appendingPathComponent(source.lastPathComponent)
                    if FileManager.default.fileExists(atPath: dest.path) {
                        dest = folder.appendingPathComponent(UUID().uuidString + "-" + source.lastPathComponent)
                    }
                    try FileManager.default.copyItem(at: source, to: dest); count += 1
                }
                refreshFiles()
                notice = count == 0 ? "No IPA files were imported." : "Imported \(count) IPA file(s). Importing does not sign them."
            } catch { refreshFiles(); notice = "Import failed: \(error.localizedDescription)" }
        }
    }

    private func refreshFiles() {
        let folder = docs().appendingPathComponent("ImportedIPAs", isDirectory: true)
        guard let urls = try? FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: [.fileSizeKey], options: [.skipsHiddenFiles]) else { files = []; return }
        files = urls.filter { $0.pathExtension.lowercased() == "ipa" }.map {
            IPAFile(name: $0.lastPathComponent, path: $0.path, size: Int64((try? $0.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0))
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private func deleteFile(_ file: IPAFile) {
        do { try FileManager.default.removeItem(atPath: file.path); refreshFiles() }
        catch { notice = "Could not delete file: \(error.localizedDescription)" }
    }

    private func docs() -> URL { FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0] }

    private func heading(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(title).font(.system(size: 32, weight: .bold, design: .rounded))
            Text(subtitle).font(.system(size: 15)).foregroundStyle(.white.opacity(0.48))
        }
    }

    private func tile(_ symbol: String, _ tint: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 20, weight: .medium)).foregroundStyle(tint)
            .frame(width: 48, height: 48).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
    }

    private func policy(_ icon: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: icon).foregroundStyle(FrozenPalette.green).frame(width: 27)
            VStack(alignment: .leading, spacing: 5) {
                Text(title).font(.system(size: 14, weight: .semibold))
                Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.5)).fixedSize(horizontal: false, vertical: true)
            }
        }.padding(14).background(.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 16))
    }

    private func step(_ number: String, _ title: String, _ detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(FrozenPalette.green)
                .frame(width: 36, height: 36).background(FrozenPalette.green.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.52)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func actionRow(_ title: String, _ subtitle: String, _ icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon).frame(width: 25).foregroundStyle(.white.opacity(0.65))
                VStack(alignment: .leading, spacing: 4) {
                    Text(title).font(.system(size: 14, weight: .semibold)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 12)).foregroundStyle(.white.opacity(0.43))
                }
                Spacer()
                Image(systemName: "chevron.right").font(.system(size: 11, weight: .semibold)).foregroundStyle(.white.opacity(0.3))
            }.padding(17).contentShape(Rectangle())
        }.buttonStyle(.plain)
    }

    private func tabButton(_ title: String, _ icon: String, _ index: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { tab = index } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(title).font(.system(size: 11, weight: .semibold))
            }.foregroundStyle(tab == index ? .white : .white.opacity(0.42))
                .frame(maxWidth: .infinity).padding(.vertical, 12)
                .background { if tab == index { RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.095)) } }
        }.buttonStyle(.plain)
    }
}

private struct IPAFile: Identifiable {
    let name: String
    let path: String
    let size: Int64
    var id: String { path }
}

private struct InboxItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: String
}


private enum FrozenPalette {
    static let green = Color(red: 0.20, green: 0.88, blue: 0.58)
    static let blue = Color(red: 0.28, green: 0.65, blue: 1.00)
}

private struct ParticleField: View {
    var body: some View {
        TimelineView(.animation(minimumInterval: 1.0 / 12.0, paused: false)) { timeline in
            Canvas { context, size in
                guard size.width > 0, size.height > 0 else { return }
                let time = timeline.date.timeIntervalSinceReferenceDate
                for index in 0..<42 {
                    let seed = Double(index)
                    let rawX = (sin(seed * 12.9898) * 0.5 + 0.5) * size.width
                    let baseY = (cos(seed * 78.233) * 0.5 + 0.5) * size.height
                    let speed = 1.2 + (Double(index % 5) * 0.55)
                    var y = (baseY - time * speed).truncatingRemainder(dividingBy: size.height)
                    if y < 0 { y += size.height }
                    let diameter = 1.2 + Double(index % 3) * 0.75
                    let rect = CGRect(x: rawX, y: y, width: diameter, height: diameter)
                    context.fill(Path(ellipseIn: rect), with: .color(Color.white.opacity(0.12 + Double(index % 5) * 0.055)))
                }
            }
        }
        .accessibilityHidden(true)
    }
}
