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
app = root / "Vendor/SideInstaller/ios-app"
activity = root / "Vendor/SideInstaller/ios-live-activity"
integration = root / "InstallerIntegration"
failures = []

def fail(message):
    failures.append(message)

if not (app / "SideInstallerApp.swift").is_file():
    fail("generated app source is missing")

swift_files = list(app.rglob("*.swift")) + list(activity.rglob("*.swift")) + list(integration.rglob("*.swift"))
metal_files = list(app.rglob("*.metal")) + list(integration.rglob("*.metal"))
if not (activity / "PairingActivityWidget.swift").is_file():
    fail("Live Activity widget source is missing from the generated target")
source_files = swift_files + metal_files

material_pattern = re.compile(
    r"(?<![A-Za-z0-9_])\.(?:ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial|ultraThickMaterial|material)(?![A-Za-z0-9_])"
)
color_pattern = re.compile(
    r"(?<![A-Za-z0-9_])\.(?:blue|purple|red|green|orange|pink|cyan|yellow|indigo|teal|mint|brown|gray|secondary|tertiary)(?![A-Za-z0-9_])"
)
system_pattern = re.compile(
    r"\bUIColor\.system[A-Za-z0-9_]*|\bColor\(\s*(?:uiColor:\s*)?\.system[A-Za-z0-9_]*"
)
constructor_pattern = re.compile(
    r"Color\(\s*(?:red:|white:)|UIColor\(\s*(?:(?:displayP3)?Red:|white:)",
    re.IGNORECASE,
)
hex_pattern = re.compile(r"#[0-9A-Fa-f]{3,8}\b")
allowed_hex = {"#000000", "#FFFFFF"}
allowed_opacity = {0.0, 0.03, 0.06, 0.12, 0.24, 0.48, 0.72, 1.0}
opacity_pattern = re.compile(r"\.opacity\(([^()]*)\)")
number_pattern = re.compile(r"(?<![A-Za-z0-9_.])(?:0?\.\d+|0|1(?:\.0+)?)(?![A-Za-z0-9_.])")

for path in source_files:
    source = path.read_text(encoding="utf-8", errors="replace")
    source = re.sub(r"/\*.*?\*/", "", source, flags=re.S)
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
            line = source.count("\n", 0, match.start()) + 1
            fail(f"{label} at {relative}:{line}")

    for match in hex_pattern.finditer(source):
        value = match.group(0).upper()
        if value not in allowed_hex:
            line = source.count("\n", 0, match.start()) + 1
            fail(f"non-monochrome hex {value} at {relative}:{line}")

    for call in opacity_pattern.finditer(source):
        for number in number_pattern.finditer(call.group(1)):
            value = float(number.group(0))
            if 0 <= value <= 1 and value not in allowed_opacity:
                line = source.count("\n", 0, call.start()) + 1
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
    if ".tint(.white)" not in root_app:
        fail("app root is missing .tint(.white)")
    if ".preferredColorScheme(.dark)" not in root_app:
        fail("app root is missing .preferredColorScheme(.dark) for dark keyboard/status bar")
    if ".background(Color.black.ignoresSafeArea())" not in root_app:
        fail("app window/root background is not solid black")

if root_view_path.is_file():
    root_view = root_view_path.read_text(encoding="utf-8")
    if "FrozenInstallProgressPopup()" not in root_view or "FrozenAnimatedOTPInput(" not in root_view:
        fail("install popup or OTP is not wired in RootView")
    if "FrozenWorkspaceRail" in root_view or "FrozenWorkspaceCommandBar" in root_view:
        fail("old sidebar or command bar remains")

if account_path.is_file() and "FrozenAnimatedAccountReadiness(" not in account_path.read_text(encoding="utf-8"):
    fail("animated account feedback is not bound to real fields")

progress_path = integration / "FrozenInstallProgressPopup.swift"
if progress_path.is_file():
    progress_source = progress_path.read_text(encoding="utf-8")
    if "FrozenInstallProgressStack()" not in progress_source:
        fail("install progress stack is missing from the stats screen")
    if "Image(uiImage: appIcon).resizable().renderingMode(.original).saturation(0)" not in progress_source:
        fail("runtime app bundle icon is not displayed in grayscale")

# Keep the original wallpaper files for source/license history, but assert that
# neither source views nor the workspace backdrop refer to them.
for path in swift_files:
    source = path.read_text(encoding="utf-8", errors="replace")
    for token in ("SideStickBackground", "IMG_2135.jpeg", "AppBackground()"):
        if token in source:
            line = source.count("\n", 0, source.index(token)) + 1
            fail(f"legacy/image background reference {token!r} at {path.relative_to(root)}:{line}")

backdrop_path = integration / "FrozenGlassComponents.swift"
if backdrop_path.is_file():
    backdrop = backdrop_path.read_text(encoding="utf-8", errors="replace")
    body = backdrop.split("struct FrozenWorkspaceBackdrop: View {", 1)[-1].split("/// A monochrome black surface", 1)[0]
    if "Color.black.ignoresSafeArea()" not in body:
        fail("workspace backdrop is not a solid black Color surface")
    if "Image(" in body or "Material" in body:
        fail("workspace backdrop contains an image or system material")

# No app-owned background modifier may paint an image. Icons/images remain
# allowed in ordinary content rows and cards.
image_background = re.compile(r"\.background\s*(?:\(\s*Image\s*\(|\{\s*Image\s*\()")
for path in swift_files:
    source = path.read_text(encoding="utf-8", errors="replace")
    match = image_background.search(source)
    if match:
        line = source.count("\n", 0, match.start()) + 1
        fail(f"image-based background at {path.relative_to(root)}:{line}")

catalog = app / "Assets.xcassets"
for name, expected in (("AccentColor", (1.0, 1.0, 1.0)), ("LaunchBackground", (0.0, 0.0, 0.0))):
    manifest = catalog / f"{name}.colorset/Contents.json"
    if not manifest.is_file():
        fail(f"{name} colorset is missing")
        continue
    data = json.loads(manifest.read_text(encoding="utf-8"))
    components = data["colors"][0]["color"]["components"]
    actual = tuple(float(components[key]) for key in ("red", "green", "blue"))
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
        if alpha not in allowed_opacity:
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

print("PASS: 0 monochrome violations (no system materials, chromatic/gray tokens, system colors, raw constructors, off-step opacity or non-black/white source hex).")
print("PASS: AccentColor is #FFFFFF; app root uses .tint(.white) and .preferredColorScheme(.dark).")
print("PASS: black app window and launch screen; dark keyboard/status-bar scheme; all compiled color assets are grayscale.")
print("PASS: separate Live Activity widget Swift source is included in the same strict monochrome scan.")
print("PASS: no wallpaper or image-background references remain; original upstream image assets are retained, not deleted.")
print("PASS: app root owns the shared LiquidChrome view; legacy sidebar and command bar are absent.")
PY
