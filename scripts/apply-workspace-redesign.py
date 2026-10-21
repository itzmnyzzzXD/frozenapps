#!/usr/bin/env python3
"""Apply the structural FrozenApps workspace UI on every clean build.

Authentication, AccountStore, Engine and the existing pairing/signing/install callbacks
are deliberately outside this patch. Login and two-factor screens are not replaced.
"""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Vendor" / "SideInstaller" / "ios-app"


def replace_owned(path: Path, owner: str, start_marker: str, end_marker: str, replacement: str) -> None:
    source = path.read_text(encoding="utf-8")
    if replacement.strip() in source:
        return
    owner_at = source.find(owner)
    if owner_at < 0:
        raise SystemExit(f"Missing declaration in {path.name}: {owner!r}")
    start = source.find(start_marker, owner_at)
    if start < 0:
        raise SystemExit(f"Missing section start in {path.name}: {start_marker[:90]!r}")
    end = source.find(end_marker, start + len(start_marker))
    if end < 0:
        raise SystemExit(f"Missing section end in {path.name}: {end_marker[:90]!r}")
    path.write_text(source[:start] + replacement.rstrip() + "\n" + source[end:], encoding="utf-8")


def insert_before(path: Path, marker: str, addition: str) -> None:
    source = path.read_text(encoding="utf-8")
    if addition.strip() in source:
        return
    count = source.count(marker)
    if count != 1:
        raise SystemExit(f"Expected one insertion marker in {path.name}, found {count}: {marker!r}")
    path.write_text(source.replace(marker, addition.rstrip() + "\n\n" + marker, 1), encoding="utf-8")


for required in ("RootView.swift", "ContentView.swift"):
    if not (APP / required).is_file():
        raise SystemExit(f"Missing generated app source {APP / required}. Run the branding patch first.")


# Floating vertical workspace rail on iPad and compact bottom dock on smaller screens.
replace_owned(
    APP / "RootView.swift",
    "struct RootView: View {",
    "    private var navigationHeader: some View {",
    "    // MARK: Popups",
    r'''    private var currentPageID: String {
        switch page {
        case .install: "signer"
        case .center: "center"
        case .network: "network"
        case .tools: "tools"
        case .files: "files"
        case .settings: "settings"
        }
    }

    private func selectPageID(_ id: String) {
        switch id {
        case "signer": selectPage(.install)
        case "center": selectPage(.center)
        case "network": selectPage(.network)
        case "tools": selectPage(.tools)
        case "files": selectPage(.files)
        case "settings": selectPage(.settings)
        default: break
        }
    }

    private var navigationHeader: some View {
        FrozenWorkspaceCommandBar(
            title: currentPageTitle,
            symbol: currentPageSymbol,
            selectedID: currentPageID,
            onSelect: selectPageID
        )
    }

    private var workspaceTabs: some View {
        TabView(selection: $page) {
            ContentView()
                .tabItem { Label("Signer", systemImage: "signature") }
                .tag(Page.install)
            FrozenControlCenterView()
                .tabItem { Label("Frozen Center", systemImage: "square.grid.2x2") }
                .tag(Page.center)
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
        }
        .toolbar(.hidden, for: .tabBar)
        .background(Color.clear)
    }

    var body: some View {
        GeometryReader { proxy in
            ZStack {
                FrozenWorkspaceBackdrop()
                if proxy.size.width >= 760 {
                    HStack(alignment: .center, spacing: 16) {
                        FrozenWorkspaceRail(selectedID: currentPageID, compact: false, onSelect: selectPageID)
                            .padding(.leading, 15)
                            .padding(.vertical, 18)
                        VStack(spacing: 12) {
                            navigationHeader
                            workspaceTabs
                        }
                        .padding(.vertical, 14)
                        .padding(.trailing, 16)
                    }
                } else {
                    VStack(spacing: 8) {
                        navigationHeader
                            .padding(.horizontal, 12)
                            .padding(.top, 7)
                        workspaceTabs
                        FrozenWorkspaceRail(selectedID: currentPageID, compact: true, onSelect: selectPageID)
                            .padding(.horizontal, 12)
                            .padding(.bottom, 8)
                    }
                }
            }
        }
        .onChange(of: page) { _, page in Backdrop.settle(on: page.wash) }
        .onReceive(NotificationCenter.default.publisher(for: .frozenAppsOpenNetwork)) { _ in
            withAnimation(.smooth(duration: 0.25)) { page = .network }
        }
        .popupStack(entries, onBackdropTap: backdropTap) { entry in
            card(for: entry)
        }
        .environmentObject(certManager)
        .onChange(of: accounts.revision) { _, _ in
            engine.forgetAppleSession()
            certManager.signOut()
            entitlementsManager.signOut()
            sideBySideManager.signOut()
        }
        .tint(Theme.accent)
        .preferredColorScheme(.dark)
        .sheet(isPresented: Binding(
            get: { engine.twoFactor != nil },
            set: { if !$0 { engine.cancelTwoFactor() } }
        )) {
            if let phase = engine.twoFactor ?? shownTwoFactor {
                TwoFactorSheet(phase: phase)
            }
        }
        .onChange(of: engine.twoFactor) { _, phase in
            if let phase { shownTwoFactor = phase }
        }
    }'''
)

