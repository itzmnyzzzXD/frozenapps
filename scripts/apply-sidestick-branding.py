#!/usr/bin/env python3
"""Apply SideStick branding and the selected background after all UI source patches.

This is a presentation-only pass: it does not alter the layout, app bundle identifier,
authentication, Keychain service, pairing protocol, stored preference keys, or install callbacks.
"""
from pathlib import Path
import json
import plistlib
import re
import shutil
import subprocess
import tempfile

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "Vendor" / "SideInstaller"
APP = VENDOR / "ios-app"
ACTIVITY = VENDOR / "ios-live-activity"
INTEGRATION = ROOT / "InstallerIntegration"
SOURCE_BACKGROUND = ROOT / "IMG_2135.jpeg"
SOURCE_ICON = ROOT / "IMG_2151.jpeg"
ASSETS = APP / "Assets.xcassets"
BACKGROUND_SET = ASSETS / "SideStickBackground.imageset"
MARK_SET = ASSETS / "SideStickMark.imageset"
ICON_SET = ASSETS / "AppIcon.appiconset"

if not (APP / "Info.plist").is_file():
    raise SystemExit("Generated app Info.plist is missing; prepare the pinned engine first.")
if not SOURCE_BACKGROUND.is_file():
    raise SystemExit("IMG_2135.jpeg is missing from the repository root.")
if not SOURCE_ICON.is_file():
    raise SystemExit("IMG_2151.jpeg is missing from the repository root.")
if not ASSETS.is_dir():
    raise SystemExit("The upstream app asset catalog is missing.")

# Add the supplied image to the asset catalog used by the app target.
BACKGROUND_SET.mkdir(parents=True, exist_ok=True)
shutil.copyfile(SOURCE_BACKGROUND, BACKGROUND_SET / "IMG_2135.jpeg")
(BACKGROUND_SET / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "IMG_2135.jpeg", "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n", encoding="utf-8")

# Reuse IMG_2151.jpeg as a small in-app brand mark. Keeping it in the existing
# asset catalog means it is compiled into Assets.car instead of loaded at runtime.
MARK_SET.mkdir(parents=True, exist_ok=True)
shutil.copyfile(SOURCE_ICON, MARK_SET / "IMG_2151.jpeg")
(MARK_SET / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "IMG_2151.jpeg", "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n", encoding="utf-8")

