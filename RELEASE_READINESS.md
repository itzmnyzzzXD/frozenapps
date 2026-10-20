# FrozenApps release-readiness checklist

## Current state

- The visual redesign is maintained in `scripts/apply-frozenapps-branding.py` and `InstallerIntegration/`; the 1.0.7 app catalog improvements are included directly in `InstallerIntegration/FrozenCatalogAndBatchViews.swift`.
- The full redesign covers the Signer screen, account setup and editor, five-tab navigation, custom tool glyphs, pairing-first onboarding, Local Network setup and percentage-focused install/download progress.
- The 1.0.7 release candidate uses marketing version `1.0.7` and CI build number `12` in `project.yml`. The published IPA is unsigned; a successful archive build does not prove on-device signing or installation.
- GitHub Actions builds the native engine and iOS app, validates app metadata/architecture, packages the unsigned IPA, and checks ZIP integrity plus app bundle/version metadata before release. Build logs and validation summaries can be uploaded normally. The IPA and checksum are kept out of release assets and workflow artifacts unless prior written authorization for binary redistribution is confirmed using the `SIDEINSTALLER_BINARY_REDISTRIBUTION_AUTHORIZED` repository variable.
- The app has not been physically tested as part of this source change. Pairing, Local Network permission, Apple authentication, two-factor callbacks, provisioning, signing, installation, and error recovery still require testing on an actual iPhone/iPad with a user-controlled account.
- Required upstream attribution and the full custom licence are retained in source documentation, the Terms screen, and Settings.

## Gates

- [x] Preserve licence text and required source attribution.
- [x] Keep branding patches in the reproducible build script rather than only in generated source.
- [ ] Verify branch build compiles the redesigned account views, tool glyphs, progress ring, and Local Network screen.
- [ ] Inspect the built unsigned IPA for app version/build, Local Network purpose text and Bonjour declarations.
- [ ] Test pairing on a device running a supported newer iPadOS version.
- [ ] For iOS/iPadOS 17.4–26.7, test importing an existing pairing file; do not claim computer-free pairing unless prerequisites are met.
- [ ] Verify LocalDevVPN, Local Network access, and required OS prompts.
- [ ] Test authentication, password handling in Keychain, two-factor callbacks, provisioning, IPA signing, install, retry and failure recovery on physical hardware.
- [ ] Test after reboot and clean install. Do not include credentials or verification codes in CI logs.
- [ ] Verify the published unsigned IPA/checksum matches the latest successful main build.

## CI limits

CI can prove compilation, expected bundle metadata/architecture, and IPA archive structure. It cannot prove Apple will accept a specific account, that pairing works on a particular iPadOS/device combination, or that a signed app installs and launches. Those checks require physical-device testing and a valid account.