# Replace the stacked installer layout with a responsive two-column workspace.
# The existing Engine callbacks, requirements, importers and progress content remain.
replace_owned(
    APP / "ContentView.swift",
    "struct ContentView: View {",
    "    var body: some View {",
    "    // MARK: Derived visibility",
    r'''    var body: some View {
        NavigationStack {
            ZStack {
                FrozenWorkspaceBackdrop()
                GeometryReader { proxy in
                    let wideLayout = proxy.size.width >= 860
                    ScrollView {
                        VStack(alignment: .leading, spacing: 17) {
                            header
                            if updateChecker.showBanner {
                                updateBanner.transition(.opacity)
                            }

                            if wideLayout {
                                HStack(alignment: .top, spacing: 16) {
                                    VStack(alignment: .leading, spacing: 15) {
                                        appCard
                                        installSurface
                                        if showProgress && !engine.isRunning {
                                            installButton
                                                .transition(.asymmetric(insertion: .identity, removal: .tuckUnder))
                                        }
                                        footer
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                    VStack(alignment: .leading, spacing: 14) {
                                        connectionCard
                                        if showsPairingCard { pairingFileCard }
                                        if !engine.isRunning {
                                            if !engine.osSupported {
                                                osRequirement
                                            } else if !engine.wifiConnected && engine.needsFreshPairing && engine.canSelfPair {
                                                wifiRequirement
                                            } else if !engine.tunnelAvailable {
                                                vpnRequirement
                                            }
                                        }
                                        if showsAdvanced {
                                            FrozenWorkspacePanel(cornerRadius: 20) { advancedSection }
                                        }
                                        FrozenWorkspacePanel(cornerRadius: 20) {
                                            VStack(alignment: .leading, spacing: 7) {
                                                Label("Signing workflow", systemImage: "info.circle")
                                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                                    .foregroundStyle(.white)
                                                Text("Pairing, authentication, provisioning, signing and installation still run through the existing engine. This panel reports readiness without bypassing device prompts.")
                                                    .font(.system(size: 10, weight: .medium))
                                                    .lineSpacing(2)
                                                    .foregroundStyle(.white.opacity(0.57))
                                                    .fixedSize(horizontal: false, vertical: true)
                                            }
                                        }
                                    }
                                    .frame(width: min(max(proxy.size.width * 0.31, 265), 330))
                                }
                            } else {
                                appCard
                                if showsPairingCard { pairingFileCard }
                                if !engine.isRunning {
                                    if !engine.osSupported {
                                        osRequirement
                                    } else if !engine.wifiConnected && engine.needsFreshPairing && engine.canSelfPair {
                                        wifiRequirement
                                    } else if !engine.tunnelAvailable {
                                        vpnRequirement
                                    }
                                }
                                installSurface
                                if showProgress && !engine.isRunning {
                                    installButton
                                        .transition(.asymmetric(insertion: .identity, removal: .tuckUnder))
                                }
                                if showsAdvanced {
                                    FrozenWorkspacePanel(cornerRadius: 20) { advancedSection }
                                }
                                connectionCard
                                footer
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: 1260)
                        .frame(maxWidth: .infinity)
                        .animation(.smooth(duration: 0.30), value: engine.isRunning)
                        .animation(.smooth(duration: 0.30), value: engine.finished)
                        .animation(.smooth(duration: 0.30), value: engine.deviceSummary)
                        .animation(.smooth(duration: 0.30), value: updateChecker.showBanner)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .sheet(isPresented: $showInstallCatalog) { FrozenSignerInstallCatalogView() }
            .sheet(isPresented: $showImporter) {
                FileImporterRepresentableView(allowedContentTypes: [.ipa]) { urls in
                    guard let url = urls.first else { return }
                    Task { await engine.importCustomIPA(from: url) }
                }
                .ignoresSafeArea()
            }
            .sheet(isPresented: $showPairingImporter) {
                FileImporterRepresentableView(allowedContentTypes: UTType.pairingFileTypes) { urls in
                    guard let url = urls.first else { return }
                    Task { await engine.importPairingFile(from: url) }
                }
                .ignoresSafeArea()
            }
            .scrollDismissesKeyboard(.interactively)
        }
    }'''
)

