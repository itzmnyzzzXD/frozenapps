#!/usr/bin/env python3
"""Fail the clean build if app-owned SwiftUI screens bypass AppIcon."""
from pathlib import Path
import re

ROOT = Path(__file__).resolve().parents[1]
APP = ROOT / "Vendor" / "SideInstaller" / "ios-app"
INTEGRATION = ROOT / "InstallerIntegration"
patterns = [
    (re.compile(r"\bImage\s*\(\s*systemName\s*:"), "Image(systemName:)"),
    (re.compile(r"\bLabel\s*\([^)]*\bsystemImage\s*:", re.S), "Label(systemImage:)"),
    (re.compile(r"\bButton\s*\([^)]*\bsystemImage\s*:", re.S), "Button(systemImage:)"),
]
failures = []
for folder in (APP, INTEGRATION):
    for path in folder.rglob("*.swift"):
        if path.name == "AppIcon.swift":
            continue
        source = path.read_text(encoding="utf-8", errors="replace")
        for pattern, label in patterns:
            match = pattern.search(source)
            if match:
                line = source.count("\n", 0, match.start()) + 1
                failures.append(f"{label} remains at {path.relative_to(ROOT)}:{line}")
if failures:
    for failure in failures:
        print("FAIL: " + failure)
    raise SystemExit(f"FAIL: {len(failures)} direct system-icon use(s) remain.")
print("PASS: app-owned SwiftUI icon call sites use AppIcon.")
