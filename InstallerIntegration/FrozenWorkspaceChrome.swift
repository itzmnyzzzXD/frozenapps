import SwiftUI

private struct FrozenWorkspaceDestination: Identifiable {
    let id: String
    let title: String
    let symbol: String
    var compactTitle: String { id == "center" ? "Center" : title }
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

/// One floating capsule shared by iPhone and iPad. No vertical rail or header bar.
struct FrozenWorkspaceDock: View {
    let selectedID: String
    let onSelect: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(FrozenWorkspaceDestinations.all) { destination in
                dockButton(destination)
            }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background {
            Capsule(style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay { Capsule(style: .continuous).fill(Color.black.opacity(0.70)) }
        }
        .overlay {
            Capsule(style: .continuous)
                .strokeBorder(
                    LinearGradient(
                        colors: [.white.opacity(0.28), .white.opacity(0.08), .white.opacity(0.18)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ), lineWidth: 1
                )
        }
        .shadow(color: .black.opacity(0.38), radius: 22, x: 0, y: 10)
        .overlay(alignment: .top) {
            Capsule().fill(.white.opacity(0.22))
                .frame(height: 1).padding(.horizontal, 24).padding(.top, 1)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace navigation")
    }

    private func dockButton(_ destination: FrozenWorkspaceDestination) -> some View {
        let selected = selectedID == destination.id
        return Button { onSelect(destination.id) } label: {
            HStack(spacing: 7) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 16, weight: selected ? .semibold : .medium))
                    .symbolRenderingMode(.hierarchical)
                    .frame(width: 22, height: 22)
                if selected {
                    Text(destination.compactTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                }
            }
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.66))
            .frame(maxWidth: .infinity).frame(minWidth: 44, minHeight: 46)
            .padding(.horizontal, selected ? 9 : 3)
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.13))
                        .matchedGeometryEffect(id: "frozen-workspace-selection", in: selectionNamespace)
                        .overlay {
                            Capsule(style: .continuous).strokeBorder(.white.opacity(0.23), lineWidth: 1)
                        }
                        .shadow(color: .white.opacity(0.06), radius: 9, x: 0, y: 1)
                }
            }
            .contentShape(Capsule())
        }
        .buttonStyle(FrozenWorkspaceDockPressStyle())
        .accessibilityLabel(destination.title)
        .accessibilityValue(selected ? "Selected" : "Not selected")
        .accessibilityAddTraits(selected ? [.isButton, .isSelected] : .isButton)
    }
}

private struct FrozenWorkspaceDockPressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(
                reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78),
                value: configuration.isPressed
            )
    }
}
