#!/usr/bin/env python3
"""Apply FrozenApps branding and navigation to the pinned SideInstaller source."""
from pathlib import Path
import subprocess

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "Vendor" / "SideInstaller"
APP = VENDOR / "ios-app"

if not (APP / "Engine.swift").is_file():
    raise SystemExit("SideInstaller submodule is missing. Run: git submodule update --init --recursive")

def replace_once(relative_path: str, old: str, new: str) -> None:
    path = VENDOR / relative_path
    text = path.read_text(encoding="utf-8")
    if new in text:
        return
    count = text.count(old)
    if count == 1:
        path.write_text(text.replace(old, new, 1), encoding="utf-8")
    else:
        raise SystemExit(f"Expected one patch target in {relative_path}; found {count}: {old[:80]!r}")

def replace_section(relative_path: str, start_marker: str, end_marker: str | None, replacement: str) -> None:
    """Replace one complete Swift declaration in the pinned source, idempotently."""
    path = VENDOR / relative_path
    source = path.read_text(encoding="utf-8")
    if replacement.strip() in source:
        return
    start = source.find(start_marker)
    if start < 0:
        raise SystemExit(f"Could not find section start in {relative_path}: {start_marker!r}")
    if end_marker is None:
        end = len(source)
    else:
        end = source.find(end_marker, start + len(start_marker))
        if end < 0:
            raise SystemExit(f"Could not find section end in {relative_path}: {end_marker!r}")
    path.write_text(source[:start] + replacement.rstrip() + "\n" + source[end:], encoding="utf-8")


# Keep SideInstaller's protocol/pairing host identifiers stable; only update app
# bundle, Keychain service and visible labels.
info = APP / "Info.plist"
txt = info.read_text(encoding="utf-8")
txt = txt.replace("SideInstaller", "FrozenApps")
txt = txt.replace("com.frizzlem.sideinstaller", "com.itzmnyzzz.frozenapps")
txt = txt.replace("com.frizzle.sideinstaller", "com.itzmnyzzz.frozenapps")
# Explain the existing pairing traffic as well as the new, user-triggered diagnostics.
txt = txt.replace(
    "FrozenApps advertises an on-device pairing service so this iPhone can pair with it, and connects to the local lockdown daemon to install apps.",
    "FrozenApps uses the local network for device pairing, app installation, and optional discovery of nearby HTTP services. Scan results stay on this device."
)

# Preserve the engine's existing Bonjour services and add only the service type
# used by FrozenNetworkView. This is required for iOS Local Network discovery.
if "<key>NSBonjourServices</key>" not in txt:
    root_end = txt.rfind("</dict>")
    if root_end < 0:
        raise SystemExit("Could not find the top-level Info.plist dictionary end.")
    services = (
        "\t<key>NSBonjourServices</key>\n"
        "\t<array>\n"
        "\t\t<string>_http._tcp</string>\n"
        "\t</array>\n"
    )
    txt = txt[:root_end] + services + txt[root_end:]
elif "<string>_http._tcp</string>" not in txt:
    services_key = txt.find("<key>NSBonjourServices</key>")
    services_array = txt.find("<array>", services_key)
    if services_array < 0:
        raise SystemExit("NSBonjourServices exists but its array is missing.")
    insert_at = txt.find("\n", services_array) + 1
    if insert_at == 0:
        raise SystemExit("Could not locate the NSBonjourServices array.")
    txt = txt[:insert_at] + "\t\t<string>_http._tcp</string>\n" + txt[insert_at:]

# Keep a purpose string even if a future upstream version removes its own key.
if "<key>NSLocalNetworkUsageDescription</key>" not in txt:
    root_end = txt.rfind("</dict>")
    if root_end < 0:
        raise SystemExit("Could not find the top-level Info.plist dictionary end.")
    purpose = (
        "\t<key>NSLocalNetworkUsageDescription</key>\n"
        "\t<string>FrozenApps uses the local network for device pairing, app installation, and optional discovery of nearby HTTP services.</string>\n"
    )
    txt = txt[:root_end] + purpose + txt[root_end:]
info.write_text(txt, encoding="utf-8")

# The Live Activity extension shares the visible product name.
activity_info = VENDOR / "ios-live-activity" / "Info.plist"
if activity_info.is_file():
    activity_text = activity_info.read_text(encoding="utf-8")
    activity_text = activity_text.replace("SideInstaller", "FrozenApps")
    activity_info.write_text(activity_text, encoding="utf-8")

