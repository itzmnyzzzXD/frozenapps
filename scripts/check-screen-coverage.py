#!/usr/bin/env python3
"""Structural acceptance checks for the app's major native screens."""
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
INTEGRATION = ROOT / "InstallerIntegration"
APP = ROOT / "Vendor" / "SideInstaller" / "ios-app"
failures = []

def read(path):
    file = path if path.is_absolute() else ROOT / path
    if not file.is_file():
        failures.append(f"missing source file: {file.relative_to(ROOT)}")
        return ""
    return file.read_text(encoding="utf-8", errors="replace")

def require(source, token, context):
    if token not in source:
        failures.append(f"{context}: missing {token!r}")

components = {
    "AppIcon.swift": ["struct AppIcon: View", "symbolRenderingMode(.monochrome)"],
    "LiquidChromeBackground.swift": ["LiquidChromeParameters", "MTKView", "Reduce Motion"],
    "FrozenChromeComponents.swift": ["FrozenAnimatedAccountReadiness", "focusedField", "FrozenLaunchWelcome", "FrozenInstallProgressStack"],
    "FrozenAnimatedOTPInput.swift": ["textContentType(.oneTimeCode)", "frozenapps.verificationCode", "isWorking", "statusMessage"],
    "FrozenInstallProgressPopup.swift": ["engine.overallProgress", "engine.stepStates", "UIImage(named:"],
    "FrozenWorkspaceChrome.swift": ["FrozenWorkspaceDock", "minHeight: 46", "frozen-workspace-selection"],
    "FrozenHomePanel.swift": ["wifiConnected", "tunnelConnected"],
    "FrozenCatalogAndBatchViews.swift": ["FrozenCatalogSource", "loadRelease", "FrozenBatchActionsView"],
    "FrozenCertificateHealthView.swift": ["FrozenProfileReader.matches", "Expiry is not revocation"],
    "FrozenControlCenterView.swift": ["FrozenCenterToolCard", "NavigationLink", "engine.stepStates"],
    "FrozenDeviceCenterView.swift": ["NWPathMonitor", "NOT VERIFIED"],
    "FrozenFilesView.swift": ["FrozenLibraryStore.importIPA", "importProgress", "CryptoKit"],
    "FrozenJITView.swift": ["connectAndDiscover", "refreshApps", "eligible"],
    "FrozenNetworkView.swift": ["FrozenNetworkDiagnostics", "startDiscovery", "stopDiscovery"],
    "FrozenSignerInstallCatalogView.swift": ["FrozenSignerCatalogApp.all", "downloadAndImport"],
    "FrozenGlassComponents.swift": ["FrozenWorkspacePanel", "FrozenGlassSurfaceModifier"],
}
for name, tokens in components.items():
    source = read(INTEGRATION / name)
    for token in tokens:
        require(source, token, name)

workspace = read(INTEGRATION / "FrozenWorkspaceChrome.swift")
for destination in ('"signer"', '"center"', '"network"', '"tools"', '"files"', '"settings"'):
    require(workspace, f'id: {destination}', "six-destination workspace dock")
if workspace.count(".init(id:") != 6:
    failures.append("workspace dock must retain exactly six destinations")

account_patcher = read("scripts/apply-liquidchrome-redesign.py")
require(account_patcher, "focusedField: focus", "account form focus binding")
require(account_patcher, "statusMessage: prompt.lastError", "OTP error-state binding")
require(account_patcher, "engine.answerTwoFactor", "preserve original two-factor answer path")

root_source = read(APP / "SideInstallerApp.swift")
require(root_source, "LiquidChromeBackground(interaction: liquidChromeInput)", "shared app-root Metal renderer")
require(root_source, "FrozenLaunchWelcome", "cold-launch welcome reveal")
root_view = read(APP / "RootView.swift")
require(root_view, "FrozenInstallProgressPopup()", "install-only stats card")
require(root_view, "engine.isRunning", "install visibility tied to real engine state")
for forbidden in ("FrozenWorkspaceRail", "FrozenWorkspaceCommandBar"):
    if forbidden in root_view:
        failures.append(f"legacy navigation component remains: {forbidden}")

if failures:
    for failure in failures:
        print("FAIL: " + failure)
    raise SystemExit(f"FAIL: {len(failures)} screen coverage issue(s).")

print("PASS: 15 native UI components/screens have required structural and state bindings.")
print("PASS: account focus, OTP AutoFill/error/Engine callback, and real install stats/progress are wired.")
print("PASS: six dock destinations preserved; legacy rail and command bar are absent.")
print("NOTE: source checks do not replace physical-device visual or interaction testing.")
