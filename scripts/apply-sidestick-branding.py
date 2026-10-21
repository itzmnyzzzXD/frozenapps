#!/usr/bin/env python3
"""Apply SideStick branding and the selected background after all UI source patches.

This is a presentation-only pass: it does not alter the layout, app bundle identifier,
authentication, Keychain service, pairing protocol, signing engine, or install callbacks.
"""
from pathlib import Path
import json
import plistlib
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "Vendor" / "SideInstaller"
APP = VENDOR / "ios-app"
INTEGRATION = ROOT / "InstallerIntegration"
SOURCE_BACKGROUND = ROOT / "IMG_2135.jpeg"
ASSETS = APP / "Assets.xcassets"
BACKGROUND_SET = ASSETS / "SideStickBackground.imageset"

if not (APP / "Info.plist").is_file():
    raise SystemExit("Generated app Info.plist is missing; prepare the pinned engine first.")
if not SOURCE_BACKGROUND.is_file():
    raise SystemExit("IMG_2135.jpeg is missing from the repository root.")
if not ASSETS.is_dir():
    raise SystemExit("The upstream app asset catalog is missing.")

# Add the supplied image to the same asset catalog consumed by the app target.
BACKGROUND_SET.mkdir(parents=True, exist_ok=True)
shutil.copyfile(SOURCE_BACKGROUND, BACKGROUND_SET / "IMG_2135.jpeg")
(BACKGROUND_SET / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "IMG_2135.jpeg", "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n", encoding="utf-8")

def rebrand_literal(match):
    literal = match.group(0)
    # Preserve URLs and the stable internal bundle/data namespace.
    if "://" in literal or "com.itzmnyzzz.frozenapps" in literal:
        return literal
    literal = literal.replace("FROZENAPPS", "SIDESTICK")
    literal = literal.replace("FrozenApps", "SideStick")
    literal = literal.replace("frozenapps", "sidestick")
    literal = literal.replace("Frozen Center", "SideStick Center")
    literal = literal.replace("Frozen Apps", "SideStick")
    return literal

# Replace branding inside quoted user-visible Swift text only; never rename types.
for folder in (APP, INTEGRATION):
    if not folder.exists():
        continue
    for swift_path in folder.rglob("*.swift"):
        source = swift_path.read_text(encoding="utf-8")
        branded = re.sub(r'"(?:\\.|[^"\\])*"', rebrand_literal, source)
        # Swap background implementation only, preserving every surrounding layout.
        branded = branded.replace("AppBackground()", "FrozenWorkspaceBackdrop()")
        if branded != source:
            swift_path.write_text(branded, encoding="utf-8")

# Stop animating the entire two-column Signer hierarchy on every engine status tick.
# Local button/sheet transitions remain; status and progress updates no longer animate
# every card and column width together.
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

# Only the display name changes. Keeping CFBundleIdentifier stable lets existing users
# upgrade without creating a second app-data / Keychain namespace.
info_path = APP / "Info.plist"
info = plistlib.loads(info_path.read_bytes())
info["CFBundleDisplayName"] = "SideStick"
info["CFBundleName"] = "SideStick"
info["NSLocalNetworkUsageDescription"] = (
    "SideStick uses the local network for device pairing, app installation, "
    "and optional discovery of nearby HTTP services."
)
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML, sort_keys=False))

activity_path = VENDOR / "ios-live-activity" / "Info.plist"
if activity_path.is_file():
    activity = plistlib.loads(activity_path.read_bytes())
    for key in ("CFBundleDisplayName", "CFBundleName"):
        if key in activity:
            activity[key] = "SideStick"
    activity_path.write_bytes(plistlib.dumps(activity, fmt=plistlib.FMT_XML, sort_keys=False))

print("Applied SideStick display branding, selected wallpaper and render optimizations.")
