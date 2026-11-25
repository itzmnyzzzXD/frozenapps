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
SOURCE_ICON = ROOT / "IMG_2151.jpeg"
ASSETS = APP / "Assets.xcassets"
MARK_SET = ASSETS / "SideStickMark.imageset"
ICON_SET = ASSETS / "AppIcon.appiconset"

if not (APP / "Info.plist").is_file():
    raise SystemExit("Generated app Info.plist is missing; prepare the pinned engine first.")
if not SOURCE_ICON.is_file():
    raise SystemExit("IMG_2151.jpeg is missing from the repository root.")
if not ASSETS.is_dir():
    raise SystemExit("The upstream app asset catalog is missing.")

def write_solid_color_asset(name, component):
    color_set = ASSETS / f"{name}.colorset"
    color_set.mkdir(parents=True, exist_ok=True)
    components = {"red": component, "green": component, "blue": component, "alpha": "1.000"}
    (color_set / "Contents.json").write_text(json.dumps({
        "colors": [{"color": {"color-space": "srgb", "components": components}, "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1}
    }, indent=2) + "\n", encoding="utf-8")

write_solid_color_asset("AccentColor", "1.000")
write_solid_color_asset("LaunchBackground", "0.000")

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
    width_match = re.search("pixelWidth:[ ]*([0-9]+)", dimensions)
    height_match = re.search("pixelHeight:[ ]*([0-9]+)", dimensions)
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
    }, indent=2) + "\n", encoding="utf-8")

STRING_PATTERN = r'"(?:\\.|[^"\\])*"'