for path in APP.glob("*.swift"):
    text = path.read_text(encoding="utf-8")
    changed = text.replace("com.frizzlem.sideinstaller", "com.itzmnyzzz.frozenapps")
    changed = changed.replace("com.frizzle.sideinstaller", "com.itzmnyzzz.frozenapps")
    changed = changed.replace("com.frizzle.SideInstaller.appleID", "com.itzmnyzzz.frozenapps.appleID")
    changed = changed.replace('Text("SideInstaller")', 'Text("FrozenApps")')
    changed = changed.replace("SideInstaller walks you through it", "FrozenApps walks you through it")
    if changed != text:
        path.write_text(changed, encoding="utf-8")


# Fully rework the first-run Apple-account setup and account editor. These views
# retain AccountStore's Keychain/save callbacks; authentication remains in Engine.
replace_section(
    "ios-app/AccountViews.swift",
    "struct AccountSetupView: View {",
    "/// Which of the two credential fields has the keyboard.",
    r'''struct AccountSetupView: View {
    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false
    @EnvironmentObject private var accounts: AccountStore
    @EnvironmentObject private var loc: Localizer

    @State private var email = ""
    @State private var password = ""
    @State private var passwordVisible = false
    @FocusState private var focus: AccountField?

    private var canSave: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        ZStack {
            AppBackground()
            ScrollView {
                VStack(spacing: 22) {
                    brandHeader
                    credentialsCard
                    actions
                    HStack(spacing: 8) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(Theme.accent2)
                        Text("Your saved password is stored with iOS Keychain. Apple sign-in and developer signing still require network access.")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.48))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 4)
                }
                .padding(22)
                .padding(.top, 24)
                .frame(maxWidth: 520)
                .frame(maxWidth: .infinity)
            }
            .scrollDismissesKeyboard(.interactively)
        }
        .preferredColorScheme(.dark)
        .task {
            try? await Task.sleep(for: .milliseconds(650))
            focus = .email
        }
    }

    private var brandHeader: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 27, style: .continuous)
                    .fill(Theme.brand)
                    .shadow(color: Theme.accent.opacity(0.34), radius: 24, x: 0, y: 12)
                Circle()
                    .strokeBorder(.white.opacity(0.22), lineWidth: 1)
                    .padding(8)
                Image(systemName: "snowflake")
                    .font(.system(size: 39, weight: .medium))
                    .foregroundStyle(.white)
                    .shadow(color: Theme.accent2.opacity(0.45), radius: 10)
            }
            .frame(width: 88, height: 88)
            .padding(.bottom, 4)

            Text("FROZENAPPS · ACCOUNT SETUP")
                .font(.system(size: 9, weight: .heavy, design: .rounded))
                .tracking(1.8)
                .foregroundStyle(Theme.accent2)

            Text("Pair with FrozenApps")
                .font(.system(size: 29, weight: .bold, design: .rounded))
                .tracking(-0.7)
                .multilineTextAlignment(.center)
                .foregroundStyle(.white)

            Text("Connect your Apple Account for provisioning, signing and app installs.")
                .font(.system(size: 13, weight: .medium))
                .multilineTextAlignment(.center)
                .foregroundStyle(.white.opacity(0.57))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Label("On-device setup", systemImage: "iphone")
                Label("Keychain storage", systemImage: "lock.fill")
            }
            .font(.system(size: 10, weight: .semibold))
            .foregroundStyle(.white.opacity(0.73))
            .padding(.horizontal, 13)
            .padding(.vertical, 9)
            .background(.white.opacity(0.055), in: Capsule())
            .overlay { Capsule().strokeBorder(.white.opacity(0.09), lineWidth: 1) }
        }
        .frame(maxWidth: .infinity)
    }

    private var credentialsCard: some View {
        VStack(alignment: .leading, spacing: 15) {
            VStack(alignment: .leading, spacing: 4) {
                Text("APPLE ACCOUNT")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.4)
                    .foregroundStyle(Theme.accent2)
                Text("Sign in details")
                    .font(.system(size: 18, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            HStack(spacing: 11) {
                Image(systemName: "envelope")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
                    .frame(width: 21)
                TextField(L("Email"), text: $email)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .keyboardType(.emailAddress)
                    .textContentType(.username)
                    .textFieldStyle(.plain)
                    .submitLabel(.next)
                    .focused($focus, equals: .email)
                    .onSubmit { focus = .password }
            }
            .fieldBackground()

            HStack(spacing: 11) {
                Image(systemName: "lock")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
                    .frame(width: 21)
                Group {
                    if passwordVisible {
                        TextField(L("Password"), text: $password)
                            .textContentType(.password)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .focused($focus, equals: .password)
                    } else {
                        SecureField(L("Password"), text: $password)
                            .textContentType(.password)
                            .submitLabel(.done)
                            .focused($focus, equals: .password)
                    }
                }
                .textFieldStyle(.plain)

                Button {
                    passwordVisible.toggle()
                } label: {
                    Image(systemName: passwordVisible ? "eye.slash" : "eye")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.55))
                        .frame(width: 28, height: 32)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel(passwordVisible ? "Hide password" : "Show password")
            }
            .fieldBackground()

            Rectangle()
                .fill(.white.opacity(0.08))
                .frame(height: 1)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Theme.accent2)
                VStack(alignment: .leading, spacing: 4) {
                    Text("Protected account storage")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.88))
                    Text("Your password is stored in iOS Keychain. Sign-in communicates with Apple, and may use the selected authentication provider.")
                        .font(.system(size: 11))
                        .foregroundStyle(.white.opacity(0.48))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .padding(19)
        .background {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .fill(LinearGradient(colors: [.white.opacity(0.075), .white.opacity(0.025)],
                                     startPoint: .topLeading, endPoint: .bottomTrailing))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(LinearGradient(colors: [.white.opacity(0.2), Theme.accent.opacity(0.2), .white.opacity(0.05)],
                                             startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 1)
        }
    }

    private var actions: some View {
        VStack(spacing: 13) {
            Button {
                accounts.save(appleID: email, password: password)
                hasCompletedAccountSetup = true
            } label: {
                HStack(spacing: 10) {
                    Text("Continue to FrozenApps")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Spacer()
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .padding(.horizontal, 18)
            }
            .buttonStyle(PrimaryButtonStyle())
            .disabled(!canSave)
            .opacity(canSave ? 1 : 0.38)
            .animation(.snappy(duration: 0.25), value: canSave)

            Button("Set this up later") { hasCompletedAccountSetup = true }
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.53))
                .buttonStyle(.plain)
        }
    }
}'''
)
replace_section(
    "ios-app/AccountViews.swift",
    "struct AccountEditor: View {",
    None,
    r'''struct AccountEditor: View {
    @EnvironmentObject private var accounts: AccountStore
    @EnvironmentObject private var loc: Localizer
    @Environment(\.dismiss) private var dismiss

    let target: AccountEditorTarget

    @State private var email = ""
    @State private var password = ""
    @State private var passwordVisible = false
    @FocusState private var focus: AccountField?

    private var canSave: Bool {
        !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !password.isEmpty
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppBackground()
                ScrollView {
                    VStack(spacing: 20) {
                        VStack(spacing: 10) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Theme.brand)
                                Image(systemName: target.account == nil ? "person.crop.circle.badge.plus" : "person.crop.circle.badge.checkmark")
                                    .font(.system(size: 31, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            .frame(width: 70, height: 70)

                            Text("FROZENAPPS · ACCOUNT")
                                .font(.system(size: 9, weight: .heavy, design: .rounded))
                                .tracking(1.6)
                                .foregroundStyle(Theme.accent2)

                            Text(target.account == nil ? "Add Apple Account" : "Update Apple Account")
                                .font(.system(size: 25, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)

                            Text("Saved account details are reused by the signing workflow on this device.")
                                .font(.system(size: 12, weight: .medium))
                                .multilineTextAlignment(.center)
                                .foregroundStyle(.white.opacity(0.54))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.top, 12)

                        PanelCard {
                            VStack(alignment: .leading, spacing: 14) {
                                HStack(spacing: 10) {
                                    Image(systemName: "envelope")
                                        .foregroundStyle(Theme.accent2)
                                        .frame(width: 21)
                                    TextField(L("Email"), text: $email)
                                        .textInputAutocapitalization(.never)
                                        .autocorrectionDisabled()
                                        .keyboardType(.emailAddress)
                                        .textContentType(.username)
                                        .submitLabel(.next)
                                        .focused($focus, equals: .email)
                                        .onSubmit { focus = .password }
                                }
                                .fieldBackground()

                                HStack(spacing: 10) {
                                    Image(systemName: "lock")
                                        .foregroundStyle(Theme.accent2)
                                        .frame(width: 21)
                                    Group {
                                        if passwordVisible {
                                            TextField(L("Password"), text: $password)
                                                .textContentType(.password)
                                                .textInputAutocapitalization(.never)
                                                .autocorrectionDisabled()
                                                .focused($focus, equals: .password)
                                        } else {
                                            SecureField(L("Password"), text: $password)
                                                .textContentType(.password)
                                                .focused($focus, equals: .password)
                                        }
                                    }
                                    .textFieldStyle(.plain)

                                    Button { passwordVisible.toggle() } label: {
                                        Image(systemName: passwordVisible ? "eye.slash" : "eye")
                                            .foregroundStyle(.white.opacity(0.55))
                                            .frame(width: 28, height: 30)
                                            .contentShape(Rectangle())
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(passwordVisible ? "Hide password" : "Show password")
                                }
                                .fieldBackground()

                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundStyle(Theme.accent2)
                                    Text(target.account == nil
                                         ? "The password is stored in iOS Keychain. Authentication uses network access to Apple and may use the selected authentication provider."
                                         : "Enter the password again to replace the saved value. It will be stored in iOS Keychain.")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.white.opacity(0.5))
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: 520)
                    .frame(maxWidth: .infinity)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle(target.account == nil ? L("Add Apple Account") : L("Update Apple Account"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(L("Cancel")) { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Save")) {
                        accounts.save(appleID: email, password: password, replacing: target.account)
                        dismiss()
                    }
                    .disabled(!canSave)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .preferredColorScheme(.dark)
        }
        .onAppear {
            if let account = target.account { email = account.appleID }
            focus = target.account == nil ? .email : .password
        }
    }
}'''
)

