# FrozenApps release-readiness checklist

## Current state

- The SideInstaller source integration and FrozenApps app integration are merged into `main`.
- CI **passed** for the earlier `v1.0.2` tag commit `eac167c4493046405278fa0a14315529e2622a3b` in [run 39234854061](https://github.com/itzmnyzzzXD/frozenapps/actions/runs/39234854061). It compiled the Rust pairing/signing engine and iOS app, then verified bundle metadata and arm64 architecture.
- The latest workflow change adds unsigned IPA packaging, archive-structure checks, a SHA-256 checksum, release-event triggers for `published` and `edited`, and an opt-in release upload.
- The current `v1.0.2` release has no attached assets. The older `v1.0.1` IPA predates engine integration and is not the current build.
- The build output is unsigned. It is not a ready-to-install signed app.
- Public release upload requires the repository variable `FROZENAPPS_BINARY_RELEASE_ALLOWED=true`, which must only be set after written permission for binary distribution has been obtained. Once the permission and variable are in place, edit/save the existing release to trigger the release workflow again.
- No physical iPad has yet been verified. Pairing, Apple authentication, provisioning, signing, and app installation still need hardware tests.
- The full upstream custom licence is kept at [LICENSES/SideInstaller-LICENSE.md](LICENSES/SideInstaller-LICENSE.md), as well as in the upstream source repository/submodule.

## Release gates

- [ ] Obtain and retain written permission for the intended binary distribution from the upstream copyright holder; set `FROZENAPPS_BINARY_RELEASE_ALLOWED=true` only after that.
- [x] Preserve the upstream licence and copyright text in this source repository and retain attribution.
- [x] Confirm that the tagged source commit compiles and passes bundle validation.
- [x] Add workflow logic to package the app into an unsigned IPA, verify the ZIP structure, and calculate its SHA-256 checksum.
- [x] Add release-published and release-edited triggers, and configure the release upload to use the existing tag.
- [ ] Confirm the updated workflow succeeds and inspect the generated IPA artifact.
- [ ] After authorization, edit/save the `v1.0.2` release to trigger the workflow and verify that both the IPA and checksum appear in its asset list.
- [ ] Test on a physical iPad running iPadOS 27 using the documented self-pair workflow.
- [ ] If supporting iPadOS 17.4–26.7, verify the existing pairing-file flow; do not claim computer-free pairing for these versions without the required pairing file.
- [ ] Verify LocalDevVPN/local-network setup and permissions using a test Apple Account.
- [ ] Exercise two-factor callbacks, certificate and provisioning setup, custom IPA signing, installation, failure recovery, and retry flows on hardware.
- [ ] Re-test after reboot and clean install. Confirm the app doesn't imply that Sign in with Apple alone enables developer signing.
- [ ] Confirm the privacy notice accurately discloses Keychain storage and all authentication-provider/network traffic.
- [ ] Publish the binary only after authorization and device checks; include the SHA-256 checksum and document the source commit.

## What CI can and cannot prove

CI can prove that the source compiles, the app bundle contains expected metadata and architecture, and the unsigned IPA archive has the expected app path. It cannot prove Apple will accept an account, pairing succeeds on a given iPadOS version, provisioning succeeds, or the signed app installs and launches. Those checks require a physical device and valid credentials that must never be included in CI logs.
