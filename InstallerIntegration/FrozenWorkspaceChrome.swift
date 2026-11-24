// From Uiverse.io by 3bdel3ziz-T - https://uiverse.io/3bdel3ziz-T/curly-duck-62
// MIT License, Copyright (c) 3bdel3ziz-T (3bdel3zizT)
import SwiftUI

private struct FrozenWorkspaceDestination: Identifiable {
    let id: String
    let title: String
    let compactTitle: String
    let symbol: String
}

private enum FrozenWorkspaceDestinations {
    static let all: [FrozenWorkspaceDestination] = [
        .init(id: "signer", title: "Signer", compactTitle: "Signer", symbol: "signature"),
        .init(id: "center", title: "Frozen Center", compactTitle: "Center", symbol: "square.grid.2x2"),
        .init(id: "network", title: "Network", compactTitle: "Network", symbol: "point.3.connected.trianglepath.dotted"),
        .init(id: "tools", title: "Tools", compactTitle: "Tools", symbol: "wrench.and.screwdriver"),
        .init(id: "files", title: "Files", compactTitle: "Files", symbol: "folder"),
        .init(id: "settings", title: "Settings", compactTitle: "Settings", symbol: "slider.horizontal.3")
    ]
}

/// Six destination controls styled as one native radio group.
/// The six existing destinations are retained; no navigation case is removed.
struct FrozenWorkspaceRail: View {
    let selectedID: String
    let compact: Bool
    let onSelect: (String) -> Void

    @Namespace private var selectionNamespace

    var body: some View {
        Group {
            if compact {
                HStack(spacing: 3) {
                    ForEach(FrozenWorkspaceDestinations.all) { destination in
                        railButton(destination)
                    }
                }
                .padding(Theme.Space.x2)
                .frame(maxWidth: .infinity)
                .background {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .fill(Color.clear)
                        .frozenLiquidMetal(variant: .gunmetal, cornerRadius: 25, live: false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 25, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
            } else {
                VStack(spacing: 9) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(.white.opacity(0.10))
                        Image(systemName: "snowflake")
                            .font(.system(size: 19, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .frame(width: 44, height: 44)
                    .overlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .strokeBorder(.white.opacity(0.32), lineWidth: 1)
                    }
                    .accessibilityHidden(true)

                    Rectangle()
                        .fill(.white.opacity(0.20))
                        .frame(width: 24, height: 1)
                        .padding(.vertical, 3)
                        .accessibilityHidden(true)

                    ForEach(FrozenWorkspaceDestinations.all) { destination in
                        railButton(destination)
                    }

                    Spacer(minLength: 4)

                    Text(Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.2.1")
                        .font(.caption2.weight(.semibold).monospacedDigit())
                        .foregroundStyle(.white.opacity(0.48))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .accessibilityLabel("Version")
                }
                .padding(9)
                .frame(width: 68)
                .background {
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .fill(Color.clear)
                        .frozenLiquidMetal(variant: .gunmetal, cornerRadius: 29, live: false)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 29, style: .continuous)
                        .strokeBorder(.white.opacity(0.25), lineWidth: 1)
                }
            }
        }
        .animation(Theme.Motion.smooth, value: selectedID)
        .sensoryFeedback(.selection, trigger: selectedID)
    }

    private func railButton(_ destination: FrozenWorkspaceDestination) -> some View {
        let isSelected = selectedID == destination.id

        return Button {
            onSelect(destination.id)
        } label: {
            VStack(spacing: compact ? 3 : 0) {
                Image(systemName: destination.symbol)
                    .font(.system(size: compact ? 18 : 19, weight: isSelected ? .semibold : .regular))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 44, height: compact ? 23 : 28)

                if compact {
                    Text(destination.compactTitle)
                        .font(.caption2.weight(isSelected ? .bold : .medium))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .frame(maxWidth: .infinity)
                }
            }
            .foregroundStyle(isSelected ? Theme.accent2 : Color.white.opacity(0.66))
            .frame(maxWidth: compact ? .infinity : nil)
            .frame(minWidth: 44, minHeight: 48)
            .padding(.horizontal, compact ? 1 : 0)
            .background {
                if isSelected {
                    RoundedRectangle(cornerRadius: compact ? 15 : 14, style: .continuous)
                        .fill(Color.clear)
                        .matchedGeometryEffect(id: "selected-workspace-radio", in: selectionNamespace)
                        .frozenLiquidMetal(variant: .chrome, cornerRadius: compact ? 15 : 14, live: true)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(FrozenWorkspaceRadioPressStyle())
        .accessibilityLabel(destination.title)
        .accessibilityValue(isSelected ? "Selected" : "Not selected")
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct FrozenWorkspaceRadioPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.94 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : Theme.Motion.snappy, value: configuration.isPressed)
    }
}

struct FrozenWorkspaceCommandBar: View {
    let title: String
    let symbol: String
    let selectedID: String
    let onSelect: (String) -> Void

    var body: some View {
        HStack(spacing: Theme.Space.x3) {
            ZStack {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .fill(.white.opacity(0.12))
                Image(systemName: "snowflake")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 42, height: 42)
            .overlay {
                RoundedRectangle(cornerRadius: 13, style: .continuous)
                    .strokeBorder(.white.opacity(0.32), lineWidth: 1)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                Text("SIDESTICK")
                    .font(.caption2.weight(.heavy))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.68))
                Text(title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .lineLimit(1)
            }

            Spacer(minLength: Theme.Space.x2)

            Menu {
                Section("Workspace") {
                    ForEach(FrozenWorkspaceDestinations.all) { destination in
                        Button {
                            onSelect(destination.id)
                        } label: {
                            if selectedID == destination.id {
                                Label(destination.title, systemImage: destination.symbol)
                            } else {
                                Label(destination.title, systemImage: destination.symbol)
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: Theme.Space.x2) {
                    Image(systemName: symbol)
                        .font(.system(size: 13, weight: .semibold))
                        .frame(width: 27, height: 27)
                        .background(.white.opacity(0.11), in: RoundedRectangle(cornerRadius: 9, style: .continuous))
                    Text("Workspace")
                        .font(.subheadline.weight(.semibold))
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .foregroundStyle(.white.opacity(0.70))
                }
                .foregroundStyle(.white)
                .padding(.horizontal, Theme.Space.x3)
                .frame(minHeight: 44)
                .contentShape(Capsule())
            }
            .menuStyle(.borderlessButton)
            .accessibilityLabel("Switch workspace")
        }
        .padding(.horizontal, Theme.Space.x4)
        .padding(.vertical, Theme.Space.x2)
        .background {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .fill(Color.clear)
                .frozenLiquidMetal(variant: .gunmetal, cornerRadius: 21, live: true)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 21, style: .continuous)
                .strokeBorder(.white.opacity(0.30), lineWidth: 1)
        }
    }
}

struct FrozenWorkspacePageHeader: View {
    let eyebrow: String
    let title: String
    let description: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: Theme.Space.x3) {
            ZStack {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(.white.opacity(0.10))
                Image(systemName: symbol)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 48, height: 48)
            .overlay {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(.white.opacity(0.30), lineWidth: 1)
            }
            .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: Theme.Space.x1) {
                Text(eyebrow.uppercased())
                    .font(.caption2.weight(.heavy))
                    .tracking(1.3)
                    .foregroundStyle(.white.opacity(0.62))
                Text(title)
                    .font(.title3.weight(.bold))
                    .tracking(-0.35)
                    .foregroundStyle(.white)
                Text(description)
                    .font(.callout)
                    .lineSpacing(2)
                    .foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(Theme.Space.x4)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color.clear)
                .frozenLiquidMetal(variant: .gunmetal, cornerRadius: 24, live: false)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .strokeBorder(.white.opacity(0.26), lineWidth: 1)
        }
    }
}

struct FrozenWorkspaceSearchField: View {
    let placeholder: String
    @Binding var text: String