# iOS app icons must be square PNGs at their required pixel sizes. Convert once,
# center-crop the supplied JPEG, then derive all legacy iPhone/iPad sizes from
# one 1024px master to avoid missing icon slots on older supported iOS versions.
icon_specs = [
    ("iphone", "20x20", "2x", "AppIcon-20@2x.png", 40),
    ("iphone", "20x20", "3x", "AppIcon-20@3x.png", 60),
    ("iphone", "29x29", "1x", "AppIcon-29.png", 29),
    ("iphone", "29x29", "2x", "AppIcon-29@2x.png", 58),
    ("iphone", "29x29", "3x", "AppIcon-29@3x.png", 87),
    ("iphone", "40x40", "2x", "AppIcon-40@2x.png", 80),
    ("iphone", "40x40", "3x", "AppIcon-40@3x.png", 120),
    ("iphone", "60x60", "2x", "AppIcon@2x.png", 120),
    ("iphone", "60x60", "3x", "AppIcon@3x.png", 180),
    ("ipad", "20x20", "1x", "AppIcon-20~ipad.png", 20),
    ("ipad", "20x20", "2x", "AppIcon-20@2x~ipad.png", 40),
    ("ipad", "29x29", "1x", "AppIcon-29~ipad.png", 29),
    ("ipad", "29x29", "2x", "AppIcon-29@2x~ipad.png", 58),
    ("ipad", "40x40", "1x", "AppIcon-40~ipad.png", 40),
    ("ipad", "40x40", "2x", "AppIcon-40@2x~ipad.png", 80),
    ("ipad", "76x76", "1x", "AppIcon~ipad.png", 76),
    ("ipad", "76x76", "2x", "AppIcon@2x~ipad.png", 152),
    ("ipad", "83.5x83.5", "2x", "AppIcon-83.5@2x~ipad.png", 167),
    ("ios-marketing", "1024x1024", "1x", "AppIcon~ios-marketing.png", 1024),
]
with tempfile.TemporaryDirectory(prefix="sidestick-icon-") as temporary_directory:
    temporary = Path(temporary_directory)
    normalized = temporary / "input.png"
    square = temporary / "square.png"
    master = temporary / "icon-1024.png"
    subprocess.run(
        ["sips", "-s", "format", "png", str(SOURCE_ICON), "--out", str(normalized)],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    dimensions = subprocess.run(
        ["sips", "-g", "pixelWidth", "-g", "pixelHeight", str(normalized)],
        check=True, capture_output=True, text=True
    ).stdout
    width_match = re.search(r"pixelWidth:\\s*(\\d+)", dimensions)
    height_match = re.search(r"pixelHeight:\\s*(\\d+)", dimensions)
    if not width_match or not height_match:
        raise SystemExit("Could not read IMG_2151.jpeg dimensions to create the app icon.")
    image_width, image_height = int(width_match.group(1)), int(height_match.group(1))
    crop_size = min(image_width, image_height)
    crop_top = (image_height - crop_size) // 2
    crop_left = (image_width - crop_size) // 2
    subprocess.run(
        ["sips", "-c", str(crop_size), str(crop_size), "--cropOffset",
         str(crop_top), str(crop_left), str(normalized), "--out", str(square)],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    subprocess.run(
        ["sips", "-z", "1024", "1024", str(square), "--out", str(master)],
        check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
    )
    if ICON_SET.exists():
        shutil.rmtree(ICON_SET)
    ICON_SET.mkdir(parents=True, exist_ok=True)
    manifest_images = []
    for idiom, size, scale, filename, pixels in icon_specs:
        output = ICON_SET / filename
        subprocess.run(
            ["sips", "-z", str(pixels), str(pixels), str(master), "--out", str(output)],
            check=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE, text=True
        )
        manifest_images.append({
            "filename": filename, "idiom": idiom, "scale": scale, "size": size
        })
    (ICON_SET / "Contents.json").write_text(json.dumps({
        "images": manifest_images, "info": {"author": "xcode", "version": 1}
    }, indent=2) + "\\n", encoding="utf-8")

STRING_PATTERN = r'"(?:\\.|[^"\\])*"'

def rebrand_literal(match, source):
    literal = match.group(0)
    # Never alter URLs, bundle identifiers, notification names, URL schemes or dotted keys.
    if "://" in literal or "com.itzmnyzzz.frozenapps" in literal:
        return literal

    text = literal[1:-1]
    if "." in text and not any(ch.isspace() for ch in text):
        return literal

    # Exact product-name strings are only changed when used as a visible SwiftUI/localized
    # label. A bare "FrozenApps" can also be a storage/engine key, so check its call site.
    if text in ("FrozenApps", "FROZENAPPS"):
        prefix = source[max(0, match.start() - 96):match.start()]
        if not re.search(r"(?:Text|Label|Button|Section|BrandHeader|L)\s*\([^()\n]*$", prefix):
            return literal
        return '"SideStick"' if text == "FrozenApps" else '"SIDESTICK"'

    # Full phrases/sentences are user-facing copy; internal no-space keys are left intact.
    if not any(ch.isspace() for ch in text):
        return literal

    text = text.replace("FROZENAPPS", "SIDESTICK")
    text = text.replace("FrozenApps", "SideStick")
    text = text.replace("Frozen Center", "SideStick Center")
    text = text.replace("Frozen Apps", "SideStick")
    return '"' + text + '"'

# Rebrand only string contents; preserve Swift symbols, type names, URLs and preference keys.
for folder in (APP, ACTIVITY, INTEGRATION):
    if not folder.exists():
        continue
    for swift_path in folder.rglob("*.swift"):
        source = swift_path.read_text(encoding="utf-8")
        branded = re.sub(STRING_PATTERN, lambda m: rebrand_literal(m, source), source)
        # Swap existing background calls without moving or rebuilding any screens.
        branded = branded.replace("AppBackground()", "FrozenWorkspaceBackdrop()")

        # Replace only the old snowflake symbols; surrounding containers, sizes and
        # navigation layout remain in place. Use custom Label builders where needed.
        branded = branded.replace(
            'Image(systemName: engine.isRunning ? "arrow.clockwise" : "snowflake")',
            '''Group {
                    if engine.isRunning {
                        Image(systemName: "arrow.clockwise")
                    } else {
                        Image("SideStickMark").resizable().scaledToFit().padding(12)
                    }
                }'''
        )
        branded = branded.replace(
            'default: icon ?? "snowflake"',
            'default: icon ?? "SideStickMark"'
        )
        branded = branded.replace(
            'Image(systemName: resolvedIcon)',
            '''Group {
                    if resolvedIcon == "SideStickMark" {
                        Image("SideStickMark").resizable().scaledToFit().padding(9)
                    } else {
                        Image(systemName: resolvedIcon)
                    }
                }'''
        )
        branded = branded.replace(
            'Image(systemName: "snowflake")',
            'Image("SideStickMark").resizable().scaledToFit().padding(9)'
        )
        branded = re.sub(
            r'Label\\(([^,\\n]+),\\s*systemImage:\\s*"snowflake"\\)',
            lambda match: 'Label { Text(' + match.group(1) + ') } icon: { '
                'Image("SideStickMark").resizable().scaledToFit().frame(width: 17, height: 17) }',
            branded
        )
        if 'if symbol == "snowflake"' not in branded:
            branded = branded.replace(
                'Image(systemName: symbol)',
                '''Group {
                    if symbol == "snowflake" {
                        Image("SideStickMark").resizable().scaledToFit().frame(width: 17, height: 17)
                    } else {
                        Image(systemName: symbol)
                    }
                }'''
            )

        # These two effects are very expensive when repeated across long glass pages.
        if swift_path.name == "FrozenGlassComponents.swift":
            branded = branded.replace('.fill(.regularMaterial)', '.fill(.ultraThinMaterial)')
            branded = branded.replace(
                '.background(.regularMaterial, in: Capsule())',
                '.background(.ultraThinMaterial, in: Capsule())'
            )
            branded = branded.replace(
                'color: Color.black.opacity(elevated ? 0.23 : 0.13)',
                'color: Color.black.opacity(elevated ? 0.19 : 0.10)'
            )
            branded = branded.replace(
                'radius: elevated ? 24 : 12',
                'radius: elevated ? 16 : 8'
            )
            branded = branded.replace('y: elevated ? 10 : 5', 'y: elevated ? 7 : 4')

        # A full-screen backdrop is already supplied by each selected page.
        # Remove the redundant copy underneath the TabView to avoid extra overdraw.
        if swift_path.name == "RootView.swift":
            branded = branded.replace(
                'ZStack {\\n                FrozenWorkspaceBackdrop()\\n                if proxy.size.width >= 760 {',
                'ZStack {\\n                if proxy.size.width >= 760 {',
                1
            )
        if branded != source:
            swift_path.write_text(branded, encoding="utf-8")

# Avoid animating the entire Signer hierarchy for every connection/progress update.
content_view = APP / "ContentView.swift"
if content_view.is_file():
    source = content_view.read_text(encoding="utf-8")
    source = re.sub(
        r"^[ \t]*\.animation\(\.smooth\(duration: 0\.30\), value: "
        r"(?:engine\.isRunning|engine\.finished|engine\.deviceSummary|updateChecker\.showBanner)\)\n",
        "",
        source,
        flags=re.MULTILINE
    )
    content_view.write_text(source, encoding="utf-8")

# Display branding only. Keep bundle identifiers/data namespace stable for upgrades.
info_path = APP / "Info.plist"
info = plistlib.loads(info_path.read_bytes())
info["CFBundleDisplayName"] = "SideStick"
info["CFBundleName"] = "SideStick"
info["NSLocalNetworkUsageDescription"] = (
    "SideStick uses the local network for device pairing, app installation, "
    "and optional discovery of nearby HTTP services."
)
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML, sort_keys=False))

activity_path = ACTIVITY / "Info.plist"
if activity_path.is_file():
    activity = plistlib.loads(activity_path.read_bytes())
    for key in ("CFBundleDisplayName", "CFBundleName"):
        if key in activity:
            activity[key] = "SideStick"
    activity_path.write_bytes(plistlib.dumps(activity, fmt=plistlib.FMT_XML, sort_keys=False))

print("Applied SideStick branding, custom icon assets, and focused render optimizations.")
