#!/usr/bin/env bash
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUTPUT="/tmp/FrozenApps-LiquidChrome.air"
cd "$ROOT"
xcrun --sdk iphoneos metal -c InstallerIntegration/SideStickLiquidMetal.metal -o "$OUTPUT"
test -s "$OUTPUT"
echo "PASS: LiquidChrome Metal shader compiled."