replace_owned(
    APP / "ContentView.swift",
    "struct ContentView: View {",
    "    private var header: some View {",
    "    /// A stable identity so the pill cross-fades when its meaning changes.",
    r'''    private var header: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("INSTALLATION WORKSPACE")
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.56))
                Text("Prepare an install")
                    .font(.system(size: 25, weight: .bold, design: .rounded))
                    .tracking(-0.65)
                    .foregroundStyle(.white)
            }
            Spacer(minLength: 8)
            statusPill
                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                .id(statusPillID)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }'''
)

replace_owned(
    APP / "ContentView.swift",
    "struct ContentView: View {",
    "    private var appCard: some View {",
    "    /// The two ways in for a custom build: pick a file, or paste a link.",
    r'''    private var appCard: some View {
        FrozenWorkspacePanel(cornerRadius: 23, elevated: true) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    sectionTitle(L("Install"), systemImage: "square.and.arrow.down.fill")
                    Spacer()
                    Text("PACKAGE SOURCE")
                        .font(.system(size: 8, weight: .heavy, design: .rounded))
                        .tracking(1.1)
                        .foregroundStyle(.white.opacity(0.48))
                }
                Text("Choose a package")
                    .font(.system(size: 17, weight: .semibold, design: .rounded))
                    .foregroundStyle(.white)
                Text("Select a maintained build, or bring your own IPA.")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.53))

                Menu {
                    Picker(L("Install"), selection: $engine.installSource) {
                        ForEach(InstallSource.allCases) { src in Text(src.displayName).tag(src) }
                    }
                    Divider()
                    Button { showInstallCatalog = true } label: {
                        Label("Browse app catalog", systemImage: "square.grid.2x2.fill")
                    }
                    Button {
                        engine.installSource = .custom
                        showImporter = true
                    } label: {
                        Label("Choose IPA from Files", systemImage: "folder.badge.plus")
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.13))
                            Image(systemName: engine.installSource == .custom ? "doc.zipper" : "app.dashed")
                                .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                        }
                        .frame(width: 43, height: 43)
                        VStack(alignment: .leading, spacing: 4) {
                            Text(engine.installSource.displayName)
                                .font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                            Text(engine.installSource == .custom
                                 ? (engine.customIPAName ?? "Choose a local package")
                                 : "Choose release or configure version")
                                .font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.49)).lineLimit(1)
                        }
                        Spacer(minLength: 4)
                        Image(systemName: "chevron.up.chevron.down").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.70))
                    }
                    .padding(12)
                    .frozenGlassSurface(cornerRadius: 16, tint: .white.opacity(0.04))
                }

                if engine.installSource == .custom || engine.installSource.hasNightly {
                    ZStack {
                        if engine.installSource == .custom {
                            importControl.transition(.opacity)
                        } else {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Release channel")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.55))
                                Picker(L("Release"), selection: $engine.releaseChannel) {
                                    ForEach(ReleaseChannel.allCases) { channel in Text(channel.displayName).tag(channel) }
                                }
                                .pickerStyle(.segmented)
                            }
                            .transition(.opacity)
                        }
                    }
                }

                Button { showInstallCatalog = true } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "square.grid.2x2.fill")
                        Text("Explore app catalog").font(.system(size: 12, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.85))
                    .padding(12)
                    .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.12), lineWidth: 1) }
                }
                .buttonStyle(FrozenWorkspacePressStyle())
                .accessibilityHint("Browse public app sources and actual release assets.")
            }
            .animation(.smooth(duration: 0.25), value: engine.installSource)
        }
        .disabled(engine.isRunning)
    }'''
)