replace_once(
    "ios-app/RootView.swift",
    '''    private enum Page: Hashable {
        case install, tools, about

        var wash: Backdrop.Level {
            switch self {
            case .install: .bright
            case .tools:   .dark
            // Same as Install, so switching between them doesn't change the backdrop.
            case .about:   .bright
            }
        }
    }''',
    '''    private enum Page: Hashable {
        case install, network, tools, settings, files

        var wash: Backdrop.Level {
            switch self {
            case .install, .network, .files: .bright
            case .tools, .settings: .dark
            }
        }
    }'''
)

# Make the engine Tools page read as FrozenApps while retaining its original utility routes.
replace_once(
    "ios-app/RootView.swift",
    '''    private var header: some View {
        Text(L("Tools"))
            .font(.largeTitle.weight(.bold))
            .frame(maxWidth: .infinity)
            .padding(.top, 8)
    }''',
    '''    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("FROZEN UTILITIES")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.6)
                        .foregroundStyle(Theme.accent2)
                    Text("Tools that do more.")
                        .font(.system(size: 25, weight: .bold, design: .rounded))
                        .tracking(-0.55)
                        .foregroundStyle(.white)
                    Text("Pairing, signing resources and app management.")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
                ZStack {
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(Theme.brand)
                    Image(systemName: "slider.horizontal.3")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .frame(width: 58, height: 58)
                .shadow(color: Theme.accent.opacity(0.3), radius: 14, x: 0, y: 6)
            }
            HStack(spacing: 8) {
                Label(Engine.deviceCanSelfPair ? "6 UTILITIES" : "5 UTILITIES",
                      systemImage: "square.grid.2x2.fill")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(0.8)
                    .foregroundStyle(.white.opacity(0.72))
                Spacer()
                Text("FROZENAPPS")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.35))
            }
        }
        .padding(19)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            ZStack(alignment: .topTrailing) {
                LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.09, blue: 0.24),
                        Color(red: 0.035, green: 0.11, blue: 0.19)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                Circle()
                    .fill(Theme.accent.opacity(0.18))
                    .frame(width: 150, height: 150)
                    .blur(radius: 30)
                    .offset(x: 40, y: -60)
            }
            .clipShape(RoundedRectangle(cornerRadius: 25, style: .continuous))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 25, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.22), Theme.accent.opacity(0.38), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }'''
)

