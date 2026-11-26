#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import json, plistlib, re, sys

root = Path(sys.argv[1])
app = root / "Vendor/SideInstaller/ios-app"
integration = root / "InstallerIntegration"
failures = []

def fail(message):
    failures.append(message)

if not (app / "SideInstallerApp.swift").is_file():
    fail("generated app source is missing")
if (app / "Assets.xcassets/SideStickBackground.imageset").exists():
    fail("legacy wallpaper is still packaged")

swift_files = list(app.rglob("*.swift")) + list(integration.rglob("*.swift"))
material_pattern = re.compile(r"(?<![A-Za-z0-9_])\\.(?:ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial|ultraThickMaterial|material)(?![A-Za-z0-9_])")
color_pattern = re.compile(r"(?<![A-Za-z0-9_])\\.(?:blue|purple|red|green|orange|pink|cyan|yellow|indigo|teal|mint|brown|gray|secondary|tertiary)(?![A-Za-z0-9_])")
system_pattern = re.compile(r"\\bUIColor\\.system[A-Za-z0-9_]*|\\bColor\\(\\s*(?:uiColor:\\s*)?\\.system[A-Za-z0-9_]*")
constructor_pattern = re.compile(r"Color\\(\\s*(?:red:|white:)|UIColor\\(\\s*(?:(?:displayP3)?Red:|white:)", re.IGNORECASE)
hex_pattern = re.compile(r"#[0-9A-Fa-f]{3,8}\\b")
allowed_hex = {"#000000", "#FFFFFF"}
allowed_opacity = {0.0, 0.03, 0.06, 0.12, 0.24, 0.48, 0.72, 1.0}
opacity_pattern = re.compile(r"\\.opacity\\(([^()]*)\\)")
number_pattern = re.compile(r"(?<![A-Za-z0-9_.])(?:0?\\.\\d+|0|1(?:\\.0+)?)(?![A-Za-z0-9_.])")

for path in swift_files:
    source = path.read_text(encoding="utf-8", errors="replace")
    source = re.sub(r"/\\*.*?\\*/", "", source, flags=re.S)
    source = re.sub(r"//.*$", "", source, flags=re.M)
    relative = path.relative_to(root)
    for pattern, label in (
        (material_pattern, "system material"),
        (color_pattern, "colored/system gray token"),
        (system_pattern, "system UI color"),
        (constructor_pattern, "raw RGB/white color constructor"),
    ):
        match = pattern.search(source)
        if match:
            line = source.count("\\n", 0, match.start()) + 1
            fail(f"{label} at {relative}:{line}")
    for match in hex_pattern.finditer(source):
        value = match.group(0).upper()
        if value not in allowed_hex:
            line = source.count("\\n", 0, match.start()) + 1
            fail(f"non-monochrome hex {value} at {relative}:{line}")
    for call in opacity_pattern.finditer(source):
        for number in number_pattern.finditer(call.group(1)):
            value = float(number.group(0))
            if 0 <= value <= 1 and min(allowed_opacity, key=lambda x: abs(x-value)) != value:
                line = source.count("\\n", 0, call.start()) + 1
                fail(f"opacity {value:g} is outside allowed steps at {relative}:{line}")

root_app_path = app / "SideInstallerApp.swift"
root_view_path = app / "RootView.swift"
account_path = app / "AccountViews.swift"
if root_app_path.is_file():
    root_app = root_app_path.read_text(encoding="utf-8")
    if "LiquidChromeBackground(interaction: liquidChromeInput)" not in root_app:
        fail("shared LiquidChrome renderer is not mounted at the app root")
    if "FrozenLaunchWelcome" not in root_app:
        fail("launch Text Reveal is not mounted")
    if ".tint(.white)" not in root_app or ".preferredColorScheme(.dark)" not in root_app:
        fail("app root is missing white tint or forced dark scheme")
if root_view_path.is_file():
    root_view = root_view_path.read_text(encoding="utf-8")
    if "FrozenInstallProgressPopup()" not in root_view or "FrozenAnimatedOTPInput(" not in root_view:
        fail("install popup or OTP is not wired in RootView")
    if "FrozenWorkspaceRail" in root_view or "FrozenWorkspaceCommandBar" in root_view:
        fail("old sidebar or command bar remains")
if account_path.is_file() and "FrozenAnimatedAccountReadiness(" not in account_path.read_text(encoding="utf-8"):
    fail("animated account feedback is not bound to real fields")
if "FrozenInstallProgressStack()" not in (integration / "FrozenInstallProgressPopup.swift").read_text(encoding="utf-8"):
    fail("install progress stack is missing from the stats screen")
for path in integration.rglob("*.swift"):
    if 'Image("SideStickBackground")' in path.read_text(encoding="utf-8", errors="replace"):
        fail(f"legacy wallpaper image reference remains in {path.relative_to(root)}")

catalog = app / "Assets.xcassets"
for name, expected in (("AccentColor", (1.0, 1.0, 1.0)), ("LaunchBackground", (0.0, 0.0, 0.0))):
    manifest = catalog / f"{name}.colorset/Contents.json"
    if not manifest.is_file():
        fail(f"{name} colorset is missing")
        continue
    data = json.loads(manifest.read_text(encoding="utf-8"))
    components = data["colors"][0]["color"]["components"]
    actual = tuple(float(components[k]) for k in ("red", "green", "blue"))
    if actual != expected:
        fail(f"{name} must be {expected}; found {actual}")

for manifest in catalog.rglob("*.colorset/Contents.json"):
    data = json.loads(manifest.read_text(encoding="utf-8"))
    for item in data.get("colors", []):
        components = item.get("color", {}).get("components", {})
        try:
            rgb = tuple(float(components[key]) for key in ("red", "green", "blue"))
            alpha = float(components.get("alpha", "1.000"))
        except Exception:
            continue
        if rgb not in ((0.0, 0.0, 0.0), (1.0, 1.0, 1.0)):
            fail(f"asset color is not pure black/white: {manifest.relative_to(root)}")
        if min(allowed_opacity, key=lambda x: abs(x-alpha)) != alpha:
            fail(f"asset alpha {alpha:g} is outside allowed steps: {manifest.relative_to(root)}")

info_path = app / "Info.plist"
if info_path.is_file():
    info = plistlib.loads(info_path.read_bytes())
    if info.get("UIUserInterfaceStyle") != "Dark":
        fail("Info.plist is not forced to dark mode")
    launch = info.get("UILaunchScreen", {})
    if launch.get("UIColorName") != "LaunchBackground":
        fail("launch screen is not using the black LaunchBackground colorset")

if failures:
    for failure in failures:
        print("FAIL: " + failure)
    raise SystemExit(f"FAIL: {len(failures)} monochrome violation(s).")

print("PASS: zero chromatic tokens, system materials, raw color constructors, non-monochrome hex and off-step opacity values.")
print("PASS: solid black surfaces, white tint, dark scheme, black launch screen and grayscale color assets.")
print("PASS: LiquidChrome root, launch reveal, login/OTP wiring, and install-only stats/progress stack.")
print("PASS: legacy wallpaper, sidebar and command bar are absent from the generated app.")
PY
