# FrozenApps release-readiness checklist

## Current state

- The SideInstaller source integration and FrozenApps app integration are merged into `main`.
- CI **passed** for tag commit `eac167c4493046405278fa0a14315529e2622a3b` in [run 39234854061](https://github.com/itzmnyzzzXD/frozenapps/actions/runs/39234854061). It compiled the Rust pairing/signing engine and iOS app, then verified the bundle ID, app display name, version/build, minimum OS, Live Activity extension, and arm64 app/library architecture.
- The validated app reports version/build `1.0.2 (3)` and minimum iOS/iPadOS 17.4. The CI build was **unsigned** and its workflow uploads diagnostics only; it does not produce a distributable IPA.
- The `v1.0.2` GitHub Release entry exists, but the release API currently reports **zero attached assets**. The tag points at the successful CI commit above.
- The older `v1.0.1` release does have an IPA asset, but it predates the engine integration and must not be presented as the current engine-enabled app.
- `latest_version.txt` remains `1.0.1` until there is a legitimate downloadable release asset.
- The Files tab supports multiple stored IPA packages, archive and app-metadata validation, search and sorting, metadata inspection, a SHA-256 checksum, and loading a package into the engine's custom-IPA signing workflow.
- No physical iPad has yet been verified. Pairing, Apple authentication, provisioning, signing, and app installation still need hardware tests.
- The full upstream custom licence is also kept at [LICENSES/SideInstaller-LICENSE.md](LICENSES/SideInstaller-LICENSE.md), in addition to its source repository/submodule.

## Release gates

- [ ] Confirm written permission for the intended binary distribution and use from the upstream copyright holder. Keep a record of the exact scope granted.
- [x] Preserve the upstream license and copyright text in this source repository and retain the attribution.
- [x] Verify that the tag commit's CI build and bundle validation pass. Repeat after any source-code change.
- [ ] Test on a physical iPad running iPadOS 27 using the documented self-pair workflow.
- [ ] If supporting iPadOS 17.4–26.7, verify the existing pairing-file flow; do not claim computer-free pairing for these versions without the required pairing file.
- [ ] Verify LocalDevVPN/local-network setup and permissions using a test Apple Account.
- [ ] Exercise two-factor callbacks, certificate and provisioning setup, custom IPA signing, installation, failure recovery, and retry flows on hardware.
- [ ] Re-test after reboot and clean install. Confirm the app doesn't imply that Sign in with Apple alone enables developer signing.
- [ ] Confirm the privacy notice accurately discloses Keychain storage and all authentication-provider/network traffic.
- [ ] Only after the gates above pass, create or update the release with an asset built from a documented source commit; verify installation from that exact build and publish its SHA-256 checksum.

## What CI can and cannot prove

CI can prove that the source compiles and the resulting app bundle contains expected metadata and architecture. It cannot prove Apple will accept an account, pairing succeeds on a given iPadOS version, provisioning succeeds, or the signed app installs and launches. Those checks require a physical device and valid credentials that must never be included in CI logs.