replace_owned(
    APP / "ContentView.swift",
    "struct ContentView: View {",
    "    private var installSurface: some View {",
    "    /// True while the surface is the button and is held down.",
    r'''    private var installSurface: some View {
        let shape = RoundedRectangle(cornerRadius: showProgress ? 22 : 18, style: .continuous)
        return ZStack(alignment: .top) {
            if showProgress {
                progressContent
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(18)
                    .transition(.surfaceSwap)
            } else {
                Button(action: startInstall) {
                    HStack(spacing: 12) {
                        Image(systemName: engine.finished ? "arrow.clockwise" : "arrow.down.to.line")
                            .font(.system(size: 16, weight: .semibold))
                        VStack(alignment: .leading, spacing: 3) {
                            Text(engine.finished ? L("Reinstall") : L("Install %@", installTargetName))
                                .font(.system(size: 15, weight: .semibold, design: .rounded))
                            Text("Run the existing signing pipeline")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.60))
                        }
                        Spacer()
                        Image(systemName: "arrow.right").font(.system(size: 12, weight: .semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 17)
                    .padding(.vertical, 18)
                    .contentShape(Rectangle())
                }
                .buttonStyle(PressReportingButtonStyle(isPressed: $installPressed))
                .transition(.surfaceSwap)
            }
        }
        .frame(maxWidth: .infinity)
        .clipShape(shape)
        .background {
            shape.fill(.regularMaterial)
                .overlay {
                    shape.fill(LinearGradient(
                        colors: [Color.white.opacity(0.17), Color.white.opacity(0.065), Color.black.opacity(0.10)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                }
        }
        .overlay {
            shape.strokeBorder(LinearGradient(
                colors: [.white.opacity(0.40), Color.white.opacity(0.12), .white.opacity(0.20)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ), lineWidth: 1)
        }
        .shadow(color: Color.black.opacity(0.22), radius: 22, x: 0, y: 9)
        .scaleEffect(surfacePressed ? 0.985 : 1)
        .animation(.snappy(duration: 0.22), value: surfacePressed)
        .alert(L("Cancel the install?"), isPresented: $confirmingCancel) {
            Button(L("Yes"), role: .destructive) { engine.cancelOneClick() }
            Button(L("No"), role: .cancel) { }
        }
        .onChange(of: engine.isRunning) { _, running in
            if !running { confirmingCancel = false }
        }
    }'''
)

