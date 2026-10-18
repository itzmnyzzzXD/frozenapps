#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
git submodule update --init --recursive Vendor/SideInstaller

if ! command -v cargo >/dev/null 2>&1; then
  echo "Rust is required. Install rustup from https://rustup.rs and rerun this script." >&2
  exit 2
fi
if ! command -v xcodegen >/dev/null 2>&1; then
  echo "XcodeGen is required. Install it with: brew install xcodegen" >&2
  exit 2
fi

export DEVELOPER_DIR="${DEVELOPER_DIR:-$(xcode-select -p)}"
export IPHONEOS_DEPLOYMENT_TARGET=17.4
rustup target add aarch64-apple-ios aarch64-apple-ios-sim
python3 scripts/apply-frozenapps-branding.py
bash Vendor/SideInstaller/build-rust.sh
xcodegen generate
set -o pipefail
xcodebuild -project FrozenApps.xcodeproj -scheme FrozenApps \
  -configuration Release -sdk iphoneos \
  -derivedDataPath "$ROOT/build/DerivedData" \
  CODE_SIGNING_ALLOWED=NO CODE_SIGNING_REQUIRED=NO CODE_SIGN_IDENTITY="" \
  build | tee "$ROOT/build.log"

echo "Build validation complete. This script does not export or distribute a signed IPA."
