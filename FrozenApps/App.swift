import SwiftUI
import UserNotifications

@main
struct FrozenAppsApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}

struct ContentView: View {
    @AppStorage("pairingNotificationsEnabled") private var pairingNotificationsEnabled = false
    @State private var selectedTab = 0
    @State private var showPairingGuide = false
    @State private var showInbox = false
    @State private var inboxItems: [InboxItem] = [
        InboxItem(title: "Pairing assistant ready", detail: "Follow the guide to pair your device using Apple's supported tools.", date: "Just now")
    ]
    @State private var notice = ""

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 0) {
                header
                Group {
                    switch selectedTab {
                    case 0: signerPage
                    case 1: settingsPage
                    default: filesPage
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                tabBar
            }
        }
        .sheet(isPresented: $showPairingGuide) { pairingGuide }
        .sheet(isPresented: $showInbox) { inboxSheet }
        .alert("FrozenApps", isPresented: Binding(
            get: { !notice.isEmpty },
            set: { if !$0 { notice = "" } }
        )) { Button("OK", role: .cancel) { notice = "" } } message: { Text(notice) }
    }

    private var header: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13).fill(Color.white.opacity(0.08)).frame(width: 44, height: 44)
                Image(systemName: "snowflake").font(.system(size: 21, weight: .semibold)).foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 3) {
                Text("FrozenApps").font(.system(size: 21, weight: .bold))
                Text("YOUR APP WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(.white.opacity(0.42))
            }
            Spacer()
            Button { showInbox = true } label: {
                ZStack(alignment: .topTrailing) {
                    Image(systemName: "bell").font(.system(size: 17, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))
                        .frame(width: 42, height: 42)
                        .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
                    Circle().fill(Color.cyan).frame(width: 7, height: 7).offset(x: -8, y: 8)
                }
            }.buttonStyle(.plain).accessibilityLabel("Notifications")
        }
        .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 26)
    }

    private var signerPage: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Signer").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Prepare your device for signing workflows.").font(.system(size: 15)).foregroundStyle(.white.opacity(0.48))
                }
                VStack(alignment: .leading, spacing: 16) {
                    HStack(spacing: 13) {
                        iconTile("iphone.gen3", tint: .cyan)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Apple device pairing").font(.system(size: 17, weight: .semibold))
                            Text("Not connected").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Circle().fill(Color.orange).frame(width: 8, height: 8)
                    }
                    Text("Pairing and app signing require a compatible Mac tool and valid Apple signing credentials. FrozenApps cannot pair your iPad directly from this screen.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.55)).fixedSize(horizontal: false, vertical: true)
                    Button { showPairingGuide = true } label: {
                        HStack {
                            Text("Open setup guide")
                            Spacer()
                            Image(systemName: "arrow.up.right")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color.black)
                        .padding(.horizontal, 16).padding(.vertical, 14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 15))
                    }.buttonStyle(.plain)
                }
                .padding(18)
                .background(Color.white.opacity(0.045), in: RoundedRectangle(cornerRadius: 23))
                .overlay(RoundedRectangle(cornerRadius: 23).stroke(Color.white.opacity(0.08), lineWidth: 1))

                VStack(alignment: .leading, spacing: 14) {
                    sectionLabel("PAIRING CHECKLIST")
                    checklistRow("Connect your iPhone or iPad to a Mac", detail: "Use Xcode or Apple Configurator.")
                    checklistRow("Trust the computer", detail: "Approve the prompt on your device if it appears.")
                    checklistRow("Enable Developer Mode if needed", detail: "Settings → Privacy & Security → Developer Mode.")
                }
                .padding(18)
                .background(Color.white.opacity(0.025), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.06), lineWidth: 1))
            }
            .padding(.horizontal, 22).padding(.bottom, 20)
        }
    }

    private var settingsPage: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Settings").font(.system(size: 32, weight: .bold, design: .rounded))
                    Text("Manage app preferences on this device.").font(.system(size: 15)).foregroundStyle(.white.opacity(0.48))
                }
                VStack(spacing: 0) {
                    Toggle(isOn: Binding(
                        get: { pairingNotificationsEnabled },
                        set: { enabled in
                            if enabled { enableNotifications() }
                            else { pairingNotificationsEnabled = false }
                        }
                    )) {
                        VStack(alignment: .leading, spacing: 5) {
                            Text("Pairing notifications").font(.system(size: 15, weight: .semibold))
                            Text("Allow FrozenApps to show local alerts.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .tint(.cyan)
                    .padding(17)
                    Divider().overlay(Color.white.opacity(0.06))
                    Button { sendTestNotification() } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 5) {
                                Text("Send test notification").font(.system(size: 15, weight: .semibold))
                                Text("Check that alerts are working.").font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
                            }
                            Spacer()
                            Image(systemName: "bell.badge").foregroundStyle(.white.opacity(0.6))
                        }.padding(17).contentShape(Rectangle())
                    }.buttonStyle(.plain)
                }
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 20))
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(Color.white.opacity(0.07), lineWidth: 1))

                VStack(alignment: .leading, spacing: 8) {
                    sectionLabel("PRIVACY")
                    Text("FrozenApps does not request or store your Apple Account password or verification codes. Preferences are stored locally on this device.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.48)).fixedSize(horizontal: false, vertical: true)
                }.padding(.horizontal, 3)
            }.padding(.horizontal, 22)
        }.scrollIndicators(.hidden)
    }

    private var filesPage: some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Files").font(.system(size: 32, weight: .bold, design: .rounded))
                Text("Your files will appear here.").font(.system(size: 15)).foregroundStyle(.white.opacity(0.48))
            }
            VStack(spacing: 14) {
                Image(systemName: "folder").font(.system(size: 26)).foregroundStyle(.white.opacity(0.65))
                    .frame(width: 62, height: 62).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 19))
                Text("Nothing here yet").font(.system(size: 17, weight: .semibold))
                Text("Imported files will show up here when file support is added.")
                    .font(.system(size: 13)).foregroundStyle(.white.opacity(0.42)).multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity).padding(24).frame(height: 230)
            .background(Color.white.opacity(0.035), in: RoundedRectangle(cornerRadius: 24))
            .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.075), lineWidth: 1))
            Spacer()
        }.padding(.horizontal, 22)
    }

    private var tabBar: some View {
        HStack(spacing: 5) {
            tabButton(title: "Signer", icon: "signature", index: 0)
            tabButton(title: "Settings", icon: "slider.horizontal.3", index: 1)
            tabButton(title: "Files", icon: "folder", index: 2)
        }
        .padding(7).background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
        .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.07), lineWidth: 1))
        .padding(.horizontal, 20).padding(.top, 12).padding(.bottom, 12)
    }

    private var pairingGuide: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack(spacing: 12) {
                        iconTile("macbook.and.iphone", tint: .cyan)
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Pair with a Mac").font(.system(size: 20, weight: .bold))
                            Text("Apple-supported setup").font(.system(size: 13)).foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    guideStep("01", title: "Connect your device", detail: "Connect your iPhone or iPad to a Mac with a compatible cable and unlock the device.")
                    guideStep("02", title: "Trust the computer", detail: "If prompted on the device, tap Trust and enter the device passcode.")
                    guideStep("03", title: "Open Xcode", detail: "On the Mac, open Window → Devices and Simulators, select the device, and follow any pairing prompts.")
                    guideStep("04", title: "Enable Developer Mode if requested", detail: "On the device, open Settings → Privacy & Security → Developer Mode. Turn it on, restart if prompted, then confirm Enable and enter the device passcode.")
                    Text("Verification codes and sign-in approvals must be completed only in Apple's own trusted sign-in flow. FrozenApps cannot detect or retrieve Apple's private pairing prompts automatically.")
                        .font(.system(size: 13)).foregroundStyle(.white.opacity(0.52)).fixedSize(horizontal: false, vertical: true)
                        .padding(14).background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 15))
                }.padding(20)
            }
            .background(Color(red: 0.035, green: 0.04, blue: 0.06))
            .navigationTitle("Pairing guide")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showPairingGuide = false } } }
        }
        .preferredColorScheme(.dark)
    }

    private var inboxSheet: some View {
        NavigationStack {
            List {
                ForEach(inboxItems) { item in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "bell.badge").foregroundStyle(.cyan)
                            .frame(width: 38, height: 38).background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
                        VStack(alignment: .leading, spacing: 5) {
                            Text(item.title).font(.system(size: 15, weight: .semibold))
                            Text(item.detail).font(.system(size: 13)).foregroundStyle(.secondary)
                            Text(item.date).font(.system(size: 11)).foregroundStyle(.tertiary)
                        }
                    }.padding(.vertical, 5).listRowBackground(Color.white.opacity(0.035))
                }
            }
            .scrollContentBackground(.hidden)
            .background(Color(red: 0.035, green: 0.04, blue: 0.06))
            .navigationTitle("Notifications")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { showInbox = false } } }
        }.preferredColorScheme(.dark)
    }

    private func enableNotifications() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            DispatchQueue.main.async {
                pairingNotificationsEnabled = granted
                if !granted { notice = "Notifications were not enabled. You can allow them in iPad Settings." }
                else { notice = "Notifications enabled. FrozenApps can send its own alerts, but it cannot read Apple's private pairing or verification prompts." }
            }
        }
    }

    private func sendTestNotification() {
        guard pairingNotificationsEnabled else {
            notice = "Turn on Pairing notifications first."
            return
        }
        let content = UNMutableNotificationContent()
        content.title = "FrozenApps"
        content.body = "Test notification — local alerts are working."
        content.sound = .default
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false))
        UNUserNotificationCenter.current().add(request) { error in
            DispatchQueue.main.async {
                if let error { notice = "Could not schedule notification: \(error.localizedDescription)" }
                else {
                    inboxItems.insert(InboxItem(title: "Test notification scheduled", detail: "A local test alert should arrive shortly.", date: "Just now"), at: 0)
                    notice = "Test notification scheduled."
                }
            }
        }
    }

    private func iconTile(_ symbol: String, tint: Color) -> some View {
        Image(systemName: symbol).font(.system(size: 20, weight: .medium)).foregroundStyle(tint)
            .frame(width: 48, height: 48).background(tint.opacity(0.12), in: RoundedRectangle(cornerRadius: 15))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title).font(.system(size: 10, weight: .bold)).tracking(1.6).foregroundStyle(.white.opacity(0.4))
    }

    private func checklistRow(_ title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 11) {
            Image(systemName: "circle").font(.system(size: 17)).foregroundStyle(.white.opacity(0.4)).padding(.top, 1)
            VStack(alignment: .leading, spacing: 4) {
                Text(title).font(.system(size: 14, weight: .medium))
                Text(detail).font(.system(size: 12)).foregroundStyle(.white.opacity(0.45))
            }
        }
    }

    private func guideStep(_ number: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 13) {
            Text(number).font(.system(size: 12, weight: .bold, design: .monospaced)).foregroundStyle(.cyan)
                .frame(width: 36, height: 36).background(Color.cyan.opacity(0.12), in: RoundedRectangle(cornerRadius: 11))
            VStack(alignment: .leading, spacing: 6) {
                Text(title).font(.system(size: 15, weight: .semibold))
                Text(detail).font(.system(size: 13)).foregroundStyle(.white.opacity(0.52)).fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { selectedTab = index } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.42))
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background { if selectedTab == index { RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.095)) } }
            .contentShape(Rectangle())
        }.buttonStyle(.plain)
    }
}

private struct InboxItem: Identifiable {
    let id = UUID()
    let title: String
    let detail: String
    let date: String
}
