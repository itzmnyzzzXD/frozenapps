import SwiftUI

private struct FrozenWorkspaceDestination: Identifiable {
    let id: String
    let title: String
    let symbol: String
}
private enum FrozenWorkspaceDestinations {
    static let all: [FrozenWorkspaceDestination] = [
        .init(id: "signer", title: "Signer", symbol: "signature"),
        .init(id: "center", title: "Frozen Center", symbol: "square.grid.2x2"),
        .init(id: "network", title: "Network", symbol: "point.3.connected.trianglepath.dotted"),
        .init(id: "tools", title: "Tools", symbol: "wrench.and.screwdriver"),
        .init(id: "files", title: "Files", symbol: "folder"),
        .init(id: "settings", title: "Settings", symbol: "slider.horizontal.3")
    ]
}
struct FrozenWorkspaceRail: View {
    let selectedID: String
    let compact: Bool
    let onSelect: (String) -> Void
    var body: some View {
        Group {
            if compact {
                HStack(spacing: 4) {
                    ForEach(FrozenWorkspaceDestinations.all) { destination in railButton(destination) }
                }
                .padding(7).frame(maxWidth: .infinity)
                .frozenGlassSurface(cornerRadius: 25, tint: .white.opacity(0.04), elevated: true)
            } else {
                VStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous).fill(.white.opacity(0.13))
                        Image(systemName: "snowflake").font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                    }
                    .frame(width: 43, height: 43)
                    .overlay { RoundedRectangle(cornerRadius: 15, style: .continuous).strokeBorder(.white.opacity(0.30), lineWidth: 1) }
                    Rectangle().fill(.white.opacity(0.16)).frame(width: 24, height: 1).padding(.vertical, 3)
                    ForEach(FrozenWorkspaceDestinations.all) { destination in railButton(destination) }
                    Spacer(minLength: 4)
                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.0")
                        .font(.system(size: 8, weight: .semibold, design: .rounded).monospacedDigit()).foregroundStyle(.white.opacity(0.35))
                }
                .padding(9).frame(width: 64)
                .frozenGlassSurface(cornerRadius: 30, tint: .white.opacity(0.04), elevated: true)
            }
        }
        .animation(.smooth(duration: 0.22), value: selectedID)
    }
    private func railButton(_ destination: FrozenWorkspaceDestination) -> some View {
        Button { onSelect(destination.id) } label: {
            VStack(spacing: compact ? 4 : 0) {
                Image(systemName: destination.symbol)
                    .font(.system(size: compact ? 16 : 18, weight: selectedID == destination.id ? .semibold : .regular))
                    .frame(width: compact ? nil : 44, height: 28)
                if compact {
                    Text(destination.title == "Frozen Center" ? "Center" : destination.title)
                        .font(.system(size: 8, weight: selectedID == destination.id ? .bold : .medium))
                        .lineLimit(1).minimumScaleFactor(0.72)
                }
            }
            .foregroundStyle(selectedID == destination.id ? Color.white : Color.white.opacity(0.57))
            .frame(maxWidth: compact ? .infinity : nil)
            .frame(width: compact ? nil : 44, height: compact ? 43 : 44)
            .background {
                if selectedID == destination.id {
                    RoundedRectangle(cornerRadius: compact ? 15 : 14, style: .continuous)
                        .fill(LinearGradient(colors: [.white.opacity(0.20), .white.opacity(0.07)], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .overlay { RoundedRectangle(cornerRadius: compact ? 15 : 14, style: .continuous).strokeBorder(.white.opacity(0.27), lineWidth: 1) }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain).accessibilityLabel(destination.title)
    }
}
struct FrozenWorkspaceCommandBar: View {
    let title: String
    let symbol: String
    let selectedID: String
    let onSelect: (String) -> Void
    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous).fill(.white.opacity(0.12))
                Image(systemName: "snowflake").font(.system(size: 17, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 39, height: 39)
            .overlay { RoundedRectangle(cornerRadius: 13, style: .continuous).strokeBorder(.white.opacity(0.23), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 3) {
                Text("FROZENAPPS").font(.system(size: 9, weight: .heavy, design: .rounded)).tracking(1.7).foregroundStyle(.white.opacity(0.56))
                Text(title).font(.system(size: 16, weight: .semibold, design: .rounded)).foregroundStyle(.white).lineLimit(1)
            }
            Spacer(minLength: 8)
            Menu {
                Section("Workspace") {
                    ForEach(FrozenWorkspaceDestinations.all) { destination in
                        Button { onSelect(destination.id) } label: {
                            if selectedID == destination.id { Label(destination.title, systemImage: destination.symbol) }
                            else { Text(destination.title) }
                        }
                    }
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: symbol).font(.system(size: 13, weight: .semibold))
                        .frame(width: 25, height: 25).background(.white.opacity(0.10), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("Workspace").font(.system(size: 11, weight: .semibold, design: .rounded))
                    Image(systemName: "chevron.down").font(.system(size: 9, weight: .bold)).foregroundStyle(.white.opacity(0.58))
                }
                .foregroundStyle(.white).padding(.horizontal, 10).padding(.vertical, 8)
                .frozenGlassSurface(cornerRadius: 15, tint: .white.opacity(0.04))
            }
            .menuStyle(.borderlessButton).accessibilityLabel("Switch workspace")
        }
        .padding(.horizontal, 14).padding(.vertical, 10)
        .frozenGlassSurface(cornerRadius: 21, tint: .white.opacity(0.025))
    }
}
struct FrozenWorkspacePageHeader: View {
    let eyebrow: String
    let title: String
    let description: String
    let symbol: String
    var body: some View {
        HStack(alignment: .top, spacing: 13) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.12))
                Image(systemName: symbol).font(.system(size: 20, weight: .semibold)).foregroundStyle(.white)
            }
            .frame(width: 47, height: 47)
            .overlay { RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(.white.opacity(0.25), lineWidth: 1) }
            VStack(alignment: .leading, spacing: 5) {
                Text(eyebrow.uppercased()).font(.system(size: 8, weight: .heavy, design: .rounded)).tracking(1.6).foregroundStyle(.white.opacity(0.56))
                Text(title).font(.system(size: 24, weight: .bold, design: .rounded)).tracking(-0.55).foregroundStyle(.white)
                Text(description).font(.system(size: 11, weight: .medium)).lineSpacing(2).foregroundStyle(.white.opacity(0.62)).fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
        .padding(18).frame(maxWidth: .infinity, alignment: .leading)
        .frozenGlassSurface(cornerRadius: 24, tint: .white.opacity(0.045), elevated: true)
    }
}
struct FrozenWorkspaceSearchField: View {
    let placeholder: String
    @Binding var text: String
    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").font(.system(size: 14, weight: .medium)).foregroundStyle(.white.opacity(0.60))
            TextField(placeholder, text: $text).font(.system(size: 13, weight: .medium)).textInputAutocapitalization(.never).autocorrectionDisabled()
        }
        .padding(.horizontal, 14).padding(.vertical, 13)
        .frozenGlassSurface(cornerRadius: 16, tint: .white.opacity(0.025))
    }
}
struct FrozenWorkspaceFilterChoice: View {
    let title: String
    let subtitle: String?
    let selected: Bool
    let action: () -> Void
    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(selected ? Color.white : Color.white.opacity(0.40))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: selected ? .semibold : .medium)).foregroundStyle(.white)
                    if let subtitle { Text(subtitle).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.47)) }
                }
                Spacer(minLength: 4)
                if selected { Image(systemName: "checkmark").font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.85)) }
            }
            .padding(.vertical, 9).padding(.horizontal, 10)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.white.opacity(0.095))
                        .overlay { RoundedRectangle(cornerRadius: 12, style: .continuous).strokeBorder(.white.opacity(0.17), lineWidth: 1) }
                }
            }
        }
        .buttonStyle(.plain)
    }
}
struct FrozenWorkspacePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label.scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.23, dampingFraction: 0.8), value: configuration.isPressed)
    }
}
