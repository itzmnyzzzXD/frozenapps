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
"wrench.and.screwdriver": "FrozenIcon-tools",
        "app.dashed": "FrozenIcon-app",
        "questionmark.app.dashed": "FrozenIcon-app-question",
        "arrow.clockwise.circle": "FrozenIcon-refresh",
        "arrow.triangle.2.circlepath": "FrozenIcon-refresh",
        "arrow.down.circle.fill": "FrozenIcon-download",
        "arrow.down.doc": "FrozenIcon-download-file",
        "arrow.up.circle.fill": "FrozenIcon-upload",
        "bitcoinsign.circle.fill": "FrozenIcon-coin",
        "bolt.horizontal.circle": "FrozenIcon-bolt",
        "bubble.left.and.bubble.right.fill": "FrozenIcon-chat",
        "calendar": "FrozenIcon-calendar",
        "character.bubble.fill": "FrozenIcon-language",
        "chevron.left.forwardslash.chevron.right": "FrozenIcon-code",
        "chevron.up.chevron.down": "FrozenIcon-chevron-vertical",
        "clock": "FrozenIcon-clock",
        "clock.arrow.circlepath": "FrozenIcon-refresh",
        "cup.and.saucer.fill": "FrozenIcon-coffee",
        "desktopcomputer": "FrozenIcon-desktop",
        "exclamationmark.shield.fill": "FrozenIcon-shield-alert",
        "externaldrive.fill": "FrozenIcon-drive",
        "gamecontroller.fill": "FrozenIcon-gamepad",
        "hammer.fill": "FrozenIcon-hammer",
        "hand.raised.fill": "FrozenIcon-hand",
        "heart.fill": "FrozenIcon-heart",
        "iphone.and.arrow.forward": "FrozenIcon-device-transfer",
        "iphone.gen3": "FrozenIcon-device",
        "iphone.gen3.slash": "FrozenIcon-device-off",
        "ladybug.fill": "FrozenIcon-bug",
        "link": "FrozenIcon-link",
        "list.bullet": "FrozenIcon-list",
        "location.fill": "FrozenIcon-location",
        "location.slash": "FrozenIcon-location-off",
        "lock.doc.fill": "FrozenIcon-lock-file",
        "lock.slash.fill": "FrozenIcon-lock-off",
        "mappin.and.ellipse": "FrozenIcon-map-pin",
        "mappin.circle.fill": "FrozenIcon-map-pin",
        "number": "FrozenIcon-number",
        "person.2.fill": "FrozenIcon-people",
        "person.crop.circle": "FrozenIcon-profile",
        "person.crop.circle.fill": "FrozenIcon-profile",
        "person.crop.circle.fill.badge.checkmark": "FrozenIcon-profile-check",
        "plus.circle.fill": "FrozenIcon-plus",
        "scope": "FrozenIcon-target",
        "seal.fill": "FrozenIcon-seal",
        "shield.lefthalf.filled": "FrozenIcon-shield",
        "shield.slash.fill": "FrozenIcon-shield-off",
        "square.and.arrow.down": "FrozenIcon-download",
        "square.and.arrow.down.fill": "FrozenIcon-download",
        "square.and.arrow.down.on.square": "FrozenIcon-download-file",
        "square.and.arrow.up": "FrozenIcon-upload",
        "square.stack.3d.up.fill": "FrozenIcon-stack",
        "tag.fill": "FrozenIcon-tag",
        "tray.and.arrow.down.fill": "FrozenIcon-download",
        "wifi": "FrozenIcon-wifi",
        "wifi.slash": "FrozenIcon-wifi-off",
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
