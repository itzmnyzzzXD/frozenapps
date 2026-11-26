#!/usr/bin/env python3
"""Apply OLED LiquidChrome and native integrations after pinned-engine UI patches."""
from pathlib import Path
import json
import plistlib
import re
import shutil

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Vendor" / "SideInstaller" / "ios-app"
INTEGRATION = ROOT / "InstallerIntegration"

def replace_once(path, old, new):
    source = path.read_text(encoding="utf-8")
    if new in source:
        return
    count = source.count(old)
    if count != 1:
        raise SystemExit(f"Expected one patch anchor in {path}: count={count}; {old[:96]!r}")
    path.write_text(source.replace(old, new, 1), encoding="utf-8")

def replace_section(path, start_marker, end_marker, transform):
    source = path.read_text(encoding="utf-8")
    start = source.find(start_marker)
    end = source.find(end_marker, start + len(start_marker)) if start >= 0 else -1
    if start < 0 or end < 0:
        raise SystemExit(f"Could not find patch section in {path}: {start_marker!r}")
    section = source[start:end]
    changed = transform(section)
    if changed != section:
        path.write_text(source[:start] + changed + source[end:], encoding="utf-8")

for name in ("SideInstallerApp.swift", "AccountViews.swift", "RootView.swift", "Theme.swift", "Info.plist"):
    if not (APP / name).is_file():
        raise SystemExit(f"Missing generated app input: {APP / name}")
for name in ("LiquidChromeBackground.swift", "SideStickLiquidMetal.metal",
             "FrozenAnimatedOTPInput.swift", "FrozenChromeComponents.swift",
             "FrozenInstallProgressPopup.swift", "FrozenWorkspaceChrome.swift",
             "FrozenGlassComponents.swift"):
    if not (INTEGRATION / name).is_file():
        raise SystemExit(f"Missing native integration source: {INTEGRATION / name}")

# Mount one Metal renderer behind the launch/onboarding, account and workspace screens.
app_path = APP / "SideInstallerApp.swift"
replace_once(app_path,
    '    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false',
    '''    @AppStorage("hasCompletedAccountSetup") private var hasCompletedAccountSetup = false
    @State private var showLaunchWelcome = true
    @State private var liquidChromeInput = LiquidChromeInteraction()''')
replace_once(app_path,
    '''            ZStack {
                if hasAcceptedTOS && hasCompletedAccountSetup {''',
    '''            GeometryReader { rootGeometry in
                ZStack {
                    LiquidChromeBackground(interaction: liquidChromeInput)
                        .ignoresSafeArea()
                        .allowsHitTesting(false)
                    if hasAcceptedTOS && hasCompletedAccountSetup {''')
replace_once(app_path,
    '''            }
            .animation(.smooth(duration: 0.5), value: hasAcceptedTOS)''',
    '''                    if showLaunchWelcome {
                        FrozenLaunchWelcome {
                            withAnimation(.easeOut(duration: 0.4)) {
                                showLaunchWelcome = false
                            }
                        }
                        .transition(.opacity)
                        .zIndex(2)
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 8)
                        .onChanged { value in
                            liquidChromeInput.updatePointer(value.location, in: rootGeometry.size, touching: true)
                        }
                        .onEnded { _ in liquidChromeInput.endPointer() }
                )
                .onContinuousHover { phase in
                    switch phase {
                    case .active(let location):
                        liquidChromeInput.updatePointer(location, in: rootGeometry.size, touching: false)
                    case .ended:
                        liquidChromeInput.endPointer()
                    }
                }
            }
            .tint(.white)
            .preferredColorScheme(.dark)
            .background(Color.black.ignoresSafeArea())
            .animation(.smooth(duration: 0.5), value: hasAcceptedTOS)''')

