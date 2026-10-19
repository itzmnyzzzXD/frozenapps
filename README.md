# FrozenApps

FrozenApps is an iPhone/iPad-first IPA signing and installation app project built around the pinned [SideInstaller by FrizzleM](https://github.com/FrizzleM/SideInstaller) engine. Its goal is to pair a supported device, authenticate for signing, provision and sign an IPA, install it, and keep a local library of IPA files—all from the device where the required iOS workflow supports it.

## Status and release notes

The engine integration and FrozenApps branding are merged into `main`. GitHub Actions compiled the native Rust pairing/signing engine and iOS app for the `v1.0.2` tag, and passed bundle checks for the app identifier, display name, version/build, minimum OS, Live Activity extension, and arm64 executable/native library.

**The `v1.0.2` GitHub Release currently has no attached assets.** The older `v1.0.1` release has an IPA asset, but it predates the engine integration and is not the current engine-enabled build. The repository's `latest_version.txt` remains `1.0.1` until a valid, downloadable release is published.

The build workflow now packages the compiled app as `FrozenApps-unsigned.ipa`, checks the archive structure, calculates a SHA-256 checksum, and stores the output as a GitHub Actions artifact. Uploading the IPA to a public Release is intentionally gated by the repository variable `FROZENAPPS_BINARY_RELEASE_ALLOWED=true`. Set that variable only after written permission for binary distribution has been obtained from the upstream copyright holder. Then edit and save the existing release to trigger the release workflow again. The workflow responds to release publication and edits, so an already-created tag/release can be processed without moving the tag.

**The generated IPA is unsigned.** It is not a ready-to-install signed app, and CI success is not proof that pairing, Apple authentication, provisioning, signing, or installation works on a physical iPad. Physical-device testing remains required; see [release readiness](RELEASE_READINESS.md).

## What is included

- **Signer:** the engine's on-device pairing, Apple developer-session authentication and two-factor callbacks, certificate/App ID/provisioning setup, IPA signing, and installation workflow.
- **Custom IPA workflow:** choose a local IPA or direct download link from the Signer screen, import a custom IPA from Files, load it into Signer, and run the engine's install/sign steps.
- **Files library:** keep multiple IPA packages separately from the signer's working copy, validate that imports are ZIP packages with readable app metadata, search and sort local packages by name, recency, or size, inspect bundle ID/version/size/modification date, calculate and copy a SHA-256 checksum, load a package into Signer, and delete files with confirmation. Multi-file imports report which package is being checked.
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

GitHub Actions builds and validates the app, packages an unsigned IPA, and stores the build output as a workflow artifact. It uploads the IPA to a public release only when the binary-release authorization variable described above is enabled.

## Attribution and licence

**SideInstaller by FrizzleM** — https://github.com/FrizzleM/SideInstaller

The upstream source is pinned as a Git submodule. The full upstream custom licence is also kept at [LICENSES/SideInstaller-LICENSE.md](LICENSES/SideInstaller-LICENSE.md) so it is visible in source archives. Source distribution must retain the upstream copyright and licence notices and comply with the licence conditions. Obtain explicit written authorization before distributing compiled derivatives or using the engine commercially.