    var body: some View {
        HStack(spacing: Theme.Space.x2) {
            Image(systemName: "magnifyingglass")
                .font(.body.weight(.medium))
                .foregroundStyle(.white.opacity(0.70))
            TextField(placeholder, text: $text)
                .font(.body)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .accessibilityLabel(placeholder)
        }
        .padding(.horizontal, Theme.Space.x4)
        .frame(minHeight: 48)
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
            HStack(spacing: Theme.Space.x3) {
                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .font(.body.weight(.medium))
                    .foregroundStyle(selected ? Theme.accent2 : Color.white.opacity(0.48))

                VStack(alignment: .leading, spacing: Theme.Space.x1) {
                    Text(title)
                        .font(.subheadline.weight(selected ? .semibold : .medium))
                        .foregroundStyle(.white)
                    if let subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }

                Spacer(minLength: Theme.Space.x1)

                if selected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
            .padding(.horizontal, Theme.Space.x3)
            .frame(minHeight: 48)
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                        .fill(Theme.accent.opacity(0.16))
                        .overlay {
                            RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous)
                                .strokeBorder(.white.opacity(0.24), lineWidth: 1)
                        }
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: Theme.Radius.small, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

struct FrozenWorkspacePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.98 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : Theme.Motion.snappy, value: configuration.isPressed)
    }
}

private struct FrozenWorkspaceChromePreview: View {
    @State private var selectedID = "signer"

    var body: some View {
        VStack(spacing: 20) {
            FrozenWorkspaceCommandBar(
                title: "Signer",
                symbol: "signature",
                selectedID: selectedID,
                onSelect: { selectedID = $0 }
            )

            HStack(alignment: .top, spacing: 16) {
                FrozenWorkspaceRail(
                    selectedID: selectedID,
                    compact: false,
                    onSelect: { selectedID = $0 }
                )
                FrozenWorkspacePageHeader(
                    eyebrow: "Workspace / Signer",
                    title: "Prepare an install",
                    description: "Pair, provision and install through the existing SideStick engine.",
                    symbol: "signature"
                )
            }

            FrozenWorkspaceRail(
                selectedID: selectedID,
                compact: true,
                onSelect: { selectedID = $0 }
            )
        }
        .padding(20)
        .background(Theme.matteSurface.ignoresSafeArea())
        .preferredColorScheme(.dark)
    }
}

#Preview("SideStick workspace chrome") {
    FrozenWorkspaceChromePreview()
}