# Account form status is tied to the actual editable Apple ID/password values.
account_path = APP / "AccountViews.swift"
replace_section(account_path, "struct AccountSetupView: View {",
    "/// Which of the two credential fields has the keyboard.",
    lambda section: section.replace(
        '''            HStack(spacing: 11) {
                Image(systemName: "envelope")''',
        '''            FrozenAnimatedAccountReadiness(email: email, password: password)

            HStack(spacing: 11) {
                Image(systemName: "envelope")''', 1
    ) if "FrozenAnimatedAccountReadiness(" not in section else section)

# Keep the One-Time-Code autofill and engine.answerTwoFactor callback behind the animated slots.
root_path = APP / "RootView.swift"
replace_section(root_path, "struct TwoFactorSheet: View {", "// MARK: - Tools",
    lambda section: section.replace(
        r'''            TextField(L("6-digit code"), text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .font(.system(size: 26, weight: .bold, design: .rounded).monospacedDigit())
                .multilineTextAlignment(.center)
                .textFieldStyle(.plain)
                .focused($codeFocused)
                .disabled(pending != nil)
                .padding(.vertical, 12)
                .fieldBackground()
                .onChange(of: code) { _, typed in
                    let digits = String(typed.filter(\.isNumber).prefix(6))
                    if digits != typed { code = digits }
                }''',
        '''            FrozenOTPSecurityOrb()
                .frame(maxWidth: .infinity)
                .frame(height: 92)

            FrozenAnimatedOTPInput(
                code: $code,
                isFocused: $codeFocused,
                isDisabled: pending != nil
            )''', 1
    ) if "FrozenAnimatedOTPInput(" not in section else section)

# Remove the photo wallpaper from the generated asset catalog.
glass_source = (INTEGRATION / "FrozenGlassComponents.swift").read_text(encoding="utf-8")
if 'Image("SideStickBackground")' in glass_source:
    raise SystemExit("Legacy SideStickBackground image remains in app background source.")
shutil.rmtree(APP / "Assets.xcassets" / "SideStickBackground.imageset", ignore_errors=True)
shutil.rmtree(APP / "Assets.xcassets" / "SignalGreen.colorset", ignore_errors=True)

# Set shared theme tokens to grayscale.
theme_path = APP / "Theme.swift"
theme = theme_path.read_text(encoding="utf-8")
theme = re.sub(r"(?m)^(\s*static let accent = ).*$", r"\1Color.white", theme, count=1)
theme = re.sub(r"(?m)^(\s*static let accent2 = ).*$", r"\1Color.white", theme, count=1)
theme = re.sub(r"(?m)^(\s*static let glow = ).*$", r"\1Color.black", theme, count=1)
theme = re.sub(r"(?m)^(\s*static let violet = ).*$", r"\1Color.white", theme, count=1)
theme = re.sub(
    r"static var brand: LinearGradient \{.*?\n    \}",
    '''static var brand: LinearGradient {
        LinearGradient(colors: [.white.opacity(0.72), .white.opacity(0.24)],
                       startPoint: .topLeading, endPoint: .bottomTrailing)
    }''', theme, count=1, flags=re.S
)
theme_path.write_text(theme, encoding="utf-8")

def numeric(value):
    parts = [part.strip() for part in value.split("/")]
    return float(parts[0]) / float(parts[1]) if len(parts) == 2 else float(parts[0])

def snap(value):
    value = max(0.0, min(1.0, value))
    if value < 0.025:
        return 0.0
    levels = (0.06, 0.12, 0.24, 0.48, 0.72, 1.0)
    return min(levels, key=lambda level: abs(level - value))

def gray_color(red, green, blue, alpha=1.0):
    level = snap((0.2126 * red + 0.7152 * green + 0.0722 * blue) * alpha)
    if level == 0.0:
        return "Color.black"
    if level == 1.0:
        return "Color.white"
    return f"Color.white.opacity({level:.2f})"

