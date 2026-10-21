#!/usr/bin/env python3
"""Replace the settings Form with real glass cards while retaining existing bound actions."""
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
        raise SystemExit(f"Missing start marker in {path.name}: {start_marker[:90]!r}")
    end = source.find(end_marker, start + len(start_marker))
    if end < 0:
        raise SystemExit(f"Missing end marker in {path.name}: {end_marker[:90]!r}")
    path.write_text(source[:start] + replacement.rstrip() + "\n" + source[end:], encoding="utf-8")


def insert_before(path: Path, marker: str, addition: str) -> None:
    source = path.read_text(encoding="utf-8")
    if addition.strip() in source:
        return
    count = source.count(marker)
    if count != 1:
        raise SystemExit(f"Expected one insertion marker in {path.name}, found {count}: {marker!r}")
    path.write_text(source.replace(marker, addition.rstrip() + "\n\n" + marker, 1), encoding="utf-8")


path = APP / "SettingsView.swift"
if not path.is_file():
    raise SystemExit("SettingsView.swift is missing. Run the branding patch first.")

replace_owned(
    path,
    "struct SettingsView: View {",
    "    var body: some View {",
    "    // MARK: Account",
    r'''    var body: some View {
        NavigationStack {
            ZStack {
                FrozenWorkspaceBackdrop()
                ScrollView {
                    VStack(alignment: .leading, spacing: 15) {
                        FrozenWorkspacePageHeader(
                            eyebrow: "FrozenApps / Preferences",
                            title: "Settings",
                            description: "Accounts, device connection, cached packages and diagnostics in one place.",
                            symbol: "slider.horizontal.3"
                        )
                        accountsCard
                        appearanceCard
                        tunnelCard
                        downloadsCard
                        anisetteCard
                        advancedCard
                        activityCard
                    }
                    .padding(18)
                    .frame(maxWidth: 980)
                    .frame(maxWidth: .infinity)
                }
                .scrollIndicators(.hidden)
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar(.hidden, for: .navigationBar)
            .sheet(item: $editorTarget) { AccountEditor(target: $0) }
            .alert(L("Remove this Apple ID?"),
                   isPresented: Binding(get: { pendingRemove != nil },
                                        set: { if !$0 { pendingRemove = nil } })) {
                Button(L("Remove"), role: .destructive) {
                    if let account = pendingRemove { accounts.remove(account) }
                    pendingRemove = nil
                }
                Button(L("Cancel"), role: .cancel) { pendingRemove = nil }
            } message: {
                if let account = pendingRemove {
                    Text(L("“%@” and its saved password will be deleted from this iPhone. Nothing changes on your Apple account.", account.appleID))
                }
            }
            .onAppear {
                anisetteIsCustom = !engine.anisetteServers.contains { $0.address == engine.anisetteURL }
                downloadsManager.refresh()
            }
            .alert(L("Delete this download?"),
                   isPresented: Binding(get: { pendingDelete != nil },
                                        set: { if !$0 { pendingDelete = nil } })) {
                Button(L("Delete"), role: .destructive) {
                    if let item = pendingDelete { downloadsManager.delete(item) }
                    pendingDelete = nil
                }
                Button(L("Cancel"), role: .cancel) { pendingDelete = nil }
            } message: {
                if let item = pendingDelete {
                    Text(L("“%@” (%@) will be removed. You can download it again any time from the Install tab.", item.fileName, item.sizeText))
                }
            }
        }
    }'''
)