replace_once(
    "ios-app/RootView.swift",
    '''    var body: some View {
        PanelCard {
            HStack(spacing: 14) {
                glyph
                    .frame(width: 46, height: 46)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                Text(title)
                    .font(.headline)
                if beta { BetaBadge() }
                Spacer(minLength: 8)
                Image(systemName: "chevron.right")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.tertiary)
            }
        }
    }''',
    '''    private var subtitle: String {
        switch image ?? icon ?? "" {
        case "SideBySideLogo": "Run a separate app workspace"
        case "PairingLogo": "Review or create a device pairing file"
        case "CertsLogo": "Inspect certificates used for signing"
        case "EntitlementsLogo": "Review app capability declarations"
        case "LocationLogo": "Manage location-related options"
        case "AppsLogo": "Review apps managed by this device"
        default: "Open a FrozenApps utility"
        }
    }

    var body: some View {
        HStack(spacing: 14) {
            glyph
                .frame(width: 50, height: 50)
                .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
            VStack(alignment: .leading, spacing: 5) {
                HStack(spacing: 8) {
                    Text(title)
                        .font(.system(size: 15, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                    if beta { BetaBadge() }
                }
                Text(subtitle)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.52))
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
            }
            Spacer(minLength: 4)
            ZStack {
                Circle()
                    .fill(Theme.accent2.opacity(0.12))
                    .frame(width: 31, height: 31)
                Image(systemName: "arrow.up.right")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Theme.accent2)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(LinearGradient(
                    colors: [.white.opacity(0.065), .white.opacity(0.022)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.17), Theme.accent.opacity(0.17), .white.opacity(0.04)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
    }'''
)

