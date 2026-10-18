#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SUBMODULE="Vendor/SideInstaller"

if [ ! -f .gitmodules ]; then
  echo "Missing .gitmodules; installer engine source cannot be fetched." >&2
  exit 2
fi
PIN="$(git ls-tree HEAD "$SUBMODULE" | awk '{print $3}')"
if [ -z "$PIN" ]; then
  echo "No pinned SideInstaller commit found in the FrozenApps tree." >&2
  exit 2
fi

# Use a shallow, blob-filtered submodule checkout and sparse checkout so the
# upstream repository's build caches and prebuilt IPA artifacts are not pulled.
git -c protocol.version=2 submodule update --init --depth 1 --filter=blob:none --no-checkout "$SUBMODULE"

git -C "$SUBMODULE" sparse-checkout init --cone
git -C "$SUBMODULE" sparse-checkout set ios-app ios-live-activity rust-core
git -C "$SUBMODULE" checkout --detach "$PIN"

test -f "$SUBMODULE/ios-app/Engine.swift"
test -f "$SUBMODULE/rust-core/Cargo.toml"
test -f "$SUBMODULE/build-rust.sh"
echo "Prepared pinned SideInstaller source at $PIN using sparse checkout."
