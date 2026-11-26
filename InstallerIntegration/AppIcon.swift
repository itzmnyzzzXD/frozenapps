import SwiftUI
import UIKit

/// Central monochrome renderer for app-owned interface icons.
struct AppIcon: View {
    let name: String
    var size: CGFloat = 17
    var weight: Font.Weight = .medium

    private static let assets: [String: String] = [
        "app.badge.checkmark": "FrozenIcon-app", "app.fill": "FrozenIcon-app",
        "arrow.clockwise": "FrozenIcon-refresh", "arrow.right": "FrozenIcon-arrow-right",
        "arrow.up.right": "FrozenIcon-arrow-up", "arrow.up.right.square": "FrozenIcon-arrow-up",
        "bell.badge.fill": "FrozenIcon-bell", "bolt.fill": "FrozenIcon-bolt",
        "book.closed.fill": "FrozenIcon-book", "checklist": "FrozenIcon-checklist",
        "checkmark": "FrozenIcon-check", "checkmark.circle.fill": "FrozenIcon-check",
        "checkmark.seal": "FrozenIcon-check", "checkmark.seal.fill": "FrozenIcon-check",
        "checkmark.shield.fill": "FrozenIcon-shield",
        "chevron.down": "FrozenIcon-chevron", "chevron.right": "FrozenIcon-chevron",
        "doc.badge.gearshape": "FrozenIcon-file", "doc.badge.plus": "FrozenIcon-file",
        "doc.on.doc": "FrozenIcon-copy", "doc.zipper": "FrozenIcon-archive",
        "dot.radiowaves.left.and.right": "FrozenIcon-network", "ellipsis": "FrozenIcon-ellipsis",
        "exclamationmark.triangle.fill": "FrozenIcon-alert", "folder.badge.plus": "FrozenIcon-folder",
        "gearshape": "FrozenIcon-settings", "hand.raised": "FrozenIcon-hand",
        "info.circle": "FrozenIcon-info", "info.circle.fill": "FrozenIcon-info",
        "ipad.and.iphone": "FrozenIcon-device", "iphone": "FrozenIcon-device",
        "line.3.horizontal.decrease": "FrozenIcon-filter",
        "line.3.horizontal.decrease.circle": "FrozenIcon-filter",
        "lock.shield": "FrozenIcon-shield", "lock.shield.fill": "FrozenIcon-shield",
        "magnifyingglass": "FrozenIcon-search", "network": "FrozenIcon-network",
        "pencil": "FrozenIcon-pencil", "person.badge.key": "FrozenIcon-key",
        "plus": "FrozenIcon-plus", "point.3.connected.trianglepath.dotted": "FrozenIcon-network",
        "server.rack": "FrozenIcon-server", "shippingbox.fill": "FrozenIcon-package",
        "signature": "FrozenIcon-signature", "slider.horizontal.3": "FrozenIcon-settings",
        "snowflake": "FrozenIcon-snowflake", "sparkles": "FrozenIcon-sparkles",
        "sparkles.rectangle.stack": "FrozenIcon-sparkles", "square.grid.2x2.fill": "FrozenIcon-grid",
        "text.alignleft": "FrozenIcon-text", "trash": "FrozenIcon-trash",
        "waveform.path": "FrozenIcon-activity", "waveform.path.ecg": "FrozenIcon-activity",
        "wrench.and.screwdriver.fill": "FrozenIcon-tools",
        "xmark": "FrozenIcon-close", "xmark.circle.fill": "FrozenIcon-close"
    ]

    var body: some View {
        Group {
            if let assetName = Self.assets[name], UIImage(named: assetName) != nil {
                Image(assetName)
                    .resizable()
                    .renderingMode(.template)
                    .scaledToFit()
                    .foregroundStyle(.white)
            } else {
                Image(systemName: name)
                    .font(.system(size: size, weight: weight))
                    .symbolRenderingMode(.monochrome)
                    .foregroundStyle(.white)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}