insert_before(
    path,
    "    // MARK: Account",
    r'''    private var accountsCard: some View {
        FrozenWorkspacePanel(cornerRadius: 22, elevated: true) {
            VStack(alignment: .leading, spacing: 12) {
                settingsCardHeading("Apple Account", subtitle: "Saved credentials use the existing iOS Keychain store.", symbol: "person.crop.circle")
                if accounts.accounts.isEmpty {
                    Text(L("No Apple ID saved yet. Add one and FrozenApps will use it for every sign-in."))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.58))
                }
                ForEach(accounts.accounts) { account in
                    HStack(spacing: 8) {
                        Button { accounts.activate(account) } label: {
                            accountRow(account)
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            editorTarget = .existing(account)
                        } label: {
                            Image(systemName: "pencil")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.74))
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.075), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Edit Apple Account")

                        Button(role: .destructive) {
                            pendingRemove = account
                        } label: {
                            Image(systemName: "trash")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.74))
                                .frame(width: 34, height: 34)
                                .background(.white.opacity(0.075), in: Circle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove Apple Account")
                    }

                    if account.id != accounts.accounts.last?.id {
                        Rectangle().fill(.white.opacity(0.10)).frame(height: 1)
                    }
                }

                if let warning = accounts.keychainWarning {
                    Label(warning, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }

                Button { editorTarget = .new } label: {
                    Label(L("Add Apple Account"), systemImage: "plus")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .padding(12)
                        .background(.white.opacity(0.09), in: Capsule())
                        .overlay { Capsule().strokeBorder(.white.opacity(0.16), lineWidth: 1) }
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var appearanceCard: some View {
        FrozenWorkspacePanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                settingsCardHeading("Language", subtitle: "App labels update immediately.", symbol: "character.bubble")
                Picker(L("App language"), selection: $loc.language) {
                    ForEach(AppLanguage.allCases) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(.menu)
                .tint(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var tunnelCard: some View {
        FrozenWorkspacePanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                settingsCardHeading("Connection tunnel", subtitle: "The install flow still checks requirements before it runs.", symbol: "shield.lefthalf.filled")
                Toggle(L("Start LocalDevVPN when needed"), isOn: $engine.autoStartVPN)
                    .font(.system(size: 12, weight: .medium))
                    .tint(.white)
                    .foregroundStyle(.white)

                Button { engine.startLocalDevVPN() } label: {
                    HStack {
                        Label(L("Start LocalDevVPN now"), systemImage: "bolt.horizontal.circle")
                        Spacer()
                        Image(systemName: "arrow.up.right").font(.system(size: 10, weight: .bold))
                    }
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(.white.opacity(0.075), in: RoundedRectangle(cornerRadius: 13, style: .continuous))
                    .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.13), lineWidth: 1) }
                }
                .buttonStyle(.plain)
                .disabled(!engine.localDevVPNInstalled)

                if !engine.localDevVPNInstalled {
                    Text(L("LocalDevVPN isn't installed. Get it from the App Store, and this can start it for you."))
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.49))
                }
            }
        }
    }

    private var downloadsCard: some View {
        FrozenWorkspacePanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    settingsCardHeading("Downloaded IPAs", subtitle: "Packages cached by the existing install flow.", symbol: "arrow.down.app")
                    Spacer()
                    if !downloadsManager.downloads.isEmpty {
                        Text(downloadsManager.totalSizeText)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.60))
                    }
                }
                if let error = downloadsManager.lastError {
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.orange)
                }
                if downloadsManager.hasLoaded && downloadsManager.downloads.isEmpty {
                    Text(L("No downloaded IPAs. Ones you install from the Install tab are cached here."))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.57))
                } else {
                    ForEach(downloadsManager.downloads) { item in
                        HStack(spacing: 8) {
                            downloadRow(item)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(role: .destructive) { pendingDelete = item } label: {
                                Image(systemName: "trash")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.65))
                                    .frame(width: 34, height: 34)
                                    .background(.white.opacity(0.07), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Delete download")
                        }
                        if item.id != downloadsManager.downloads.last?.id {
                            Rectangle().fill(.white.opacity(0.09)).frame(height: 1)
                        }
                    }
                }
            }
        }
    }

    private var anisetteCard: some View {
        FrozenWorkspacePanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                settingsCardHeading("Anisette server", subtitle: "The selected endpoint is used by the current authentication workflow.", symbol: "network")
                Picker(L("Server"), selection: anisetteSelection) {
                    ForEach(engine.anisetteServers) { server in
                        Text(server.name).tag(Optional(server.address))
                    }
                    Divider()
                    Text(L("Custom…")).tag(String?.none)
                }
                .pickerStyle(.menu)
                .tint(.white)
                .padding(.horizontal, 12)
                .padding(.vertical, 7)
                .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))

                if anisetteIsCustom {
                    TextField(L("Server URL"), text: $engine.anisetteURL)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.URL)
                        .font(.system(size: 12, weight: .medium))
                        .padding(12)
                        .background(.white.opacity(0.065), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                } else {
                    Text(engine.anisetteURL)
                        .font(.system(size: 10, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.54))
                        .lineLimit(2)
                        .textSelection(.enabled)
                }
            }
        }
    }

    private var advancedCard: some View {
        FrozenWorkspacePanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                settingsCardHeading("Advanced networking", subtitle: "Device IP used by the existing pairing and tunnel workflow.", symbol: "point.3.connected.trianglepath.dotted")
                HStack(spacing: 12) {
                    Text(L("Device IP")).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                    Spacer()
                    TextField("10.7.0.1", text: $engine.deviceIP)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                        .multilineTextAlignment(.trailing)
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.76))
                        .frame(maxWidth: 180)
                }
                .padding(12)
                .background(.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
        }
    }

    private var activityCard: some View {
        FrozenWorkspacePanel(cornerRadius: 22) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    settingsCardHeading("Activity log", subtitle: "Recent output from the existing engine.", symbol: "text.alignleft")
                    Spacer()
                    Text("\\(engine.lines.count)")
                        .font(.system(size: 10, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.53))
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 3) {
                            ForEach(engine.lines) { line in
                                Text("\\(line.stamp)  \\(line.text)")
                                    .font(.system(size: 10, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.70))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .id(line.id)
                            }
                        }
                        .padding(.vertical, 5)
                    }
                    .frame(height: 230)
                    .onChange(of: engine.lines.count) { _, _ in
                        if let last = engine.lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                }
                HStack(spacing: 9) {
                    Button { UIPasteboard.general.string = engine.logText() } label: {
                        Label(L("Copy"), systemImage: "doc.on.doc")
                    }
                    .buttonStyle(.plain)
                    Spacer()
                    Button(role: .destructive) { engine.clearLog() } label: {
                        Label(L("Clear"), systemImage: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.78))
            }
        }
    }

    private func settingsCardHeading(_ title: String, subtitle: String, symbol: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: symbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white.opacity(0.86))
                .frame(width: 34, height: 34)
                .background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 11, style: .continuous))
            VStack(alignment: .leading, spacing: 3) {
                Text(title).font(.system(size: 13, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.52)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }'''
)

print("Applied FrozenApps settings workspace redesign.")
