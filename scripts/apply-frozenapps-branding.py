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
# Request local-network access only for FrozenApps' explicit diagnostics flow.
if "<key>NSLocalNetworkUsageDescription</key>" not in txt or "<key>NSBonjourServices</key>" not in txt:
    entries = []
    if "<key>NSLocalNetworkUsageDescription</key>" not in txt:
        entries.append(
            "\t<key>NSLocalNetworkUsageDescription</key>\n"
            "\t<string>FrozenApps uses your local network to help diagnose Wi-Fi connectivity and discover nearby services for device setup.</string>\n"
        )
    if "<key>NSBonjourServices</key>" not in txt:
        entries.append(
            "\t<key>NSBonjourServices</key>\n"
            "\t<array>\n"
            "\t\t<string>_http._tcp</string>\n"
            "\t</array>\n"
        )
    close_index = txt.rfind("</dict>")
    if close_index < 0:
        raise SystemExit("Could not find the top-level Info.plist dictionary end.")
    txt = txt[:close_index] + "".join(entries) + txt[close_index:]
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
            FrozenFilesView()
                .tabItem { Label("Files", systemImage: "folder") }
                .tag(Page.files)
            SettingsView()
                .tabItem { Label("Settings", systemImage: "slider.horizontal.3") }
                .tag(Page.settings)
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

# Use FrozenApps identity in the actual signer header and user-facing messaging.
replace_once(
    "ios-app/ContentView.swift",
    'BrandHeader(icon: "arrow.down.app.fill", image: "AppLogo", title: "SideInstaller",',
    'BrandHeader(icon: "signature", title: "FrozenApps",'
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