replace_once(
    "ios-app/RootView.swift",
    "    @State private var showSettings = false\n",
    ""
)
replace_once(
    "ios-app/RootView.swift",
    '''            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }''',
    '''            // Settings has its own FrozenApps tab.'''
)

replace_once(
    "ios-app/RootView.swift",
    '''        TabView(selection: $page) {
            ContentView()
                .tabItem { Label(L("Install"), systemImage: "square.and.arrow.down") }
                .tag(Page.install)
            ToolsView(pairingManager: pairingManager,
                      certManager: certManager,
                      locationManager: locationManager,
                      entitlementsManager: entitlementsManager,
                      appsManager: appsManager,
                      sideBySideManager: sideBySideManager)
                .tabItem { Label(L("Tools"), systemImage: "wrench.and.screwdriver") }
                .tag(Page.tools)
            AboutView()
                .tabItem { Label(L("About"), systemImage: "info.circle") }
                .tag(Page.about)
        }''',
    '''        TabView(selection: $page) {
            ContentView()
                .tabItem { Label("Signer", systemImage: "signature") }
                .tag(Page.install)
            FrozenNetworkView()
                .tabItem { Label("Network", systemImage: "point.3.connected.trianglepath.dotted") }
                .tag(Page.network)
            ToolsView(pairingManager: pairingManager,
                      certManager: certManager,
                      locationManager: locationManager,
                      entitlementsManager: entitlementsManager,
                      appsManager: appsManager,
                      sideBySideManager: sideBySideManager)
                .tabItem { Label("Tools", systemImage: "wrench.and.screwdriver") }
                .tag(Page.tools)
            FrozenFilesView()
                .tabItem { Label("Files", systemImage: "folder") }
                .tag(Page.files)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Page.settings)
        }'''
)

replace_once(
    "ios-app/RootView.swift",
    '''        .onChange(of: page) { _, page in Backdrop.settle(on: page.wash) }''',
    '''        .onChange(of: page) { _, page in Backdrop.settle(on: page.wash) }
        .onReceive(NotificationCenter.default.publisher(for: .frozenAppsOpenNetwork)) { _ in
            withAnimation(.smooth(duration: 0.25)) { page = .network }
        }'''
)


replace_once(
    "ios-app/RootView.swift",
    '''    @ViewBuilder
    private var glyph: some View {
        if let image {
            Image(image)
                .resizable()
                .scaledToFill()
        } else {
            ZStack {
                Rectangle().fill(Theme.brand)
                Image(systemName: icon ?? "questionmark")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(.white)
            }
        }
    }''',
    '''    private var resolvedIcon: String {
        switch image ?? "" {
        case "SideBySideLogo": "rectangle.3.group.fill"
        case "PairingLogo": "point.3.connected.trianglepath.dotted"
        case "CertsLogo": "checkmark.seal.fill"
        case "EntitlementsLogo": "lock.shield.fill"
        case "LocationLogo": "location.fill"
        case "AppsLogo": "square.grid.2x2.fill"
        default: icon ?? "snowflake"
        }
    }

    private var glyph: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .fill(LinearGradient(
                    colors: [Theme.accent.opacity(0.95), Theme.accent2.opacity(0.64)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
            Circle()
                .strokeBorder(.white.opacity(0.18), lineWidth: 1)
                .padding(5)
            Image(systemName: resolvedIcon)
                .font(.system(size: 21, weight: .semibold))
                .symbolRenderingMode(.hierarchical)
                .foregroundStyle(.white)
                .shadow(color: .black.opacity(0.12), radius: 4, x: 0, y: 2)
        }
    }'''
)

replace_once("ios-app/Theme.swift",
    "static let accent = Color(red: 0.13, green: 0.44, blue: 0.96)",
    "static let accent = Color(red: 0.43, green: 0.29, blue: 1.0)")
replace_once("ios-app/Theme.swift",
    "static let glow = Color(red: 1 / 255, green: 26 / 255, blue: 92 / 255)",
    "static let glow = Color(red: 0.035, green: 0.018, blue: 0.09)")