def normalize_swift(source):
    num = r"(?:[0-9]+(?:\.[0-9]*)?|\.[0-9]+)(?:\s*/\s*[0-9]+)?"
    rgb = re.compile(
        r"Color\(\s*red:\s*(" + num + r"),\s*green:\s*(" + num
        + r"),\s*blue:\s*(" + num + r")(?:,\s*opacity:\s*(" + num + r"))?\s*\)"
    )
    def replace_rgb(match):
        values = [numeric(match.group(i)) for i in (1, 2, 3)]
        alpha = numeric(match.group(4)) if match.group(4) else 1.0
        return gray_color(*values, alpha)
    source = rgb.sub(replace_rgb, source)

    ui_rgb = re.compile(
        r"UIColor\(\s*(?:displayP3Red|red):\s*(" + num + r"),\s*green:\s*(" + num
        + r"),\s*blue:\s*(" + num + r"),\s*alpha:\s*(" + num + r")\s*\)"
    )
    def replace_ui(match):
        vals = [numeric(match.group(i)) for i in (1, 2, 3, 4)]
        result = gray_color(*vals)
        if result == "Color.black":
            return "UIColor.black"
        if result == "Color.white":
            return "UIColor.white"
        alpha = re.search(r"opacity\(([0-9.]+)\)", result).group(1)
        return f"UIColor.white.withAlphaComponent({alpha})"
    source = ui_rgb.sub(replace_ui, source)

    source = re.sub(
        r"(?<![A-Za-z0-9_])\.(?:blue|purple|red|green|orange|pink|cyan|yellow|indigo|teal|mint|brown)(?![A-Za-z0-9_])",
        ".white", source
    )
    source = re.sub(r"\bColor\.gray\b", "Color.white.opacity(0.48)", source)
    source = re.sub(r"\bUIColor\.gray\b", "UIColor.white.withAlphaComponent(0.48)", source)
    source = source.replace("Color.primary", "Color.white")
    source = source.replace("Color.secondary", "Color.white.opacity(0.48)")
    source = source.replace("Color.tertiary", "Color.white.opacity(0.24)")
    for token in ("systemBackground", "secondarySystemBackground", "tertiarySystemBackground",
                  "systemGroupedBackground", "secondarySystemGroupedBackground",
                  "tertiarySystemGroupedBackground", "groupTableViewBackground"):
        source = source.replace(f"Color(.{token})", "Color.black")
        source = source.replace(f"Color(uiColor: .{token})", "Color.black")
        source = source.replace(f"UIColor.{token}", "UIColor.black")
    for token in ("systemBlue", "systemRed", "systemGreen", "systemOrange", "systemYellow",
                  "systemPurple", "systemPink", "systemTeal", "systemCyan", "systemIndigo",
                  "systemMint", "systemBrown"):
        source = source.replace(f"Color(.{token})", "Color.white")
        source = source.replace(f"Color(uiColor: .{token})", "Color.white")
        source = source.replace(f"UIColor.{token}", "UIColor.white")
    for token in ("systemGray", "systemGray2", "systemGray3", "systemGray4", "systemGray5", "systemGray6"):
        source = source.replace(f"Color(.{token})", "Color.white.opacity(0.48)")
        source = source.replace(f"Color(uiColor: .{token})", "Color.white.opacity(0.48)")
        source = source.replace(f"UIColor.{token}", "UIColor.white.withAlphaComponent(0.48)")
    source = source.replace("Color(.label)", "Color.white")
    source = source.replace("Color(.secondaryLabel)", "Color.white.opacity(0.48)")
    source = source.replace("Color(.tertiaryLabel)", "Color.white.opacity(0.24)")
    source = source.replace("Color(.separator)", "Color.white.opacity(0.12)")
    source = source.replace("Color(.placeholderText)", "Color.white.opacity(0.48)")
    source = source.replace(".tint(Theme.accent)", ".tint(.white)")
    source = source.replace(".tint(Theme.accent2)", ".tint(.white)")
    source = source.replace(".preferredColorScheme(.light)", ".preferredColorScheme(.dark)")
    return source

