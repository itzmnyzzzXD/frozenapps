#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
SUBMODULE="Vendor/SideInstaller"
UPSTREAM="https://github.com/FrizzleM/SideInstaller.git"

PIN="$(git ls-tree HEAD "$SUBMODULE" | awk '{print $3}')"
if [ -z "$PIN" ]; then
  echo "No pinned SideInstaller commit found in the FrozenApps tree." >&2
  exit 2
fi

# The upstream Git tree also contains large build caches and prebuilt IPA
# files. Clone without checking files out, enable sparse checkout first, and
# only materialize source directories needed to compile the engine.
if [ ! -e "$SUBMODULE/.git" ]; then
  if [ -d "$SUBMODULE" ]; then
    if [ -n "$(find "$SUBMODULE" -mindepth 1 -maxdepth 1 -print -quit)" ]; then
      echo "$SUBMODULE exists but is not a Git checkout. Remove it and retry." >&2
      exit 2
    fi
    rmdir "$SUBMODULE"
  fi
  git clone --filter=blob:none --no-checkout --depth 1 --branch main "$UPSTREAM" "$SUBMODULE"
fi

git -C "$SUBMODULE" sparse-checkout init --cone
git -C "$SUBMODULE" sparse-checkout set ios-app ios-live-activity rust-core
if ! git -C "$SUBMODULE" cat-file -e "$PIN^{commit}" 2>/dev/null; then
  git -C "$SUBMODULE" fetch --filter=blob:none --depth 1 origin "$PIN"
fi
git -C "$SUBMODULE" checkout --detach --force "$PIN"

test -f "$SUBMODULE/ios-app/Engine.swift"
test -f "$SUBMODULE/rust-core/Cargo.toml"
test -f "$SUBMODULE/build-rust.sh"
echo "Prepared pinned SideInstaller source at $PIN using sparse checkout."
