# FrozenApps

FrozenApps is an iPhone/iPad-first signing and installation workspace. It brings device pairing, Apple developer authentication, provisioning, IPA signing, app installation, local network diagnostics, and a personal IPA library into one native SwiftUI app.

## Current build

The v1.0.3 redesign uses a custom violet-and-ice-cyan identity, five purpose-built tabs, redesigned Apple Account setup/edit screens, refreshed utility icons, a pairing-first onboarding path, and a more visible live install-progress ring with percentages. Downloading a custom IPA from a link also shows a numeric percentage when the server reports transfer progress.

The UI changes are applied by \`scripts/apply-frozenapps-branding.py\` to the pinned engine checkout during every build. That keeps the customised screens reproducible rather than leaving edits in a generated directory that disappears on the next build. The existing pairing, Apple authentication, two-factor, provisioning, signing, and installation callbacks are retained.

## What is included

- **Signer:** on-device pairing, Apple developer-session authentication and two-factor callbacks, certificate/App ID/provisioning setup, IPA signing, and installation.
- **Pairing and network:** Local Network diagnostics, active route and Wi-Fi status, local IPv4 display/copy, and opt-in Bonjour discovery. The app does not bypass iOS privacy prompts or replace required pairing/tunnel setup.
- **Custom IPA workflow:** import a local IPA or fetch one from a direct download link, view transfer progress, load a package into Signer, and run signing/install steps.
- **Files library:** store multiple IPA packages separately from the signer's working copy; validate ZIP structure and app metadata; search/sort by name, date, and size; view bundle ID, version and SHA-256; load, or delete with confirmation.
- **Tools and settings:** account/session management, pairing tools, certificates, entitlements, location tools, managed apps, language, tunnel settings, logs, privacy and licence information.
- **Branding:** new FrozenApps app mark and utility glyphs, violet/ice-cyan visual system, glass surfaces, custom onboarding and account editor, animated backdrop, and Signer / Network / Tools / Files / Settings tabs.

## Compatibility

The app targets iOS/iPadOS 17.4 and later, but the supported pairing method depends on OS version. Self-pairing is available only on supported newer versions. On iOS/iPadOS 17.4–26.7, an existing pairing file is required, and creating that pairing file may require a computer. LocalDevVPN, local-network access, eligible Apple Account access, Apple service availability, and user-approved Developer Mode may also be necessary.

"Computer-free" is not a promise for every version or device. Read [release readiness](RELEASE_READINESS.md) and the compatibility details maintained with the underlying engine before setup.

## Import a custom IPA

1. Open **Files** and import one or more \`.ipa\` files. FrozenApps checks the archive and main app metadata before saving the package.
2. Open the package details to check its app name, bundle ID, version, size, modified date, and SHA-256 checksum.
3. Tap **Load into Signer**. This creates a separate working copy; the library copy remains intact.
4. Open **Signer**, choose the imported IPA, and follow the pairing, authentication, two-factor, provisioning, signing, and installation steps.
5. Follow any device prompts. Importing an IPA alone does not sign or install it.

Only install apps and files you are authorised to use. Never send your Apple Account password or verification code to anyone in chat or issue reports. Saved passwords use iOS Keychain, but Apple authentication still makes network requests and may use the selected authentication provider. Local storage is not the same as entirely local authentication.

## Build and validate

Build prerequisites on a Mac: Xcode 27, Rust (rustup), XcodeGen, Python 3, and Git.

\`\`\`bash
git clone https://github.com/itzmnyzzzXD/frozenapps.git
cd frozenapps
git submodule update --init --recursive
bash scripts/build-engine.sh
bash scripts/validate-build.sh
\`\`\`

GitHub Actions compiles the app and native engine, validates the app bundle and architecture, packages \`FrozenApps-unsigned.ipa\`, and calculates a SHA-256 checksum. The generated IPA is **unsigned**; it is not ready to install as-is. CI compilation also cannot prove that Apple authentication, device pairing, provisioning, signing, or installation works on a physical iPad. Physical-device testing remains necessary.

## Attribution and licence

**Required upstream attribution:** SideInstaller by FrizzleM — https://github.com/FrizzleM/SideInstaller.

The upstream source is pinned as a Git submodule. The full upstream custom licence is kept at [LICENSES/SideInstaller-LICENSE.md](LICENSES/SideInstaller-LICENSE.md). Source distributions must retain the copyright and licence notices and clearly identify modifications. The upstream licence restricts redistribution of compiled derivatives and commercial use without written authorization; read it before redistributing an IPA.