replace_once("ios-app/Theme.swift",
    "static let accent2 = Color(red: 0.30, green: 0.68, blue: 1.0)",
    "static let accent2 = Color(red: 0.20, green: 0.88, blue: 0.98)")
replace_once(
    "ios-app/Theme.swift",
    '''                Color.black.opacity(Backdrop.wash(at: t))
            }
            .ignoresSafeArea()''',
    '''                Color.black.opacity(Backdrop.wash(at: t))
                FrozenParticleOverlay(time: t)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            .ignoresSafeArea()'''
)

replace_once("ios-app/WelcomeView.swift",
    "@State private var accepted = false",
    "@State private var accepted = false\n    @State private var showTerms = false")
replace_once("ios-app/WelcomeView.swift",
    'Text(L("an app by Frizzle"))',
    'Text("On-device app installer")')
replace_once(
    "ios-app/WelcomeView.swift",
    '''            Link(destination: URL(string: "https://frizzlem.github.io/SideInstaller/terms.html")!) {
                Text("TOS")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                    .underline()
            }''',
    '''            Button { showTerms = true } label: {
                Text("Terms of Service")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.accent2)
                    .underline()
            }
            .buttonStyle(.plain)'''
)
replace_once(
    "ios-app/WelcomeView.swift",
    '''        .preferredColorScheme(.dark)
    }

    /// Notice for iOS below 27''',
    '''        .sheet(isPresented: $showTerms) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Use only with apps and files you are authorized to install. You are responsible for respecting Apple's terms, applicable laws, and account signing limits.")
                        Text("Local storage: the account details you enter are kept on this device, and the password is stored using iOS Keychain. FrozenApps does not operate a credential database or upload your password to a FrozenApps server.")
                        Text("Authentication: the installer communicates with Apple to authenticate and request developer signing resources. The selected Anisette provider may also receive protocol data needed to complete authentication. Local storage does not mean every network request stays on this device.")
                        Text("Device setup: supported versions may require LocalDevVPN, local-network permission, and user-approved Developer Mode. FrozenApps cannot turn Developer Mode on without your action.")
                        Text("Compatibility depends on iOS version, account eligibility, Apple service availability, and signing limits. These notes are not legal advice or a promise of legal immunity.")
                        Text("Installer engine attribution: SideInstaller by FrizzleM. Source and licence: github.com/FrizzleM/SideInstaller.")
                            .foregroundStyle(.secondary)
                    }
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(22)
                }
                .background(Color.black.ignoresSafeArea())
                .navigationTitle("Terms of Service")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") { showTerms = false }
                    }
                }
            }
            .preferredColorScheme(.dark)
        }
        .preferredColorScheme(.dark)
    }

    /// Notice for iOS below 27'''
)

replace_once(
    "ios-app/ContentView.swift",
    "@State private var showSettings = false",
    "// Settings are available in FrozenApps' dedicated bottom tab."
)
replace_once(
    "ios-app/ContentView.swift",
    """            .toolbar { settingsToolbarItem(isPresented: $showSettings) }
            .sheet(isPresented: $showSettings) { SettingsView() }""",
    """            // Settings is a dedicated tab in FrozenApps."""
)

replace_once("ios-app/AccountViews.swift",
    """Text(L("Don't worry, these are stored locally"))""",
    """Text("Password stored in iOS Keychain · No FrozenApps database")""")
replace_once(
    "ios-app/SettingsView.swift",
    '''                advancedSection
                logSection
            }''',
    '''                advancedSection
                logSection
                Section("About FrozenApps") {
                    Text("The on-device pairing and signing engine is based on SideInstaller by FrizzleM.")
                    Link("View upstream source and licence",
                         destination: URL(string: "https://github.com/FrizzleM/SideInstaller")!)
                    Text("FrozenApps has its own branding and UI changes. The upstream engine's custom licence remains in the source checkout.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }'''
)



replace_once(
    "ios-app/Engine.swift",
    '''SideInstaller couldn't reuse the certificate that's already there''',
    '''FrozenApps couldn't reuse the certificate that's already there'''
)
replace_once(
    "ios-app/AccountStore.swift",
    '''so it's kept only until SideInstaller quits.''',
    '''so it's kept only until FrozenApps quits.'''
)
replace_once(
    "ios-app/WelcomeView.swift",
    '''Text("SideInstaller")''',
    '''Text("FrozenApps")'''
)

