# FrozenApps

FrozenApps is an iPhone and iPad-first sideloading project with a green, white, and blue interface, subtle animated particles, and three main areas: **Signer**, **Settings**, and **Files**.

## Current app features

- First-launch terms screen; acceptance is saved locally.
- Native Sign in with Apple UI. This signs the user into an app identity flow; it is **not** the Apple Account developer sign-in used by an IPA signing engine.
- Local IPA import from Files, local file listing, and deletion.
- Developer Mode guidance that explains the steps the user must take on the device.
- Optional local notifications and a test alert.
- No FrozenApps database or server upload is implemented in this version.

## Important: the sideloading engine is not complete yet

The current source is an app interface and local file library; it does **not** yet do the complete SideInstaller-style workflow. In particular, it does not perform on-device Apple developer authentication, Anisette, device pairing, provisioning-profile/certificate creation, IPA signing, device installation, or pairing-file handoff to SideStore.

Those steps require a real on-device engine—not just an Apple sign-in button or a Developer Mode help screen. We must not show a successful signing/installation status until the underlying operation actually succeeds.

## SideInstaller research

The upstream [SideInstaller repository](https://github.com/FrizzleM/SideInstaller) documents an on-device pipeline that combines remote pairing, a LocalDevVPN-style network tunnel, Apple developer-account authentication, IPA signing, and installation. Its documented compatibility is version-sensitive: iOS 27+ can pair on-device, iOS 17.4–26.7 requires an existing pairing file, and versions below iOS 17.4 are listed as unsupported. These are SideInstaller's stated compatibility notes, not a claim that FrozenApps supports those workflows today.

SideInstaller's source licence is custom and non-commercial. It requires attribution for incorporated code and restricts commercial use and distribution of its compiled releases/derivatives. FrozenApps should not copy the upstream engine into a public IPA build without confirming that the planned use and distribution are permitted. See the upstream [licence](https://github.com/FrizzleM/SideInstaller/blob/main/LICENSE.md) before reusing code.

## Build an unsigned IPA

The GitHub Actions workflow builds an **unsigned** iOS app and packages it as `FrozenApps-unsigned.ipa`.

1. Open this repository's **Actions** tab.
2. Select **Build FrozenApps IPA**.
3. Open the latest completed successful run.
4. Download the **FrozenApps-iOS-build** artifact and extract the ZIP.

The output is a build artifact, not a ready-to-install signed app. It needs a supported signing method before ordinary installation on iOS. This repository does not contain signing certificates or provisioning profiles.

## Privacy

Preferences, terms acceptance, Apple sign-in profile fields, and imported IPA files are kept in app-local storage in the current version. This version does not send those fields or files to a FrozenApps database. The native Sign in with Apple flow does not expose the Apple Account password to FrozenApps. No two-factor verification codes are requested by the current implementation.

Local-only storage is a technical design choice, not a guarantee of legal immunity. The app's terms should describe actual behavior accurately and should not claim that a privacy policy prevents every possible legal claim.

## Project

- Bundle identifier: `com.itzmnyzzz.frozenapps`
- Minimum iOS version: `16.0`
- UI: SwiftUI
