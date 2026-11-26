#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"

python3 - "$ROOT" <<'PY'
from pathlib import Path
import json
import plistlib
import re
import sys

root = Path(sys.argv[1])
app = root / "Vendor" / "SideInstaller" / "ios-app"
activity = root / "Vendor" / "SideInstaller" / "ios-live-activity"
integration = root / "InstallerIntegration"
theme = root / "SideStickTheme.swift"
violations = []
checked_sources = 0
checked_colorsets = 0

scan = [integration]
if app.is_dir():
    scan.extend([app, activity])
else:
    print("WARN: Vendor submodule unavailable; generated app checks will run in CI after checkout.")

checks = [
    (
        "named chromatic color",
        re.compile(r"(?<![A-Za-z0-9_])\.(?:blue|purple|red|green|orange|pink|cyan|yellow|indigo|teal|mint|brown)(?![A-Za-z0-9_])")
    ),
    (
        "system gray or dynamic semantic color",
        re.compile(r"\b(?:Color|UIColor|NSColor)\.gray\b|\bUIColor\.systemGray(?:[2-6])?\b|\bColor\s*\(\s*white:|\bUIColor\s*\(\s*white:|\bColor\.(?:primary|secondary|tertiary)\b")
    ),
    (
        "UIKit system color",
        re.compile(r"\bUIColor\.(?:system[A-Z][A-Za-z0-9]*|secondarySystem[A-Z][A-Za-z0-9]*|tertiarySystem[A-Z][A-Za-z0-9]*|quaternarySystem[A-Z][A-Za-z0-9]*|label\b|secondaryLabel\b|tertiaryLabel\b|quaternaryLabel\b|placeholderText\b|separator\b|opaqueSeparator\b|tintColor\b)")
    ),
    (
        "SwiftUI system color asset",
        re.compile(r"\bColor\s*\(\s*(?:uiColor:\s*)?\.(?:system[A-Z][A-Za-z0-9]*|secondarySystem[A-Z][A-Za-z0-9]*|tertiarySystem[A-Z][A-Za-z0-9]*|quaternarySystem[A-Z][A-Za-z0-9]*|label\b|secondaryLabel\b|tertiaryLabel\b|quaternaryLabel\b|placeholderText\b|separator\b|opaqueSeparator\b)")
    ),
    (
        "semantic foreground color",
        re.compile(r"\.(?:foregroundStyle|foregroundColor)\s*\([^)]*\.(?:primary|secondary|tertiary)\b", re.DOTALL)
    ),
    (
        "system material",
        re.compile(r"\.(?:ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial)\b|\.glassEffect\(")
    ),
    (
        "RGB/HSB/white color constructor",
        re.compile(r"\b(?:Color|UIColor|NSColor|CGColor)\s*\([^)\n]*(?:red:|hue:|displayP3Red:|white:)")
    ),
    (
        "non-monochrome hex",
        re.compile(r"#([0-9A-Fa-f]{3,8})\b")
    ),
    (
        "light appearance override",
        re.compile(r"\.preferredColorScheme\s*\(\s*\.light\s*\)")
    ),
]

def fail(path, line, label, value):
    try:
        name = path.relative_to(root)
    except ValueError:
        name = str(path)
    violations.append(f"{name}:{line}: {label}: {value.strip()}")

source_files = []
for folder in scan:
    if folder.is_dir():
        source_files += list(folder.rglob("*.swift")) + list(folder.rglob("*.metal"))
if theme.is_file():
    source_files.append(theme)

for path in sorted(set(source_files)):
    checked_sources += 1
    source = path.read_text(encoding="utf-8", errors="replace")
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.DOTALL)
    for number, line in enumerate(source.splitlines(), 1):
        code_line = re.sub(r"//.*$", "", line)
        for label, pattern in checks:
            candidate = code_line if label in ("non-monochrome hex", "light appearance override") else line
            for match in pattern.finditer(candidate):
                if label == "non-monochrome hex" and match.group(1).upper() in {"000000", "FFFFFF"}:
                    continue
                fail(path, number, label, line)

