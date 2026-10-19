# FrozenApps release-readiness checklist

## Current state

- The SideInstaller source integration and FrozenApps app integration are merged into `main`.
- CI compiled the Rust pairing/signing engine and iOS app successfully on the feature branch before the merge. A fresh main-branch build is running/required after later commits.
- CI now validates the app bundle, display name, version/build number, minimum OS, Live Activity extension, and arm64 engine library.
- The Files tab supports multiple stored IPA packages, archive and app-metadata validation, search, metadata inspection, a SHA-256 checksum, and loading a package into the engine's custom-IPA signing workflow.
- No physical iPad has yet been verified. Pairing, Apple authentication, provisioning, signing, and app installation still need hardware tests.
- The published `v1.0.1` release predates this integration. Do not treat it as the current engine-enabled app.
- The upstream custom licence does not clearly grant permission to publish a compiled derivative. Obtain written permission from FrizzleM before distributing a compiled FrozenApps IPA.

## Release gates

- [ ] Confirm written permission for the intended binary distribution and use. Keep a record of the exact scope granted.
- [ ] Preserve the pinned upstream `LICENSE.md`, copyright notice, and attribution when distributing source.
- [ ] Verify the latest main CI run completes successfully after all current changes.
- [ ] Test on a physical iPad running iPadOS 27 using the documented self-pair workflow.
- [ ] If supporting iPadOS 17.4–26.7, verify the existing pairing-file flow; do not claim computer-free pairing for these versions without the required pairing file.
- [ ] Verify LocalDevVPN/local-network setup and permissions using a test Apple Account.
- [ ] Exercise two-factor callbacks, certificate and provisioning setup, custom IPA signing, installation, failure recovery, and retry flows on hardware.
- [ ] Re-test after reboot and clean install. Confirm the app doesn't imply that Sign in with Apple alone enables developer signing.
- [ ] Confirm the privacy notice accurately discloses Keychain storage and all authentication-provider/network traffic.
- [ ] Only after the gates above pass, prepare a new versioned release, verify installation from that exact build, and publish the asset with a reproducible source commit and SHA-256 checksum.

## What CI can and cannot prove

CI can prove that the native code compiles and that the resulting app bundle contains expected metadata and architecture. It cannot prove Apple will accept an account, pairing succeeds on a given iPadOS version, provisioning succeeds, or the signed app installs and launches. Those checks require a physical device and valid credentials that must never be included in CI logs.
