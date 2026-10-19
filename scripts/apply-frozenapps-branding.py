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