def rebrand_literal(match, source):
    literal = match.group(0)
    # Never alter URLs, bundle identifiers, notification names, URL schemes or dotted keys.
    if "://" in literal or "com.itzmnyzzz.frozenapps" in literal:
        return literal

    text = literal[1:-1]
    if text == "Welcome to FrozenApps":
        return literal
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
                        Image("SideStickMark").grayscale(1).resizable().scaledToFit().grayscale(1).padding(12)
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
                        Image("SideStickMark").grayscale(1).resizable().scaledToFit().grayscale(1).padding(9)
                    } else {
                        Image(systemName: resolvedIcon)
                    }
                }'''
        )
        branded = branded.replace(
            'Image(systemName: "snowflake")',
            'Image("SideStickMark").grayscale(1).resizable().scaledToFit().grayscale(1).padding(9)'
        )
        branded = re.sub(
            r'Label\(([^,\n]+),\s*systemImage:\s*"snowflake"\)',
            lambda match: 'Label { Text(' + match.group(1) + ') } icon: { '
                'Image("SideStickMark").grayscale(1).resizable().scaledToFit().grayscale(1).frame(width: 17, height: 17) }',
            branded
        )
        if 'if symbol == "snowflake"' not in branded:
            branded = branded.replace(
                'Image(systemName: symbol)',
                '''Group {
                    if symbol == "snowflake" {
                        Image("SideStickMark").grayscale(1).resizable().scaledToFit().grayscale(1).frame(width: 17, height: 17)
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
                "                FrozenWorkspaceBackdrop()\n                if proxy.size.width >= 760 {",
                "                if proxy.size.width >= 760 {",
                1
            )
        if branded != source:
            swift_path.write_text(branded, encoding="utf-8")

# Enforce the OLED palette across app-owned and generated SwiftUI source.
OPACITY_STEPS = (0.03, 0.06, 0.12, 0.24, 0.48, 0.72, 1.0)

def snap_opacity(value):
    value = max(0.0, min(1.0, float(value)))
    if value < 0.015:
        return 0.0
    return min(OPACITY_STEPS, key=lambda step: abs(step - value))

def opacity_literal(value):
    snapped = snap_opacity(value)
    if snapped == 0.0: return "0"
    if snapped == 1.0: return "1"
    return f"{snapped:.2f}"

def grayscale_rgb(match):
    red, green, blue = (float(match.group(index)) for index in (1, 2, 3))
    luminance = max(0.0, min(1.0, 0.2126 * red + 0.7152 * green + 0.0722 * blue))
    source_opacity = float(match.group(4)) if match.group(4) is not None else 1.0
    opacity = snap_opacity(luminance * source_opacity)
    if opacity == 0.0: return "Color.black"
    if opacity == 1.0: return "Color.white"
    return f"Color.white.opacity({opacity:.2f})"

rgb_pattern = (
    r"Color\(red:\s*((?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)),"
    r"\s*green:\s*((?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)),"
    r"\s*blue:\s*((?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+))"
    r"(?:,\s*opacity:\s*((?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)))?\)"
)
opacity_pattern = re.compile(r"\.opacity\(\s*((?:0(?:\.[0-9]+)?|1(?:\.0+)?))\s*\)")
BACKGROUND_COLOR_TYPES = (
    "systemBackground", "secondarySystemBackground", "tertiarySystemBackground",
    "systemGroupedBackground", "secondarySystemGroupedBackground",
    "tertiarySystemGroupedBackground", "groupTableViewBackground"
)
FILL_COLOR_TYPES = ("systemFill", "secondarySystemFill", "tertiarySystemFill", "quaternarySystemFill")
CHROMATIC_UI_COLORS = (
    "systemBlue", "systemRed", "systemGreen", "systemOrange", "systemYellow",
    "systemPurple", "systemPink", "systemTeal", "systemCyan", "systemIndigo",
    "systemMint", "systemBrown"
)

def normalize_swift(source):
    monochrome = source
    monochrome = monochrome.replace("Theme.accent2", ".white")
    monochrome = monochrome.replace("Theme.accent", ".white")
    monochrome = monochrome.replace("Theme.violet", ".white")
    monochrome = monochrome.replace("Theme.glow", ".white.opacity(0.12)")
    monochrome = monochrome.replace(
        "Theme.brand",
        "LinearGradient(colors: [.white.opacity(0.72), .white.opacity(0.24)], "
        "startPoint: .topLeading, endPoint: .bottomTrailing)"
    )
    monochrome = re.sub(r"\.tint\([^()]*\)", ".tint(.white)", monochrome)
    monochrome = re.sub(
        r"\.(?:red|orange|yellow|green|mint|teal|cyan|blue|indigo|purple|pink|brown)(?![A-Za-z0-9_])",
        ".white",
        monochrome
    )
    monochrome = re.sub(rgb_pattern, grayscale_rgb, monochrome)
    monochrome = re.sub(
        r"Color\\(white:\\s*((?:[0-9]+(?:\\.[0-9]*)?|\\.[0-9]+))\\)",
        lambda match: (
            "Color.black" if snap_opacity(float(match.group(1))) == 0.0
            else ("Color.white" if snap_opacity(float(match.group(1))) == 1.0
                  else f"Color.white.opacity({snap_opacity(float(match.group(1))):.2f})")
        ),
        monochrome
    )

    for name in BACKGROUND_COLOR_TYPES:
        monochrome = monochrome.replace(f"Color(.{name})", "Color.black")
        monochrome = monochrome.replace(f"UIColor.{name}", "UIColor.black")
    for name in FILL_COLOR_TYPES:
        monochrome = monochrome.replace(f"Color(.{name})", "Color.white.opacity(0.12)")
        monochrome = monochrome.replace(f"UIColor.{name}", "UIColor.white.withAlphaComponent(0.12)")
    for name in CHROMATIC_UI_COLORS:
        monochrome = monochrome.replace(f"Color(.{name})", "Color.white")
        monochrome = monochrome.replace(f"UIColor.{name}", "UIColor.white")

    replacements = {
        "Color(.label)": "Color.white",
        "Color(.secondaryLabel)": "Color.white.opacity(0.48)",
        "Color(.tertiaryLabel)": "Color.white.opacity(0.24)",
        "Color(.quaternaryLabel)": "Color.white.opacity(0.12)",
        "Color(.placeholderText)": "Color.white.opacity(0.48)",
        "Color(.separator)": "Color.white.opacity(0.12)",
        "Color(.opaqueSeparator)": "Color.white.opacity(0.24)",
        "Color(uiColor: .systemBackground)": "Color.black",
        "Color(uiColor: .secondarySystemBackground)": "Color.black",
        "Color(uiColor: .secondaryLabel)": "Color.white.opacity(0.48)",
        "Color(uiColor: .tertiaryLabel)": "Color.white.opacity(0.24)",
        "Color.gray": "Color.white.opacity(0.48)",
        "Color.accentColor": "Color.white",
        "UIColor.tintColor": "UIColor.white",
    }
    for old, new in replacements.items():
        monochrome = monochrome.replace(old, new)
    monochrome = re.sub(r"\bUIColor\.systemGray(?:[2-6])?\b",
                        "UIColor.white.withAlphaComponent(0.48)", monochrome)

    for material in ("ultraThinMaterial", "thinMaterial", "regularMaterial", "thickMaterial", "bar"):
        monochrome = re.sub(rf"\.{material}\b", "Color.black", monochrome)
    monochrome = monochrome.replace(
        ".glassEffect(.regular, in: Capsule())",
        ".background(Capsule().fill(Color.black))"
    )
    monochrome = re.sub(
        r"(\.(?:foregroundStyle|foregroundColor)\s*\([^()\n]*?)\.secondary\b",
        r"\1.white.opacity(0.48)", monochrome
    )
    monochrome = re.sub(
        r"(\.(?:foregroundStyle|foregroundColor)\s*\([^()\n]*?)\.tertiary\b",
        r"\1.white.opacity(0.24)", monochrome
    )
    monochrome = re.sub(
        r"(\.(?:foregroundStyle|foregroundColor)\s*\([^()\n]*?)\.primary\b",
        r"\1.white", monochrome
    )
    return opacity_pattern.sub(
        lambda match: f".opacity({opacity_literal(match.group(1))})",
        monochrome
    )

swift_paths = set()
for folder in (APP, ACTIVITY, INTEGRATION):
    if folder.exists():
        swift_paths.update(folder.rglob("*.swift"))
theme_path = ROOT / "SideStickTheme.swift"
if theme_path.is_file():
    swift_paths.add(theme_path)

for swift_path in sorted(swift_paths):
    source = swift_path.read_text(encoding="utf-8")
    monochrome = normalize_swift(source)
    if swift_path.name == "Theme.swift":
        start = monochrome.find("struct AppBackground: View {")
        end = monochrome.find("// MARK: - Cards", start)
        if start >= 0 and end > start:
            monochrome = (
                monochrome[:start]
                + "struct AppBackground: View {\n"
                  "    var body: some View {\n"
                  "        Color.black.ignoresSafeArea()\n"
                  "    }\n"
                  "}\n\n"
                + monochrome[end:]
            )
    monochrome = monochrome.replace(
        'Image("SideStickMark")',
        'Image("SideStickMark").grayscale(1)'
    )
    if monochrome != source:
        swift_path.write_text(monochrome, encoding="utf-8")

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
info["UIUserInterfaceStyle"] = "Dark"
launch_screen = info.get("UILaunchScreen", {})
launch_screen["UIColorName"] = "LaunchBackground"
info["UILaunchScreen"] = launch_screen
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
