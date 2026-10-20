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
    @State private var selectedTab = "Home"
    @State private var isExpanded = true

    let sidebarButtons: [(String, String)] = [
        ("house.fill", "Home"),
        ("magnifyingglass", "Search"),
        ("play.rectangle.fill", "Shorts"),
        ("folder.fill", "Library"),
        ("info.circle.fill", "Info"),
        ("gearshape.fill", "Settings"),
        ("arrowshape.turn.up.right.fill", "Logout")
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.06, green: 0.06, blue: 0.08),
                    Color(red: 0.12, green: 0.07, blue: 0.10),
                    Color(red: 0.25, green: 0.09, blue: 0.12)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            PinkFlowBackground()

            HStack(alignment: .center, spacing: 28) {
                SidebarPanel()
                GlassMenuPanel(selectedTab: $selectedTab, isExpanded: $isExpanded)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 26)
        }
    }
}

private struct SidebarPanel: View {
    var body: some View {
        VStack(spacing: 18) {
            VStack(spacing: 16) {
                HStack(spacing: 8) {
                    Circle().fill(Color.green).frame(width: 12, height: 12)
                    Circle().fill(Color.yellow).frame(width: 12, height: 12)
                    Circle().fill(Color.red).frame(width: 12, height: 12)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 18)

                RoundedRectangle(cornerRadius: 28)
                    .fill(Color.white.opacity(0.08))
                    .frame(width: 120, height: 74)
                    .overlay(
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Performance")
                                .font(.system(size: 12, weight: .medium))
                                .foregroundStyle(.white.opacity(0.8))
                            HStack(alignment: .bottom, spacing: 4) {
                                Text("45")
                                    .font(.system(size: 28, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("%")
                                    .font(.system(size: 14, weight: .medium))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 14)
                    )

                VStack(spacing: 12) {
                    GlassButton(icon: "house.fill", label: "")
                    GlassButton(icon: "magnifyingglass", label: "")
                    GlassButton(icon: "play.rectangle.fill", label: "")
                    GlassButton(icon: "video.fill", label: "")
                    GlassButton(icon: "info.circle.fill", label: "")
                    GlassButton(icon: "gearshape.fill", label: "")
                    GlassButton(icon: "arrow.right", label: "")
                }
            }
            .padding(.vertical, 18)
            .frame(width: 160, height: 610)
            .background(
                RoundedRectangle(cornerRadius: 38)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 38)
                            .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    )
                    .blur(radius: 0.2)
            )
            .shadow(color: .black.opacity(0.25), radius: 26, x: 0, y: 18)
        }
    }
}

private struct GlassMenuPanel: View {
    @Binding var selectedTab: String
    @Binding var isExpanded: Bool

    let menuItems = [
        "Home",
        "Explore",
        "Short",
        "Subscription",
        "Information",
        "Settings",
        "Log out"
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 30)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.10),
                            Color.white.opacity(0.06),
                            Color.white.opacity(0.12)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 30)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1.5)
                )
                .shadow(color: .black.opacity(0.2), radius: 28, x: 0, y: 20)

            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    Text("YouTube")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(.white.opacity(0.92))
                        .padding(.top, 10)

                    Spacer()

                    HStack(spacing: 10) {
                        Circle().fill(Color.green).frame(width: 12, height: 12)
                        Circle().fill(Color.yellow).frame(width: 12, height: 12)
                        Circle().fill(Color.red).frame(width: 12, height: 12)
                    }
                    .padding(.trailing, 8)
                }
                .padding(.horizontal, 18)

                Divider().background(Color.white.opacity(0.2))

                VStack(alignment: .leading, spacing: 0) {
                    Text("MENU")
                        .font(.system(size: 12, weight: .bold))
                        .letterSpacing(1.4)
                        .foregroundStyle(.white.opacity(0.72))
                        .padding(.horizontal, 18)
                        .padding(.top, 6)

                    ForEach(menuItems, id: \ .self) { item in
                        MenuItemRow(title: item, isSelected: selectedTab == item) {
                            selectedTab = item
                        }
                    }
                }

                HStack(spacing: 16) {
                    RoundedRectangle(cornerRadius: 18)
                        .fill(Color.white.opacity(0.08))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "person.crop.circle.fill")
                                .foregroundStyle(.white.opacity(0.95))
                                .font(.system(size: 26))
                        )

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Hesala hertz")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.9))
                        Text("Premium Account")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.white.opacity(0.62))
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .foregroundStyle(.white.opacity(0.7))
                        .font(.system(size: 16, weight: .bold))
                }
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 12)
            }
            .padding(.vertical, 12)
        }
        .frame(width: 560, height: 690)
    }
}

private struct MenuItemRow: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: iconFor(title))
                    .font(.system(size: 20, weight: .medium))
                    .frame(width: 24)
                Text(title)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundStyle(isSelected ? .white : .white.opacity(0.72))
                Spacer()
                if title == "Subscription" {
                    Circle().fill(Color.white.opacity(0.9)).frame(width: 8, height: 8)
                } else if title == "Home" || title == "Explore" || title == "Short" {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(.white.opacity(0.75))
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(isSelected ? Color.white.opacity(0.10) : Color.clear)
            )
        }
        .buttonStyle(.plain)
    }

    private func iconFor(_ item: String) -> String {
        switch item {
        case "Home": return "house.fill"
        case "Explore": return "magnifyingglass"
        case "Short": return "play.rectangle.fill"
        case "Subscription": return "play.square.stack.fill"
        case "Information": return "info.circle.fill"
        case "Settings": return "gearshape.fill"
        case "Log out": return "rectangle.portrait.and.arrow.right"
        default: return "house.fill"
        }
    }
}

private struct GlassButton: View {
    let icon: String
    let label: String

    var body: some View {
        Button(action: {}) {
            VStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .frame(width: 40, height: 40)
                    .foregroundStyle(.white.opacity(0.9))
                    .background(Color.white.opacity(0.08), in: Circle())
                if label.isEmpty == false {
                    Text(label)
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .buttonStyle(.plain)
    }
}

private struct PinkFlowBackground: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                ForEach(0..<7) { index in
                    let x = CGFloat(index) * 110 + 120
                    let y = CGFloat(index % 2 == 0 ? 120 : 400)
                    let width = 720.0 + Double(index * 16)
                    let height = 740.0 - Double(index * 18)

                    RoundedRectangle(cornerRadius: 200)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.96, green: 0.68, blue: 0.76).opacity(0.75),
                                    Color(red: 0.83, green: 0.28, blue: 0.45).opacity(0.45),
                                    Color.clear
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .rotationEffect(.degrees(Double(index * 16)))
                        .frame(width: width, height: height)
                        .position(x: x, y: y)
                        .blur(radius: 10)
                }
            }
        }
        .allowsHitTesting(false)
    }
}
