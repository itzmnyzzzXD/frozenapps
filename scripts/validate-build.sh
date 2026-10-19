#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PRODUCTS="$ROOT/build/DerivedData/Build/Products/Release-iphoneos"
APP="$PRODUCTS/FrozenApps.app"
ENGINE="$ROOT/Vendor/SideInstaller/SideInstallerFFI.xcframework"
SUMMARY="$ROOT/build-validation.txt"

fail() {
  echo "FAIL: $*" | tee -a "$SUMMARY" >&2
  exit 1
}

{
  echo "FrozenApps build validation"
  echo "Commit: ${GITHUB_SHA:-local}"
  echo "Date (UTC): $(date -u +%Y-%m-%dT%H:%M:%SZ)"
  echo
} > "$SUMMARY"

{
  test -d "$APP" || fail "FrozenApps.app was not produced at $APP"
  test -x "$APP/FrozenApps" || fail "App executable is missing or not executable"

  APP_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$APP/Info.plist")
  APP_VERSION=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$APP/Info.plist")
  APP_BUILD=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleVersion' "$APP/Info.plist")
  MIN_OS=$(/usr/libexec/PlistBuddy -c 'Print :MinimumOSVersion' "$APP/Info.plist")

  [[ "$APP_ID" == "com.itzmnyzzz.frozenapps" ]] || fail "Unexpected app bundle identifier: $APP_ID"
  [[ "$APP_VERSION" == "1.0.2" ]] || fail "Expected candidate version 1.0.2, got $APP_VERSION"
  [[ "$APP_BUILD" == "3" ]] || fail "Expected build number 3, got $APP_BUILD"
  [[ "$MIN_OS" == "17.4" ]] || fail "Expected minimum iOS/iPadOS 17.4, got $MIN_OS"

  EXTENSION="$APP/PlugIns/FrozenAppsLiveActivity.appex"
  test -d "$EXTENSION" || fail "Live Activity extension is missing"
  EXTENSION_ID=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$EXTENSION/Info.plist")
  [[ "$EXTENSION_ID" == "com.itzmnyzzz.frozenapps.LiveActivity" ]] || fail "Unexpected Live Activity bundle identifier: $EXTENSION_ID"

  DEVICE_LIB="$ENGINE/ios-arm64/libsideinstaller_ffi.a"
  test -f "$DEVICE_LIB" || fail "The iOS-device SideInstaller FFI static library is missing"
  LIB_ARCHS=$(lipo -archs "$DEVICE_LIB")
  [[ " $LIB_ARCHS " == *" arm64 "* ]] || fail "The device FFI library does not contain arm64: $LIB_ARCHS"

  APP_ARCHS=$(lipo -archs "$APP/FrozenApps")
  [[ " $APP_ARCHS " == *" arm64 "* ]] || fail "The app executable does not contain arm64: $APP_ARCHS"

  APP_SIZE=$(du -sh "$APP" | awk '{print $1}')
  LIB_SIZE=$(du -sh "$DEVICE_LIB" | awk '{print $1}')
  echo "PASS: app bundle exists"
  echo "PASS: bundle identifier: $APP_ID"
  echo "PASS: candidate version/build: $APP_VERSION ($APP_BUILD)"
  echo "PASS: minimum OS: $MIN_OS"
  echo "PASS: Live Activity extension: $EXTENSION_ID"
  echo "PASS: SideInstaller device library architecture: $LIB_ARCHS"
  echo "PASS: app executable architecture: $APP_ARCHS"
  echo "App bundle size: $APP_SIZE"
  echo "Device FFI library size: $LIB_SIZE"
  echo
  echo "LIMITATION: this validates compilation and bundle structure only. It does not verify pairing, Apple authentication, signing, installation, or compatibility on a physical iPad."
} | tee -a "$SUMMARY"

echo "Build validation passed."
