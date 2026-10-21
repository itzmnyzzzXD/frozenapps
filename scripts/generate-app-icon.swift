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

struct StickPixel: Hashable {
    let x: Int
    let y: Int
}

func makeIcon(size: Int, variant: String) -> CGImage {
    let dimension = CGFloat(size)
    let context = CGContext(
        data: nil,
        width: size,
        height: size,
        bitsPerComponent: 8,
        bytesPerRow: 0,
        space: CGColorSpaceCreateDeviceRGB(),
        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
    )!
    let rect = CGRect(x: 0, y: 0, width: dimension, height: dimension)
    context.setFillColor(cgColor(1, 1, 1, 1))
    context.fill(rect)
    context.setAllowsAntialiasing(false)
    context.setShouldAntialias(false)
    context.interpolationQuality = .none

    // The rod is built from chunky square pixels, with an 8-neighbour outline.
    // Every step advances right and up, like the vanilla Minecraft inventory item.
    var wood = [StickPixel: CGColor]()
    for step in 0..<14 {
        let x = 5 + step
        let y = 18 - step
        wood[StickPixel(x: x, y: y)] = cgColor(0.76, 0.52, 0.29)
        wood[StickPixel(x: x + 1, y: y)] = cgColor(0.63, 0.39, 0.20)
        wood[StickPixel(x: x, y: y + 1)] = cgColor(0.53, 0.31, 0.15)
        wood[StickPixel(x: x + 1, y: y + 1)] = cgColor(0.40, 0.23, 0.12)
    }

    let body = Set(wood.keys)
    var outline = Set<StickPixel>()
    for pixel in body {
        for dx in -1...1 {
            for dy in -1...1 {
                let neighbour = StickPixel(x: pixel.x + dx, y: pixel.y + dy)
                if !body.contains(neighbour) { outline.insert(neighbour) }
            }
        }
    }

    let cell = dimension / 24.0
    func pixelRect(_ pixel: StickPixel) -> CGRect {
        CGRect(
            x: CGFloat(pixel.x) * cell,
            y: dimension - CGFloat(pixel.y + 1) * cell,
            width: cell + 0.15,
            height: cell + 0.15
        )
    }

    // Small, hard-edged shadow gives the pixel item depth without any blur cost.
    for pixel in body {
        let shadowPixel = StickPixel(x: pixel.x + 1, y: pixel.y + 1)
        context.setFillColor(cgColor(0.25, 0.18, 0.14, 0.11))
        context.fill(pixelRect(shadowPixel))
    }
    context.setFillColor(cgColor(0.24, 0.14, 0.085))
    for pixel in outline { context.fill(pixelRect(pixel)) }
    for (pixel, color) in wood {
        context.setFillColor(color)
        context.fill(pixelRect(pixel))
    }

    // A few square highlights and darker wood-grain pixels preserve the blocky look.
    for step in [1, 4, 7, 10, 12] {
        let pixel = StickPixel(x: 5 + step, y: 18 - step)
        context.setFillColor(cgColor(0.88, 0.68, 0.42))
        context.fill(pixelRect(pixel))
    }
    for step in [2, 6, 9, 13] {
        let pixel = StickPixel(x: 6 + step, y: 19 - step)
        context.setFillColor(cgColor(0.34, 0.19, 0.095))
        context.fill(pixelRect(pixel))
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
