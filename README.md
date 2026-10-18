# FrozenApps

FrozenApps is an iPhone/iPad-first sideloading installer. The planned workflow pairs the device, authenticates for signing, provisions/signs an IPA, installs it, and offers a local files library—all from the device where the supported iOS version allows it.

## Installer engine

FrozenApps integrates the source of [SideInstaller by FrizzleM](https://github.com/FrizzleM/SideInstaller) as a pinned Git submodule at `Vendor/SideInstaller`. The upstream engine implements device pairing, LocalDevVPN/tunnel communication, Apple developer-session authentication with a two-factor callback, certificate/App ID/provisioning setup, IPA signing, and installation.

FrozenApps adds its own green/white/blue branding, subtle animated white particles, local terms notice, and three tabs: Signer, Settings, Files.

## Compatibility and requirements

The upstream engine's requirements are version-dependent. Its documented self-pair workflow targets iOS/iPadOS 27; iOS 17.4–26.7 requires an existing pairing file, and versions below 17.4 are listed as unsupported. A supported device, working Wi-Fi/local-network access, the required LocalDevVPN setup, account eligibility and physical-device testing are still necessary. Developer Mode, when required, must be enabled by the device owner in Settings.

## Build validation

Prerequisites on a Mac: Xcode 27, Rust (rustup), XcodeGen, and Git with submodule support.

```bash
git clone --recurse-submodules https://github.com/itzmnyzzzXD/frozenapps.git
cd frozenapps
bash scripts/build-engine.sh
```

GitHub Actions builds the Rust engine and iOS app and uploads the build log only. It does not publish an IPA because the upstream engine uses a custom licence with restrictions around redistribution and monetization. Obtain written permission from the upstream copyright holder before distributing a compiled derivative. The upstream licence is preserved in the submodule.

## Privacy

FrozenApps does not operate a FrozenApps-owned credential database. Apple Account credentials are stored on the device by the upstream code using Keychain and are used to authenticate with Apple. The selected Anisette provider may also receive protocol data required for authentication, so local storage does not mean all network traffic stays on-device. Review the source and terms before entering credentials.

## Attribution

**SideInstaller by FrizzleM** — https://github.com/FrizzleM/SideInstaller

FrozenApps is a separate project with its own branding and UI modifications. The pinned upstream source and licence are preserved as a Git submodule. No official SideInstaller IPA is copied or rehosted by this repository.
