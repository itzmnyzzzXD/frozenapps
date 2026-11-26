#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import json, plistlib, re, sys
root = Path(sys.argv[1])
app = root / "Vendor/SideInstaller/ios-app"
integration = root / "InstallerIntegration"
if not (app / "SideInstallerApp.swift").is_file():
    raise SystemExit("FAIL: generated app source is missing")
if (app / "Assets.xcassets/SideStickBackground.imageset").exists():
    raise SystemExit("FAIL: legacy JPEG wallpaper remains packaged")
for path in (integration / "FrozenWorkspaceChrome.swift", app / "RootView.swift"):
    source = path.read_text(encoding="utf-8")
    if "FrozenWorkspaceRail" in source or "FrozenWorkspaceCommandBar" in source:
        raise SystemExit(f"FAIL: old sidebar or command bar remains in {path}")
pattern = re.compile(r"(?<![A-Za-z0-9_])\.(?:blue|purple|red|green|orange|pink|cyan|yellow|indigo|teal|mint|brown)(?![A-Za-z0-9_])")
for path in list(app.rglob("*.swift")) + list(integration.rglob("*.swift")):
    source = re.sub(r"/\*.*?\*/", "", path.read_text(encoding="utf-8", errors="replace"), flags=re.S)
    for number, line in enumerate(source.splitlines(), 1):
        code = re.sub(r"//.*$", "", line)
        if pattern.search(code):
            raise SystemExit(f"FAIL: colored SwiftUI token at {path}:{number}")
        if re.search(r"Color\(\s*red:|UIColor\(\s*(?:red|displayP3Red):", code):
            raise SystemExit(f"FAIL: RGB color constructor at {path}:{number}")
root_app = (app / "SideInstallerApp.swift").read_text()
root_view = (app / "RootView.swift").read_text()
if "LiquidChromeBackground(interaction: liquidChromeInput)" not in root_app:
    raise SystemExit("FAIL: shared LiquidChrome renderer is not mounted")
if "FrozenLaunchWelcome" not in root_app:
    raise SystemExit("FAIL: launch text reveal is missing")
if "FrozenInstallProgressPopup()" not in root_view or "FrozenAnimatedOTPInput(" not in root_view:
    raise SystemExit("FAIL: real install popup or OTP is not wired")
if "FrozenAnimatedAccountReadiness(" not in (app / "AccountViews.swift").read_text():
    raise SystemExit("FAIL: animated login form is not bound to real fields")
if "FrozenInstallProgressStack()" not in (integration / "FrozenInstallProgressPopup.swift").read_text():
    raise SystemExit("FAIL: install progress stack is missing from stats card")
catalog = app / "Assets.xcassets"
for name, expected in (("AccentColor", (1.0,1.0,1.0)), ("LaunchBackground", (0.0,0.0,0.0))):
    data = json.loads((catalog / f"{name}.colorset/Contents.json").read_text())
    c = data["colors"][0]["color"]["components"]
    actual = tuple(float(c[k]) for k in ("red","green","blue"))
    if actual != expected:
        raise SystemExit(f"FAIL: {name} should be {expected}; found {actual}")
info = plistlib.loads((app / "Info.plist").read_bytes())
if info.get("UIUserInterfaceStyle") != "Dark":
    raise SystemExit("FAIL: app's Info.plist is not forced dark")
print("PASS: black/white palette, LiquidChrome root, no wallpaper/sidebars/old command bar.")
print("PASS: animated login, OTP AutoFill/callback, install-only Stats/Progress Stack, launch Text Reveal.")
PY
