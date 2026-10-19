# FrozenApps release-readiness checklist

This checklist is the release gate for the SideInstaller-integrated FrozenApps build.

## Current state

- `v1.0.1` points to the `main` commit that predates the SideInstaller engine integration. Do not describe that release as engine-enabled.
- The engine integration is on `feature/on-device-installer-engine` and its GitHub Actions build completed successfully.
- CI validates compilation only. No physical iPad has been verified, and the branch has not produced a tested installable package.
- The current build workflow intentionally uploads diagnostics rather than an IPA. The upstream custom licence grants source distribution under conditions but does not clearly grant distribution of a compiled derivative. Obtain written permission from FrizzleM before publishing a compiled FrozenApps IPA.

## Release gates

- [ ] Confirm written permission for the intended binary distribution and use. Keep a record of the exact scope granted.
- [ ] Review the pinned upstream licence at `Vendor/SideInstaller/LICENSE.md` and keep the required notice and attribution with source distributions.
- [ ] Wait for the integration pull request to be reviewed and merged; do not retag `v1.0.1`.
- [ ] Confirm CI passes source preparation, Rust device/simulator builds, Xcode compilation, and bundle validation.
- [ ] Test on a physical iPad running iPadOS 27 with the documented self-pair workflow.
- [ ] If supporting iPadOS 17.4–26.7, verify the existing pairing-file flow; do not claim computer-free pairing for these versions without the required pairing file.
- [ ] Verify LocalDevVPN/local-network setup and permissions using a test Apple Account. Never use a shared account or send credentials/2FA codes in chat or issue reports.
- [ ] Exercise Apple authentication, two-factor callback, certificate and provisioning setup, IPA signing, installation, error recovery, and retry flows on hardware.
- [ ] Re-test after reboot and on a clean install. Confirm the app does not claim that Sign in with Apple alone enables developer signing.
- [ ] Confirm the privacy notice accurately discloses any third-party Anisette/provider network traffic and all locally stored account data.
- [ ] Only after the gates above pass, prepare a new versioned release asset and publish it with a reproducible source commit and SHA-256 checksum.

## What CI can and cannot prove

CI compiles the pinned Rust engine and iOS target and checks bundle metadata, the device architecture, and the Live Activity extension. It cannot prove Apple's servers will accept a particular account, that device pairing works, that provisioning succeeds, or that an IPA can be installed on a real device. Those checks require a physical-device test.
