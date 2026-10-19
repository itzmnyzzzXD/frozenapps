# FrozenApps

FrozenApps is an iPhone/iPad-first IPA signing and installation app project built around the pinned [SideInstaller by FrizzleM](https://github.com/FrizzleM/SideInstaller) engine. Its goal is to pair a supported device, authenticate for signing, provision and sign an IPA, install it, and keep a local library of IPA files—all from the device where the required iOS workflow supports it.

## Status

The engine integration and FrozenApps branding are now merged into `main`. GitHub Actions compiles the native Rust pairing/signing engine and the iOS app, then verifies the app bundle, target OS, native arm64 library, and Live Activity extension.

**This is a source-build milestone, not yet a tested public IPA release.** The currently published `v1.0.1` release predates the engine integration. CI does not publish an IPA because the upstream custom licence does not clearly grant permission to distribute a compiled derivative. Written permission from the upstream copyright holder is required before publishing a compiled FrozenApps build. Physical-iPad pairing, Apple authentication, provisioning, signing, and installation still need device testing. See [release readiness](RELEASE_READINESS.md).

## What is included

- **Signer:** the engine's on-device pairing, Apple developer-session authentication and two-factor callbacks, certificate/App ID/provisioning setup, IPA signing, and installation workflow.
- **Custom IPA workflow:** choose a local IPA or direct download link from the Signer screen, import a custom IPA from Files, load it into Signer, and run the engine's install/sign steps.
- **Files library:** keep multiple IPA packages separately from the signer's working copy, validate that imports are ZIP packages with readable app metadata, search local packages, inspect bundle ID/version/size/modification date, calculate and copy a SHA-256 checksum, load a package into Signer, and delete files with confirmation.
- **Settings:** account/session settings and the upstream engine's diagnostics/logs, plus an in-app privacy and licence notice.
- **Branding:** FrozenApps identity, green/white/blue accents, subtle animated particles, and the Signer / Settings / Files tabs.

## iPad compatibility

The upstream engine documents device self-pairing for iOS/iPadOS 27. On iOS/iPadOS 17.4–26.7, an existing pairing file is required; the upstream documentation says generating that pairing file requires a computer. Versions below 17.4 are listed as unsupported. Wi-Fi/local-network access, the required LocalDevVPN setup, eligible Apple Account access, and a user-approved Developer Mode workflow may also be necessary.

That means "computer-free" is not a promise for every iPadOS version. Check [the upstream requirements](https://github.com/FrizzleM/SideInstaller#requirements) before attempting setup.

## Use the custom IPA signer

1. Open FrozenApps and review the in-app privacy and terms notice.
2. Open **Files** and import one or more `.ipa` files. The app checks the archive and its main app metadata before saving each package.
3. Tap the information icon to review the app name, bundle ID, version, file size, modified date, and SHA-256 checksum. The checksum helps compare the file to a trusted source; it does not prove that an app is safe.
4. Tap **Load into Signer** on the IPA you want to work with. This creates a separate custom-IPA working copy; the saved library copy stays intact.
5. In **Signer**, select the custom IPA option and follow the engine's device pairing, authentication, two-factor, provisioning, signing, and installation steps. Read any errors carefully; importing an IPA alone does not sign or install it.

Only install apps and files you are authorized to use. Never send your Apple Account password or verification code to anyone in chat or issue reports. Credentials are handled by the upstream auth flow and stored using iOS Keychain, but authentication still makes network requests to Apple and may involve the configured Anisette provider. Local storage is not the same as entirely local authentication.

## Build validation

Build prerequisites on a Mac: Xcode 27, Rust (rustup), XcodeGen, Python 3, and Git.

```bash
git clone https://github.com/itzmnyzzzXD/frozenapps.git
cd frozenapps
git submodule update --init --recursive
bash scripts/build-engine.sh
bash scripts/validate-build.sh
```

GitHub Actions runs the same source build and bundle validation and uploads diagnostic logs only. It does not publish the compiled app.

## Attribution and licence

**SideInstaller by FrizzleM** — https://github.com/FrizzleM/SideInstaller

The upstream source is pinned as a Git submodule and its original custom licence is preserved. FrozenApps changes the UI, branding, local file-library experience, and app integration. Source distribution must retain the upstream notice and comply with its non-commercial conditions. Obtain explicit written authorization before distributing compiled derivatives or using the engine commercially.