for folder in (APP, INTEGRATION):
    for path in folder.rglob("*.swift"):
        original = path.read_text(encoding="utf-8")
        normalized = normalize_swift(original)
        if normalized != original:
            path.write_text(normalized, encoding="utf-8")

# Mount installation stats only while a real install is active.
root_source = root_path.read_text(encoding="utf-8")
if "FrozenWorkspaceRail" in root_source or "FrozenWorkspaceCommandBar" in root_source:
    raise SystemExit("Legacy sidebar/command bar reference remains in RootView.")
if "FrozenInstallProgressPopup()" not in root_source:
    anchor = "        .popupStack(entries, onBackdropTap: backdropTap) {"
    if root_source.count(anchor) != 1:
        raise SystemExit("Expected exactly one popup stack for install stats insertion.")
    overlay = '''        .overlay(alignment: .top) {
            Group {
                if engine.isRunning {
                    FrozenInstallProgressPopup()
                        .padding(.horizontal, 14)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .zIndex(30)
                }
            }
            .animation(.spring(response: 0.42, dampingFraction: 0.86), value: engine.isRunning)
        }
'''
    root_source = root_source.replace(anchor, overlay + anchor, 1)
root_source = root_source.replace(".tint(Theme.accent)", ".tint(.white)")
root_path.write_text(root_source, encoding="utf-8")

# Add explicit OLED white tint and black launch-screen colors.
assets = APP / "Assets.xcassets"
assets.mkdir(parents=True, exist_ok=True)
def write_color(name, value):
    directory = assets / f"{name}.colorset"
    directory.mkdir(parents=True, exist_ok=True)
    payload = {"colors": [{
        "color": {"color-space": "srgb", "components": {
            "red": value, "green": value, "blue": value, "alpha": "1.000"}},
        "idiom": "universal"}],
        "info": {"author": "xcode", "version": 1}}
    (directory / "Contents.json").write_text(json.dumps(payload, indent=2) + "\n", encoding="utf-8")

write_color("AccentColor", "1.000")
write_color("LaunchBackground", "0.000")
for manifest in assets.rglob("*.colorset/Contents.json"):
    data = json.loads(manifest.read_text(encoding="utf-8"))
    for item in data.get("colors", []):
        components = item.get("color", {}).get("components", {})
        try:
            channels = [float(components[key]) for key in ("red", "green", "blue")]
        except Exception:
            continue
        level = snap(0.2126 * channels[0] + 0.7152 * channels[1] + 0.0722 * channels[2])
        gray = f"{level:.3f}"
        components["red"] = components["green"] = components["blue"] = gray
        item["color"]["color-space"] = "srgb"
    manifest.write_text(json.dumps(data, indent=2) + "\n", encoding="utf-8")

project = (ROOT / "project.yml").read_text(encoding="utf-8")
version = re.search(r"(?m)^\s*MARKETING_VERSION:\s*['\"]?([^'\"\s]+)", project)
build = re.search(r"(?m)^\s*CURRENT_PROJECT_VERSION:\s*['\"]?([^'\"\s]+)", project)
if not version or not build:
    raise SystemExit("Could not read version/build from project.yml")
info_path = APP / "Info.plist"
info = plistlib.loads(info_path.read_bytes())
info["CFBundleDisplayName"] = "SideStick"
info["CFBundleName"] = "SideStick"
info["CFBundleShortVersionString"] = version.group(1)
info["CFBundleVersion"] = build.group(1)
info["UIUserInterfaceStyle"] = "Dark"
launch = info.get("UILaunchScreen", {})
launch["UIColorName"] = "LaunchBackground"
info["UILaunchScreen"] = launch
info_path.write_bytes(plistlib.dumps(info, fmt=plistlib.FMT_XML, sort_keys=False))

print("Applied OLED LiquidChrome, native account/OTP, install-only Stats/Progress Stack and launch Text Reveal.")
