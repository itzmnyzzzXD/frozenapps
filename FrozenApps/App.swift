import SwiftUI

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
    @State private var selectedTab = 0

    var body: some View {
        ZStack {
            Color(red: 0.035, green: 0.04, blue: 0.06).ignoresSafeArea()
            VStack(spacing: 0) {
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 13)
                            .fill(Color.white.opacity(0.08))
                            .frame(width: 44, height: 44)
                        Image(systemName: "snowflake")
                            .font(.system(size: 21, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("FrozenApps").font(.system(size: 21, weight: .bold))
                        Text("YOUR APP WORKSPACE").font(.system(size: 10, weight: .semibold)).tracking(1.7).foregroundStyle(.white.opacity(0.42))
                    }
                    Spacer()
                    Circle().fill(Color.green.opacity(0.9)).frame(width: 7, height: 7)
                    Text("Ready").font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.65))
                }
                .padding(.horizontal, 22).padding(.top, 16).padding(.bottom, 28)

                Group {
                    switch selectedTab {
                    case 0: emptyPage(title: "Signer", subtitle: "Your signing tools will live here.", symbol: "signature")
                    case 1: emptyPage(title: "Settings", subtitle: "Customize your experience here.", symbol: "slider.horizontal.3")
                    default: emptyPage(title: "Files", subtitle: "Your files will appear here.", symbol: "folder")
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)

                HStack(spacing: 5) {
                    tabButton(title: "Signer", icon: "signature", index: 0)
                    tabButton(title: "Settings", icon: "slider.horizontal.3", index: 1)
                    tabButton(title: "Files", icon: "folder", index: 2)
                }
                .padding(7)
                .background(Color.white.opacity(0.055), in: RoundedRectangle(cornerRadius: 22))
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(Color.white.opacity(0.07), lineWidth: 1))
                .padding(.horizontal, 20).padding(.bottom, 12)
            }
        }
    }

    private func emptyPage(title: String, subtitle: String, symbol: String) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            VStack(alignment: .leading, spacing: 8) {
                Text(title).font(.system(size: 32, weight: .bold, design: .rounded))
                Text(subtitle).font(.system(size: 15)).foregroundStyle(.white.opacity(0.48))
            }
            RoundedRectangle(cornerRadius: 24)
                .fill(Color.white.opacity(0.035))
                .overlay(RoundedRectangle(cornerRadius: 24).stroke(Color.white.opacity(0.075), lineWidth: 1))
                .overlay {
                    VStack(spacing: 14) {
                        Image(systemName: symbol)
                            .font(.system(size: 26, weight: .regular))
                            .foregroundStyle(.white.opacity(0.65))
                            .frame(width: 62, height: 62)
                            .background(Color.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 19))
                        Text("Nothing here yet")
                            .font(.system(size: 17, weight: .semibold))
                        Text("This space is ready for what comes next.")
                            .font(.system(size: 13))
                            .foregroundStyle(.white.opacity(0.42))
                            .multilineTextAlignment(.center)
                    }
                    .padding(24)
                }
                .frame(height: 230)
        }
        .padding(.horizontal, 22)
    }

    private func tabButton(title: String, icon: String, index: Int) -> some View {
        Button { withAnimation(.easeInOut(duration: 0.18)) { selectedTab = index } } label: {
            VStack(spacing: 6) {
                Image(systemName: icon).font(.system(size: 18, weight: .medium))
                Text(title).font(.system(size: 11, weight: .semibold))
            }
            .foregroundStyle(selectedTab == index ? .white : .white.opacity(0.42))
            .frame(maxWidth: .infinity).padding(.vertical, 12)
            .background {
                if selectedTab == index {
                    RoundedRectangle(cornerRadius: 16).fill(Color.white.opacity(0.095))
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}