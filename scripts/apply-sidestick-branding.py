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

ROOT = Path(__file__).resolve().parents[1]
VENDOR = ROOT / "Vendor" / "SideInstaller"
APP = VENDOR / "ios-app"
ACTIVITY = VENDOR / "ios-live-activity"
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

# Add the supplied image to the asset catalog used by the app target.
BACKGROUND_SET.mkdir(parents=True, exist_ok=True)
shutil.copyfile(SOURCE_BACKGROUND, BACKGROUND_SET / "IMG_2135.jpeg")
(BACKGROUND_SET / "Contents.json").write_text(json.dumps({
    "images": [{"filename": "IMG_2135.jpeg", "idiom": "universal", "scale": "1x"}],
    "info": {"author": "xcode", "version": 1}
}, indent=2) + "\n", encoding="utf-8")

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

print("Applied SideStick display branding, background and render optimizations.")
