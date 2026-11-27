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

/// A shape-based black lens with restrained specular rails and no system materials.
private struct FrozenLiquidDockLens: View {
    var body: some View {
        Capsule(style: .continuous)
            .fill(Color.black.opacity(0.72))
            .overlay {
                Capsule(style: .continuous)
                    .fill(LinearGradient(
                        stops: [
                            .init(color: .white.opacity(0.12), location: 0),
                            .init(color: .white.opacity(0.03), location: 0.22),
                            .init(color: .black.opacity(0.72), location: 0.72),
                            .init(color: .white.opacity(0.06), location: 1)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
            }
            .overlay {
                Capsule(style: .continuous)
                    .strokeBorder(
                        LinearGradient(
                            colors: [.white.opacity(0.24), .white.opacity(0.06), .white.opacity(0.12)],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        ), lineWidth: 1
                    )
            }
            .overlay(alignment: .top) {
                Capsule().fill(.white.opacity(0.24))
                    .frame(height: 1).padding(.horizontal, 28).padding(.top, 1)
                    .allowsHitTesting(false)
            }
            .overlay(alignment: .bottom) {
                Capsule().fill(.white.opacity(0.06))
                    .frame(height: 1).padding(.horizontal, 42).padding(.bottom, 1)
                    .allowsHitTesting(false)
            }
            .shadow(color: .black.opacity(0.72), radius: 18, x: 0, y: 9)
            .shadow(color: .white.opacity(0.06), radius: 1, x: 0, y: -1)
            .accessibilityHidden(true)
    }
}

/// One floating six-destination capsule shared by iPhone and iPad.
struct FrozenWorkspaceDock: View {
    let selectedID: String
    let onSelect: (String) -> Void
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Namespace private var selectionNamespace

    var body: some View {
        HStack(spacing: 3) {
            ForEach(FrozenWorkspaceDestinations.all) { destination in dockButton(destination) }
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background { FrozenLiquidDockLens() }
        .animation(reduceMotion ? nil : .spring(response: 0.34, dampingFraction: 0.82), value: selectedID)
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Workspace navigation")
    }

    private func dockButton(_ destination: FrozenWorkspaceDestination) -> some View {
        let selected = selectedID == destination.id
        return Button { onSelect(destination.id) } label: {
            HStack(spacing: 7) {
                Image(systemName: destination.symbol)
                    .font(.system(size: 16, weight: selected ? .semibold : .medium))
                    .symbolRenderingMode(.monochrome)
                    .frame(width: 22, height: 22)
                if selected {
                    Text(destination.compactTitle)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .lineLimit(1).minimumScaleFactor(0.75)
                        .transition(.opacity.combined(with: .scale(scale: 0.88)))
                }
            }
            .foregroundStyle(selected ? Color.white : Color.white.opacity(0.72))
            .frame(maxWidth: .infinity).frame(minWidth: 44, minHeight: 46)
            .padding(.horizontal, selected ? 9 : 3)
            .background {
                if selected {
                    Capsule(style: .continuous)
                        .fill(Color.white.opacity(0.12))
                        .matchedGeometryEffect(id: "frozen-workspace-selection", in: selectionNamespace)
                        .overlay {
                            Capsule(style: .continuous).strokeBorder(.white.opacity(0.24), lineWidth: 1)
                        }
                        .overlay(alignment: .top) {
                            Capsule().fill(.white.opacity(0.24))
                                .frame(height: 1).padding(.horizontal, 12).padding(.top, 1)
                        }
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
            .animation(reduceMotion ? nil : .spring(response: 0.24, dampingFraction: 0.78),
                       value: configuration.isPressed)
    }
}


// Shared workspace primitives used by Signer, App Catalog, IPA Library and Settings.
struct FrozenWorkspacePressStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.975 : 1)
            .brightness(configuration.isPressed ? -0.025 : 0)
            .animation(reduceMotion ? nil : .spring(response: 0.22, dampingFraction: 0.78),
                       value: configuration.isPressed)
    }
}

struct FrozenWorkspacePageHeader: View {
    let eyebrow: String
    let title: String
    let description: String
    let symbol: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            VStack(alignment: .leading, spacing: 7) {
                Text(eyebrow.uppercased())
                    .font(.system(size: 9, weight: .heavy, design: .rounded))
                    .tracking(1.45).foregroundStyle(.white.opacity(0.48))
                Text(title)
                    .font(.system(size: 27, weight: .bold, design: .rounded))
                    .tracking(-0.7).foregroundStyle(.white)
                Text(description)
                    .font(.system(size: 12, weight: .medium))
                    .lineSpacing(3).foregroundStyle(.white.opacity(0.72))
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 4)
            Image(systemName: symbol)
                .font(.system(size: 19, weight: .semibold)).foregroundStyle(.white)
                .frame(width: 48, height: 48)
                .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                }
        }
        .padding(.horizontal, 2).padding(.vertical, 5)
        .accessibilityElement(children: .combine)
    }
}

struct FrozenWorkspaceSearchField: View {
    let placeholder: String
    @Binding var text: String
    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 14, weight: .semibold)).foregroundStyle(.white.opacity(0.48))
            TextField(placeholder, text: $text)
                .font(.system(size: 13, weight: .medium)).foregroundStyle(.white).tint(.white)
                .focused($isFocused).autocorrectionDisabled()
                .textInputAutocapitalization(.never).submitLabel(.search)
            if !text.isEmpty {
                Button { text = ""; isFocused = true } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14)).foregroundStyle(.white.opacity(0.48))
                }
                .buttonStyle(.plain).accessibilityLabel("Clear search")
            }
        }
        .padding(.horizontal, 14).frame(minHeight: 48)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 15, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 15, style: .continuous)
                .strokeBorder(.white.opacity(isFocused ? 0.24 : 0.12), lineWidth: 1)
        }
        .animation(.easeOut(duration: 0.16), value: isFocused)
    }
}

struct FrozenWorkspaceFilterChoice: View {
    let title: String
    let subtitle: String
    let selected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title).font(.system(size: 12, weight: .semibold, design: .rounded)).foregroundStyle(.white)
                    Text(subtitle).font(.system(size: 10, weight: .medium)).foregroundStyle(.white.opacity(0.48))
                }
                Spacer(minLength: 4)
                Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16, weight: .medium))
                    .foregroundStyle(.white.opacity(selected ? 1.0 : 0.24))
            }
            .padding(.horizontal, 11).padding(.vertical, 10)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background {
                if selected {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.06))
                        .overlay {
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(.white.opacity(0.12), lineWidth: 1)
                        }
                }
            }
        }
        .buttonStyle(FrozenWorkspacePressStyle())
        .accessibilityAddTraits(selected ? .isSelected : [])
    }
}