# Keep the unused About page accurate if it is opened through a future navigation.
replace_once(
    "ios-app/AboutView.swift",
    'BrandHeader(icon: "info.circle.fill", image: "AppLogo", title: "SideInstaller",',
    'BrandHeader(icon: "info.circle.fill", image: "AppLogo", title: "FrozenApps",'
)
replace_once(
    "ios-app/AboutView.swift",
    'subtitle: L("an app by Frizzle")',
    'subtitle: "On-device installer"'
)
replace_once(
    "ios-app/AboutView.swift",
    '''Text(L("SideInstaller installs SideStore and LiveContainer straight onto your iPhone, with no PC involved."))''',
    '''Text(L("FrozenApps provides an on-device signing and installation workflow for compatible Apple devices."))'''
)
replace_once(
    "ios-app/AboutView.swift",
    '"https://github.com/FrizzleM/SideInstaller/tree/main"',
    '"https://github.com/itzmnyzzzXD/frozenapps"'
)

# Add a branded control-center card without changing the existing signer engine flow.
replace_once(
    "ios-app/ContentView.swift",
    '''                    header.cascadeItem(0)
                    if updateChecker.showBanner {''',
    '''                    header.cascadeItem(0)
                    FrozenHomePanel(
                        wifiConnected: engine.wifiConnected,
                        tunnelConnected: engine.vpnConnected,
                        deviceSummary: engine.deviceSummary
                    ) {
                        NotificationCenter.default.post(name: .frozenAppsOpenNetwork, object: nil)
                    }
                    .cascadeItem(1)
                    if updateChecker.showBanner {'''
)
replace_once(
    "ios-app/ContentView.swift",
    '''                    appCard.cascadeItem(1)''',
    '''                    appCard.cascadeItem(2)'''
)

# Use a dedicated FrozenApps visual identity on the Signer screen.
replace_once(
    "ios-app/ContentView.swift",
    '''    private var header: some View {
        BrandHeader(icon: "arrow.down.app.fill", image: "AppLogo", title: "SideInstaller",
                    animateIcon: engine.isRunning) {
            statusPill
                .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                .id(statusPillID)
        }
    }''',
    '''    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 13) {
                ZStack {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Theme.brand)
                        .shadow(color: Theme.accent.opacity(0.38), radius: 16, x: 0, y: 6)
                    Image(systemName: engine.isRunning ? "arrow.clockwise" : "snowflake")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(.white)
                }
                .frame(width: 52, height: 52)
                VStack(alignment: .leading, spacing: 3) {
                    Text("FROZENAPPS · ON-DEVICE")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.7)
                        .foregroundStyle(Theme.accent2)
                    Text("Your install studio")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer(minLength: 0)
            }
            HStack(spacing: 10) {
                statusPill
                    .transition(.opacity.combined(with: .scale(scale: 0.85, anchor: .top)))
                    .id(statusPillID)
                Spacer(minLength: 0)
                Text("PRIVATE WORKSPACE")
                    .font(.system(size: 9, weight: .bold, design: .rounded))
                    .tracking(1.2)
                    .foregroundStyle(.white.opacity(0.42))
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LinearGradient(
                    colors: [
                        Color(red: 0.12, green: 0.10, blue: 0.24),
                        Color(red: 0.04, green: 0.13, blue: 0.20)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
        }
        .overlay {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.24), Theme.accent.opacity(0.42), .white.opacity(0.05)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        }
        .shadow(color: Theme.accent.opacity(0.12), radius: 20, x: 0, y: 8)
    }'''
)
replace_once(
    "ios-app/ContentView.swift",
    '''    private var footer: some View {
        Text(L("an app by Frizzle"))
            .font(.caption)
            .foregroundStyle(.secondary)
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
    }''',
    '''    private var footer: some View {
        Text("FROZENAPPS  ·  YOUR DEVICE, YOUR WORKFLOW")
            .font(.system(size: 9, weight: .semibold, design: .rounded))
            .tracking(1.2)
            .foregroundStyle(.white.opacity(0.34))
            .frame(maxWidth: .infinity)
            .padding(.top, 10)
    }'''
)
replace_once(
    "ios-app/SettingsView.swift",
    '''            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(L("Done")) { dismiss() }
                }
            }''',
    '''            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Text("1.0.3")
                        .font(.system(size: 10, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.accent2)
                }
            }'''
)


