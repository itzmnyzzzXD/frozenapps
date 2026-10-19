# FrozenApps release-readiness checklist

## Current state

- The pinned SideInstaller pairing/signing engine is retained; the FrozenApps UI and additional local files/network screens are maintained in this repository.
- The base engine build previously passed CI for the `v1.0.2` source commit `eac167c4493046405278fa0a14315529e2622a3b` in [run 39234854061](https://github.com/itzmnyzzzXD/frozenapps/actions/runs/39234854061).
- The UI redesign for version `1.0.3` is proposed in [pull request #2](https://github.com/itzmnyzzzXD/frozenapps/pull/2). The branch adds the five-tab UI, control-center home panel, violet/ice-cyan theme, updated app icon, and Local Network diagnostics/Bonjour discovery. The branch's build is version `1.0.3`, build 4.
- The release workflow packages an unsigned `FrozenApps-unsigned.ipa`, validates its archive structure, calculates a SHA-256 checksum, and attaches both files when a release is published/edited or a `v*` tag is pushed.
- The new UI has not yet been verified on a physical iPad. Pairing, local-network permission behavior, Apple authentication, provisioning, signing, installation, and failure recovery still require device testing.
- The full upstream custom licence is retained at [LICENSES/SideInstaller-LICENSE.md](LICENSES/SideInstaller-LICENSE.md) and in the pinned submodule. Read the licence and comply with its conditions when using or distributing derivatives.

## Release gates

- [x] Preserve the upstream licence and copyright text in this source repository and retain attribution.
- [x] Package the app into an unsigned IPA, verify the ZIP structure, and calculate the SHA-256 checksum.
- [x] Configure release-published and release-edited events to upload assets to the matching release tag.
- [ ] Merge the UI redesign only after the build workflow for the branch succeeds.
- [ ] Inspect the generated IPA and confirm the expected app version/build, Local Network description, Bonjour service declarations, and bundled Swift screens.
- [ ] Test on a physical iPad running iPadOS 27 using the documented self-pair workflow.
- [ ] If supporting iPadOS 17.4–26.7, verify the existing pairing-file flow; do not claim computer-free pairing for these versions without the required pairing file.
- [ ] Verify LocalDevVPN/local-network setup and permissions using a test Apple Account.
- [ ] Exercise two-factor callbacks, certificate and provisioning setup, custom IPA signing, installation, failure recovery, and retry flows on hardware.
- [ ] Re-test after reboot and clean install. Confirm the app doesn't imply that Sign in with Apple alone enables developer signing.
- [ ] Confirm the privacy notice accurately discloses Keychain storage and all authentication-provider/network traffic.
- [ ] Choose and publish the intended release tag after the updated source is built and tested, and include the SHA-256 checksum and source commit in release notes.

## What CI can and cannot prove

CI can prove that the source compiles, the app bundle contains expected metadata and architecture, and the unsigned IPA archive has the expected app path. It cannot prove Apple will accept an account, pairing succeeds on a given iPadOS version, provisioning succeeds, or the signed app installs and launches. Those checks require a physical device and valid credentials that must never be included in CI logs.
