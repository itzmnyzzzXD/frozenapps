# FrozenApps

A clean, dark SwiftUI iOS app shell with three tabs: **Signer**, **Settings**, and **Files**. Each tab is intentionally empty for now.

## Build

The GitHub Actions workflow builds an unsigned iOS app and packages it as `FrozenApps-unsigned.ipa`.

1. Open the repository's **Actions** tab.
2. Select **Build FrozenApps IPA**.
3. Choose **Run workflow** if no push has triggered a build.
4. Open the completed run and download the **FrozenApps-iOS-build** artifact.
5. Extract the downloaded artifact ZIP to find the IPA and build log.

## Important: signing

The generated IPA is **unsigned**. It is useful as a build artifact, but iOS will not install it normally until it is signed with a valid Apple development/distribution certificate and provisioning profile. This repository does not contain signing certificates or provisioning profiles.

Bundle identifier: `com.itzmnyzzz.frozenapps`
Minimum iOS version: 16.0