replace_once(
    "ios-app/ContentView.swift",
    '''    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 10) {
                Text(progressTitle)
                    .font(.headline)
                    .contentTransition(.opacity)
                Spacer(minLength: 4)
                Text("\\(Int(engine.overallProgress * 100))%")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(progressTint)
                    .contentTransition(.numericText(value: engine.overallProgress))
                    .animation(.smooth(duration: 0.3), value: engine.overallProgress)
                stepsDisclosure
                // Only a run in flight can be cancelled.
                if engine.isRunning {
                    cancelButton
                        .transition(.opacity.combined(with: .scale(scale: 0.6)))
                }
            }

            InstallProgressBar(progress: engine.overallProgress,
                               tint: progressTint,
                               gradient: progressGradient,
                               animating: engine.isRunning && !engine.finished && !runFailed)

            stepSection
        }
    }''',
    '''    private var progressContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .center, spacing: 14) {
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.09), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: max(0.001, min(1, engine.overallProgress)))
                        .stroke(progressGradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 1) {
                        Text("\\(Int(engine.overallProgress * 100))%")
                            .font(.system(size: 18, weight: .bold, design: .rounded).monospacedDigit())
                            .foregroundStyle(progressTint)
                            .contentTransition(.numericText(value: engine.overallProgress))
                        Text("DONE")
                            .font(.system(size: 8, weight: .heavy, design: .rounded))
                            .tracking(1)
                            .foregroundStyle(.white.opacity(0.43))
                    }
                }
                .frame(width: 72, height: 72)
                .animation(.smooth(duration: 0.3), value: engine.overallProgress)

                VStack(alignment: .leading, spacing: 5) {
                    Text(progressTitle.uppercased())
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.5)
                        .foregroundStyle(progressTint)
                    Text(currentStep.title(for: engine.installSource))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\\(Step.allCases.filter { engine.stepStates[$0] == .done }.count) of \\(Step.allCases.count) steps complete")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.46))
                }

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    stepsDisclosure
                    if engine.isRunning {
                        cancelButton
                            .transition(.opacity.combined(with: .scale(scale: 0.6)))
                    }
                }
            }

            InstallProgressBar(progress: engine.overallProgress,
                               tint: progressTint,
                               gradient: progressGradient,
                               animating: engine.isRunning && !engine.finished && !runFailed)

            stepSection
        }
    }'''
)
replace_once(
    "ios-app/ContentView.swift",
    '''            if engine.isImportingIPA, let fraction = engine.importProgress {
                ProgressView(value: fraction)
                    .tint(Theme.accent2)
            }''',
    '''            if engine.isImportingIPA, let fraction = engine.importProgress {
                HStack(spacing: 10) {
                    ProgressView(value: fraction)
                        .tint(Theme.accent2)
                    Text("\\(Int(fraction * 100))%")
                        .font(.system(size: 11, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(Theme.accent2)
                        .contentTransition(.numericText(value: fraction))
                        .animation(.smooth(duration: 0.25), value: fraction)
                }
            }'''
)

replace_once(
    "ios-app/ContentView.swift",
    '''Text(L("SideInstaller %@ is available — you're on %@.",''',
    '''Text(L("FrozenApps %@ is available — you're on %@.",'''
)
replace_once(
    "ios-app/ContentView.swift",
    '''Text(L("This iPhone runs iOS %@, which SideInstaller can't install on. Update to iOS %@ or later in Settings › General › Software Update.",''',
    '''Text(L("This iPhone runs iOS %@, which FrozenApps can't run on. Update to iOS %@ or later in Settings › General › Software Update.",'''
)
replace_once(
    "ios-app/ContentView.swift",
    '''Text(L("Connect to a Wi-Fi network. Pairing this iPhone needs it — SideInstaller has to be findable on the local network."))''',
    '''Text(L("Connect to a Wi-Fi network. Pairing this device needs it — FrozenApps has to be findable on the local network."))'''
)
replace_once(
    "ios-app/SettingsView.swift",
    '''Text(L("No Apple ID saved yet. Add one and SideInstaller will use it for every sign-in."))''',
    '''Text(L("No Apple ID saved yet. Add one and FrozenApps will use it for every sign-in."))'''
)
replace_once(
    "ios-app/UpdateChecker.swift",
    '"https://raw.githubusercontent.com/FrizzleM/SideInstaller/main/latest_version.txt"',
    '"https://raw.githubusercontent.com/itzmnyzzzXD/frozenapps/main/latest_version.txt"'
)
replace_once(
    "ios-app/UpdateChecker.swift",
    'static let installPageURL = "https://frizzlem.github.io/SideInstaller/"',
    'static let installPageURL = "https://github.com/itzmnyzzzXD/frozenapps/releases"'
)
replace_once(
    "ios-app/UpdateChecker.swift",
    'req.setValue("SideInstaller", forHTTPHeaderField: "User-Agent")',
    'req.setValue("FrozenApps", forHTTPHeaderField: "User-Agent")'
)

# Generate all declared app-icon sizes from the FrozenApps vector design.
subprocess.run(["swift", str(ROOT / "scripts" / "generate-app-icon.swift")], cwd=ROOT, check=True)

print("Applied FrozenApps branding to pinned engine source.")