catalog = app / "Assets.xcassets"
if catalog.is_dir():
    for manifest in sorted(catalog.rglob("*.colorset/Contents.json")):
        checked_colorsets += 1
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
        except Exception as error:
            fail(manifest, 1, "invalid colorset", str(error))
            continue
        for item in data.get("colors", []):
            components = item.get("color", {}).get("components", {})
            try:
                values = tuple(float(components[key]) for key in ("red", "green", "blue"))
            except Exception:
                fail(manifest, 1, "non-sRGB colorset", repr(components))
                continue

            # The only chromatic exception is the shared, explicitly named status accent.
            if manifest.parent.name == "SignalGreen.colorset":
                if values != (0.160, 0.910, 0.470):
                    fail(manifest, 1, "SignalGreen must match approved green accent", repr(values))
                continue

            if not (all(value == 0.0 for value in values) or all(value == 1.0 for value in values)):
                fail(manifest, 1, "chromatic/gray colorset", repr(components))

    required_colors = {
        "AccentColor": (1.0, 1.0, 1.0),
        "LaunchBackground": (0.0, 0.0, 0.0),
    }
    for name, expected in required_colors.items():
        manifest = catalog / f"{name}.colorset" / "Contents.json"
        if not manifest.is_file():
            fail(catalog, 1, "required colorset missing", name)
            continue
        try:
            data = json.loads(manifest.read_text(encoding="utf-8"))
            color = data["colors"][0]["color"]["components"]
            actual = tuple(float(color[channel]) for channel in ("red", "green", "blue"))
            if actual != expected:
                fail(manifest, 1, f"{name} must be {'white' if expected[0] else 'black'}", repr(actual))
        except Exception as error:
            fail(manifest, 1, "invalid required colorset", str(error))

    signal_green_manifest = catalog / "SignalGreen.colorset" / "Contents.json"
    if not signal_green_manifest.is_file():
        fail(catalog, 1, "required green accent colorset missing", "SignalGreen")
    else:
        try:
            data = json.loads(signal_green_manifest.read_text(encoding="utf-8"))
            color = data["colors"][0]["color"]["components"]
            actual = tuple(float(color[channel]) for channel in ("red", "green", "blue"))
            if actual != (0.160, 0.910, 0.470):
                fail(signal_green_manifest, 1, "SignalGreen must match approved green accent", repr(actual))
        except Exception as error:
            fail(signal_green_manifest, 1, "invalid SignalGreen colorset", str(error))

info = app / "Info.plist"
if info.is_file():
    try:
        plist = plistlib.loads(info.read_bytes())
        if plist.get("UIUserInterfaceStyle") != "Dark":
            fail(info, 1, "UIUserInterfaceStyle must be Dark", repr(plist.get("UIUserInterfaceStyle")))
        if plist.get("UILaunchScreen", {}).get("UIColorName") != "LaunchBackground":
            fail(info, 1, "launch screen must use LaunchBackground", repr(plist.get("UILaunchScreen")))
    except Exception as error:
        fail(info, 1, "invalid Info.plist", str(error))

root_app = app / "SideInstallerApp.swift"
if root_app.is_file():
    content = root_app.read_text(encoding="utf-8", errors="replace")
    for token in (".preferredColorScheme(.dark)", ".tint(.white)", "Color.black.ignoresSafeArea()"):
        if token not in content:
            fail(root_app, 1, "missing root appearance invariant", token)

if violations:
    print(f"FAIL: {len(violations)} monochrome violation(s) in {checked_sources} Swift/Metal files and {checked_colorsets} colorsets.")
    for violation in violations:
        print(" - " + violation)
    sys.exit(1)

print(f"PASS: {checked_sources} Swift/Metal files scanned; zero chromatic source violations.")
print(f"PASS: {checked_colorsets} colorsets scanned; colors are OLED black/white, with only the approved SignalGreen accent.")
if app.is_dir():
    print("PASS: AccentColor white; LaunchBackground black; Info.plist forced dark.")
    print("PASS: root tint white; root window black; preferred color scheme dark.")
else:
    print("PARTIAL: generated Vendor source checks execute in CI after submodule checkout.")
PY