insert_before(
    APP / "ContentView.swift",
    "    // MARK: Footer",
    r'''    private var connectionCard: some View {
        FrozenWorkspacePanel(cornerRadius: 21, elevated: true) {
            VStack(alignment: .leading, spacing: 13) {
                HStack {
                    Text("DEVICE & CONNECTION")
                        .font(.system(size: 9, weight: .heavy, design: .rounded))
                        .tracking(1.35)
                        .foregroundStyle(.white.opacity(0.55))
                    Spacer()
                    Image(systemName: "point.3.connected.trianglepath.dotted")
                        .foregroundStyle(.white.opacity(0.70))
                }
                HStack(spacing: 10) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.12))
                        Image(systemName: engine.deviceSummary == nil ? "iphone.gen3" : "iphone.gen3.radiowaves.left.and.right")
                            .font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
                    }
                    .frame(width: 42, height: 42)
                    VStack(alignment: .leading, spacing: 3) {
                        Text(engine.deviceSummary ?? "No paired device yet")
                            .font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
                        Text(engine.deviceSummary == nil ? "Pairing will be checked when you install" : "Device reported by the existing engine")
                            .font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.52))
                    }
                    Spacer(minLength: 0)
                }
                Rectangle().fill(.white.opacity(0.12)).frame(height: 1)
                HStack(spacing: 8) {
                    statusCell(engine.wifiConnected ? "Wi-Fi ready" : "Wi-Fi needed", symbol: engine.wifiConnected ? "wifi" : "wifi.slash", ready: engine.wifiConnected)
                    statusCell(engine.vpnConnected ? "Tunnel active" : "Tunnel idle", symbol: engine.vpnConnected ? "shield.lefthalf.filled" : "shield.slash", ready: engine.vpnConnected)
                }
                Button {
                    NotificationCenter.default.post(name: .frozenAppsOpenNetwork, object: nil)
                } label: {
                    HStack(spacing: 8) {
                        Text("Open connection center").font(.system(size: 11, weight: .semibold))
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                    }
                    .foregroundStyle(.white.opacity(0.84))
                    .padding(.vertical, 9)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func statusCell(_ title: String, symbol: String, ready: Bool) -> some View {
        HStack(spacing: 6) {
            Image(systemName: symbol).font(.system(size: 10, weight: .semibold))
            Text(title).font(.system(size: 9, weight: .semibold)).lineLimit(1)
        }
        .foregroundStyle(ready ? Color.white : Color.white.opacity(0.61))
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 9).padding(.vertical, 10)
        .background(.white.opacity(ready ? 0.10 : 0.045), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
        .overlay { RoundedRectangle(cornerRadius: 11, style: .continuous).strokeBorder(.white.opacity(ready ? 0.16 : 0.075), lineWidth: 1) }
    }'''
)

# Tools becomes an adaptive utility grid while retaining the existing navigation destinations.
replace_owned(
    APP / "RootView.swift",
    "struct ToolsView: View {",
    "    var body: some View {",
    "    /// Cascade index for rows below Pairing, shifted by one when that row is shown.",
    r'''    var body: some View {
        NavigationStack {
            ZStack {
                FrozenWorkspaceBackdrop()
                GeometryReader { proxy in
                    ScrollView {
                        VStack(alignment: .leading, spacing: 18) {
                            header
                            LazyVGrid(
                                columns: [GridItem(.adaptive(minimum: proxy.size.width > 780 ? 230 : 265), spacing: 13)],
                                spacing: 13
                            ) {
                                NavigationLink {
                                    SideBySideView(manager: sideBySideManager)
                                } label: {
                                    ToolRow(image: "SideBySideLogo", title: L("Side by Side"), beta: true)
                                }
                                .buttonStyle(.plain)

                                if Engine.deviceCanSelfPair {
                                    NavigationLink {
                                        PairingView(manager: pairingManager)
                                    } label: {
                                        ToolRow(image: "PairingLogo", title: L("Pairing"))
                                    }
                                    .buttonStyle(.plain)
                                }

                                NavigationLink {
                                    CertsView(manager: certManager)
                                } label: {
                                    ToolRow(image: "CertsLogo", title: L("Certificates"))
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    EntitlementsView(manager: entitlementsManager)
                                } label: {
                                    ToolRow(image: "EntitlementsLogo", title: L("Entitlements"))
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    LocationView(manager: locationManager)
                                } label: {
                                    ToolRow(image: "LocationLogo", title: L("Location spoofing"))
                                }
                                .buttonStyle(.plain)

                                NavigationLink {
                                    AppsView(manager: appsManager)
                                } label: {
                                    ToolRow(image: "AppsLogo", title: L("Sideloaded apps"))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(18)
                        .frame(maxWidth: 1120)
                        .frame(maxWidth: .infinity)
                    }
                    .scrollIndicators(.hidden)
                }
            }
            .navigationTitle("Tools")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
        }
    }'''
)

print("Applied FrozenApps structural workspace redesign.")
