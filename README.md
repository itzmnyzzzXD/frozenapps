# FrozenApps

FrozenApps is an iPhone/iPad-first app installer project. The intended workflow pairs a device, authenticates for signing, provisions and signs an IPA, installs it, and provides a local files library—only on supported iOS versions and after the necessary device setup.

## Release status

**The published `v1.0.1` release predates the SideInstaller engine integration.** The engine is currently developed on the `feature/on-device-installer-engine` branch and has passed a GitHub Actions source build. This is not yet a verified, installable release.

The integrated build intentionally does not publish an IPA from CI. The upstream custom licence does not clearly grant binary distribution of a compiled derivative; written permission from the upstream copyright holder is required before publishing a compiled FrozenApps build. See [release readiness](RELEASE_READINESS.md) for the remaining validation gates.

## Installer engine

FrozenApps integrates the source of [SideInstaller by FrizzleM](https://github.com/FrizzleM/SideInstaller) as a pinned Git submodule at `Vendor/SideInstaller`. The upstream engine implements device pairing, LocalDevVPN/tunnel communication, Apple developer-session authentication with a two-factor callback, certificate/App ID/provisioning setup, IPA signing, and installation.

FrozenApps adds green/white/blue branding, subtle animated white particles, an in-app privacy and terms notice, and three tabs: Signer, Settings, Files.

## Compatibility and requirements

The upstream engine's requirements are version-dependent. Its documented self-pair workflow targets iOS/iPadOS 27; iOS 17.4–26.7 requires an existing pairing file, and versions below 17.4 are listed as unsupported. Working Wi-Fi/local-network access, the required LocalDevVPN setup, account eligibility, and physical-device testing are still necessary. Developer Mode, when required, must be enabled by the device owner in Settings.

## Build validation

Build prerequisites on a Mac: Xcode 27, Rust (rustup), XcodeGen, Python 3, and Git.

```bash
git clone https://github.com/itzmnyzzzXD/frozenapps.git
cd frozenapps
git checkout feature/on-device-installer-engine
bash scripts/build-engine.sh
bash scripts/validate-build.sh
```

The local validation script expects a successful build at `build/DerivedData/Build/Products/Release-iphoneos/FrozenApps.app`. GitHub Actions performs the same bundle checks and uploads build diagnostics only, not the compiled application.

## Privacy

FrozenApps does not operate a FrozenApps-owned credential database. Apple Account credentials entered into the installer are handled by the upstream authentication flow and stored using iOS Keychain. Authentication is still networked: Apple receives authentication requests, and the selected Anisette provider may receive protocol data required to complete authentication. Local storage does not mean all network traffic stays on-device. Review the source and terms before entering credentials; never send passwords or verification codes to anyone.

## Attribution

**SideInstaller by FrizzleM** — https://github.com/FrizzleM/SideInstaller

FrozenApps is a separate project with its own branding and UI modifications. The pinned upstream source and licence are preserved as a Git submodule.
