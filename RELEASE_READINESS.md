# FrozenApps release-readiness checklist

## Current state

- The structural workspace redesign is reproducibly applied by `scripts/apply-workspace-redesign.py` and `scripts/apply-settings-redesign.py` after the branding patch; shared glass/navigation components and redesigned library/catalog layouts live in `InstallerIntegration/`.
- The redesign includes a responsive floating navigation rail, compact dock, command bar, two-column Signer workspace, filter-panel IPA Library and App Catalog, responsive Tools grid and card-based Settings. Account setup/onboarding and two-factor screens remain unchanged.
- FrozenApps 1.1.0 uses marketing version `1.1.0` and CI build number `15` in `project.yml`. The published IPA is unsigned; a successful archive build does not prove on-device signing or installation.
- GitHub Actions builds the native engine and iOS app, validates app metadata/architecture, packages the unsigned IPA and checksum, and checks ZIP integrity plus app bundle/version metadata before replacing the version release assets. The release process does not require a repository variable or manual true switch. The published package is unsigned and still needs a supported signing method before installation.
- The app has not been physically tested as part of this source change. Pairing, Local Network permission, Apple authentication, two-factor callbacks, provisioning, signing, installation, and error recovery still require testing on an actual iPhone/iPad with a user-controlled account.
- Required upstream attribution and the full custom licence are retained in source documentation, the Terms screen, and Settings.
- The release workflow does not require a repository variable or a manual `true` switch: a validated version-tag push or a `[publish-release]` commit on `main` attaches the unsigned IPA and SHA-256 checksum to the GitHub Release.

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
- [x] Keep release publication free of a required repository-variable toggle.

## CI limits

CI can prove compilation, expected bundle metadata/architecture, and IPA archive structure. It cannot prove Apple will accept a specific account, that pairing works on a particular iPadOS/device combination, or that a signed app installs and launches. Those checks require physical-device testing and a valid account.
