#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
python3 - "$ROOT" <<'PY'
from pathlib import Path
import json, plistlib, re, sys

root = Path(sys.argv[1])
app = root / "Vendor" / "SideInstaller" / "ios-app"
activity = root / "Vendor" / "SideInstaller" / "ios-live-activity"
integration = root / "InstallerIntegration"
theme = root / "SideStickTheme.swift"
violations = []
checked = 0

scan = [integration]
if app.is_dir():
    scan.extend([app, activity])
else:
    print("WARN: Vendor submodule unavailable; only checked app-owned integration sources.")

checks = [
    ("named chromatic color", re.compile(r"(?<![A-Za-z0-9_])\.(?:blue|purple|red|green|orange|pink|cyan|yellow|indigo|teal|mint|brown)(?![A-Za-z0-9_])")),
    ("semantic gray foreground", re.compile(r"\.(?:foregroundStyle|foregroundColor)\([^\n]*\.(?:secondary|tertiary)\b")),
    ("system gray", re.compile(r"\bColor\.gray\b|\bUIColor\.systemGray(?:[2-6])?\b|\bColor\s*\(\s*white:")),
    ("system UI color", re.compile(r"UIColor\.(?:system(?:Blue|Red|Green|Orange|Yellow|Purple|Pink|Teal|Cyan|Indigo|Mint|Brown)|secondarySystem|tertiarySystem|quaternarySystem|label\b|secondaryLabel\b|tertiaryLabel\b)")),
    ("system material", re.compile(r"\.(?:ultraThinMaterial|thinMaterial|regularMaterial|thickMaterial|bar)\b|\.glassEffect\(")),
    ("RGB color constructor", re.compile(r"\bColor\s*\(\s*(?:red:|hue:)|\bUIColor\s*\(\s*(?:red:|hue:)")),
    ("non-monochrome hex", re.compile(r"#([0-9A-Fa-f]{3,8})\b")),
]

def fail(path, line, label, value):
    try: name = path.relative_to(root)
    except ValueError: name = str(path)
    violations.append(f"{name}:{line}: {label}: {value.strip()}")

source_files=[]
for folder in scan:
    if folder.is_dir():
        source_files += list(folder.rglob("*.swift")) + list(folder.rglob("*.metal"))
if theme.is_file(): source_files.append(theme)

for path in sorted(set(source_files)):
    checked += 1
    for number, line in enumerate(path.read_text(encoding="utf-8",errors="replace").splitlines(),1):
        for label, pattern in checks:
            for match in pattern.finditer(line):
                if label == "non-monochrome hex" and match.group(1).upper() in {"000000","FFFFFF"}: continue
                fail(path,number,label,line)

catalog=app/"Assets.xcassets"
if catalog.is_dir():
    for manifest in catalog.rglob("*.colorset/Contents.json"):
        try: data=json.loads(manifest.read_text())
        except Exception as error:
            fail(manifest,1,"invalid colorset",str(error)); continue
        for item in data.get("colors",[]):
            components=item.get("color",{}).get("components",{})
            try: values=[float(components[k]) for k in ("red","green","blue")]
            except Exception:
                fail(manifest,1,"non-sRGB colorset",repr(components)); continue
            if not (all(x==0 for x in values) or all(x==1 for x in values)):
                fail(manifest,1,"chromatic/gray colorset",repr(components))
    for name in ("AccentColor","LaunchBackground"):
        if not (catalog/f"{name}.colorset"/"Contents.json").is_file():
            fail(catalog,1,"required colorset missing",name)

info=app/"Info.plist"
if info.is_file():
    try:
        plist=plistlib.loads(info.read_bytes())
        if plist.get("UIUserInterfaceStyle")!="Dark": fail(info,1,"UIUserInterfaceStyle must be Dark",repr(plist.get("UIUserInterfaceStyle")))
        if plist.get("UILaunchScreen",{}).get("UIColorName")!="LaunchBackground":
            fail(info,1,"launch screen must use LaunchBackground",repr(plist.get("UILaunchScreen")))
    except Exception as error: fail(info,1,"invalid Info.plist",str(error))

root_app=app/"SideInstallerApp.swift"
if root_app.is_file():
    content=root_app.read_text(errors="replace")
    for token in (".preferredColorScheme(.dark)",".tint(.white)","Color.black.ignoresSafeArea()"):
        if token not in content: fail(root_app,1,"missing root appearance invariant",token)

if violations:
    print(f"FAIL: {len(violations)} monochrome violation(s) in {checked} source files.")
    for item in violations: print(" - "+item)
    sys.exit(1)
print(f"PASS: {checked} Swift/Metal files scanned; zero monochrome leaks.")
if app.is_dir():
    print("PASS: AccentColor white; launch background black; app appearance forced dark.")
    print("PASS: root tint white; root window black; preferred color scheme dark.")
else:
    print("PARTIAL: generated Vendor source checks execute in CI after submodule checkout.")
PY
