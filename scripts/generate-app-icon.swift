#!/usr/bin/env swift
import AppKit
import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let assets = root.appendingPathComponent("Vendor/SideInstaller/ios-app/Assets.xcassets")
let iconSet = assets.appendingPathComponent("AppIcon.appiconset")
let logoSet = assets.appendingPathComponent("AppLogo.imageset")

func cgColor(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor {
    CGColor(colorSpace: CGColorSpaceCreateDeviceRGB(), components: [r, g, b, a])!
}

func roundedRect(_ context: CGContext, x: CGFloat, y: CGFloat, width: CGFloat,
                 height: CGFloat, radius: CGFloat, color: CGColor) {
    let rect = CGRect(x: x, y: y, width: width, height: height)
    let path = CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil)
    context.addPath(path)
    context.setFillColor(color)
    context.fillPath()
}

func drawSnowflake(_ context: CGContext, center: CGPoint, radius: CGFloat,
                   lineWidth: CGFloat, color: CGColor) {
    context.saveGState()
    context.setStrokeColor(color)
    context.setLineWidth(lineWidth)
    context.setLineCap(.round)
    context.setLineJoin(.round)

    for arm in 0..<6 {
        let angle = CGFloat(arm) * .pi / 3
        let end = CGPoint(x: center.x + cos(angle) * radius,
                          y: center.y + sin(angle) * radius)
        context.move(to: center)
        context.addLine(to: end)

        let branchPoint = CGPoint(x: center.x + cos(angle) * radius * 0.67,
                                  y: center.y + sin(angle) * radius * 0.67)
        let branchLength = radius * 0.25
        for offset in [-1, 1] {
            let branchAngle = angle + CGFloat(offset) * 2.25
            let branchEnd = CGPoint(x: branchPoint.x + cos(branchAngle) * branchLength,
                                    y: branchPoint.y + sin(branchAngle) * branchLength)
            context.move(to: branchPoint)
            context.addLine(to: branchEnd)
        }
    }
    context.strokePath()

    let diamondRadius = radius * 0.18
    let diamond = CGMutablePath()
    diamond.move(to: CGPoint(x: center.x, y: center.y + diamondRadius))
    diamond.addLine(to: CGPoint(x: center.x + diamondRadius, y: center.y))
    diamond.addLine(to: CGPoint(x: center.x, y: center.y - diamondRadius))
    diamond.addLine(to: CGPoint(x: center.x - diamondRadius, y: center.y))
    diamond.closeSubpath()
    context.addPath(diamond)
    context.setFillColor(cgColor(0.95, 1.0, 0.99))
    context.fillPath()
    context.restoreGState()
}

func makeIcon(size: Int, variant: String) -> CGImage {
    let dimension = CGFloat(size)
    let colorSpace = CGColorSpaceCreateDeviceRGB()
    let context = CGContext(data: nil, width: size, height: size,
                            bitsPerComponent: 8, bytesPerRow: 0,
                            space: colorSpace,
                            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let rect = CGRect(x: 0, y: 0, width: dimension, height: dimension)
    context.clear(rect)
    context.setAllowsAntialiasing(true)
    context.setShouldAntialias(true)
    context.interpolationQuality = .high

    let tinted = variant == "tinted"
    if !tinted {
        let dark = variant == "dark"
        let colors: [CGColor] = dark
            ? [cgColor(0.018, 0.012, 0.065), cgColor(0.045, 0.055, 0.18), cgColor(0.018, 0.12, 0.20)]
            : [cgColor(0.02, 0.014, 0.08), cgColor(0.095, 0.055, 0.30), cgColor(0.02, 0.29, 0.43)]
        let gradient = CGGradient(colorsSpace: colorSpace, colors: colors as CFArray,
                                  locations: [0, 0.56, 1])!
        context.drawLinearGradient(gradient,
                                   start: CGPoint(x: dimension * 0.05, y: dimension * 0.02),
                                   end: CGPoint(x: dimension * 0.95, y: dimension * 0.98),
                                   options: [.drawsBeforeStartLocation, .drawsAfterEndLocation])

        let glowColors: [CGColor] = [
            cgColor(0.52, 0.32, 1.0, dark ? 0.15 : 0.24),
            cgColor(0.12, 0.75, 1.0, 0.07),
            cgColor(0.12, 0.75, 1.0, 0.0)
        ]
        let glow = CGGradient(colorsSpace: colorSpace, colors: glowColors as CFArray,
                              locations: [0, 0.45, 1])!
        context.drawRadialGradient(glow,
                                   startCenter: CGPoint(x: dimension * 0.76, y: dimension * 0.70),
                                   startRadius: 0,
                                   endCenter: CGPoint(x: dimension * 0.76, y: dimension * 0.70),
                                   endRadius: dimension * 0.68,
                                   options: [])

        let border = CGPath(roundedRect: rect.insetBy(dx: dimension * 0.045, dy: dimension * 0.045),
                            cornerWidth: dimension * 0.23, cornerHeight: dimension * 0.23, transform: nil)
        context.addPath(border)
        context.setStrokeColor(cgColor(0.86, 0.84, 1.0, 0.16))
        context.setLineWidth(max(1, dimension * 0.0035))
        context.strokePath()
    }

    let white = tinted ? cgColor(1, 1, 1, 1) : cgColor(0.94, 1.0, 0.98, 1)
    let mint = tinted ? cgColor(1, 1, 1, 1) : cgColor(0.24, 0.91, 1.0, 1)

    // A bold F monogram with softened corners: readable at tiny notification-icon sizes.
    roundedRect(context, x: dimension * 0.265, y: dimension * 0.245,
                width: dimension * 0.125, height: dimension * 0.515,
                radius: dimension * 0.055, color: white)
    roundedRect(context, x: dimension * 0.275, y: dimension * 0.635,
                width: dimension * 0.405, height: dimension * 0.125,
                radius: dimension * 0.055, color: white)
    roundedRect(context, x: dimension * 0.275, y: dimension * 0.465,
                width: dimension * 0.295, height: dimension * 0.115,
                radius: dimension * 0.052, color: white)

    drawSnowflake(context,
                  center: CGPoint(x: dimension * 0.685, y: dimension * 0.405),
                  radius: dimension * 0.145,
                  lineWidth: max(1.3, dimension * 0.036),
                  color: mint)

    // A few restrained glints reinforce the ice motif without cluttering the mark.
    if !tinted {
        let glints: [(CGFloat, CGFloat, CGFloat)] = [(0.76, 0.82, 0.012), (0.19, 0.56, 0.009), (0.79, 0.22, 0.008)]
        for (x, y, radius) in glints {
            let dot = CGRect(x: dimension * x - dimension * radius,
                             y: dimension * y - dimension * radius,
                             width: dimension * radius * 2,
                             height: dimension * radius * 2)
            context.setFillColor(cgColor(0.85, 1.0, 0.97, 0.65))
            context.fillEllipse(in: dot)
        }
    }

    return context.makeImage()!
}

func writePNG(_ image: CGImage, to url: URL) throws {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(),
                                            withIntermediateDirectories: true)
    guard let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil) else {
        throw NSError(domain: "FrozenAppsIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: "Could not create PNG destination at \(url.path)"])
    }
    CGImageDestinationAddImage(destination, image, nil)
    guard CGImageDestinationFinalize(destination) else {
        throw NSError(domain: "FrozenAppsIcon", code: 2, userInfo: [NSLocalizedDescriptionKey: "Could not write PNG at \(url.path)"])
    }
}

func main() throws {
    let contentsURL = iconSet.appendingPathComponent("Contents.json")
    let contentsData = try Data(contentsOf: contentsURL)
    guard let contents = try JSONSerialization.jsonObject(with: contentsData) as? [String: Any],
          let images = contents["images"] as? [[String: Any]] else {
        throw NSError(domain: "FrozenAppsIcon", code: 3, userInfo: [NSLocalizedDescriptionKey: "Invalid AppIcon Contents.json"])
    }

    var generated = Set<String>()
    for entry in images {
        guard let filename = entry["filename"] as? String,
              let sizeText = entry["size"] as? String else { continue }
        guard generated.insert(filename).inserted else { continue }

        let parts = sizeText.split(separator: "x")
        guard parts.count == 2, let pointSize = Double(parts[0]) else {
            throw NSError(domain: "FrozenAppsIcon", code: 4, userInfo: [NSLocalizedDescriptionKey: "Invalid icon size: \(sizeText)"])
        }
        let scaleText = (entry["scale"] as? String ?? "1x").replacingOccurrences(of: "x", with: "")
        let scale = Double(scaleText) ?? 1
        let pixels = max(1, Int((pointSize * scale).rounded()))
        let variant = filename.localizedCaseInsensitiveContains("tinted") ? "tinted"
            : filename.localizedCaseInsensitiveContains("dark") ? "dark" : "standard"
        try writePNG(makeIcon(size: pixels, variant: variant),
                     to: iconSet.appendingPathComponent(filename))
    }

    try writePNG(makeIcon(size: 512, variant: "standard"),
                 to: logoSet.appendingPathComponent("AppLogo.png"))
    print("Generated \(generated.count) FrozenApps app-icon renditions and AppLogo.png.")
}

do {
    try main()
} catch {
    fputs("FrozenApps icon generation failed: \(error)\n", stderr)
    exit(1)
}
