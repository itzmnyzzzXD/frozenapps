# SideStick 1.2.2 — OLED LiquidChrome redesign

## Scope

This branch is based on the published 1.2.2 release and replaces its legacy presentation layer with native SwiftUI and Metal components.

- A monochrome LiquidChrome Metal renderer is mounted once at the app root behind Welcome, account setup, verification and every workspace page.
- The previous IMG_2135.jpeg wallpaper is no longer added to the asset catalog or referenced by the workspace backdrop.
- The iPad vertical rail and previous command bar are removed. One floating horizontal dock is used on both iPhone and iPad.
- Animated login-form feedback follows the actual Apple ID and password fields.
- The six-digit OTP uses iOS One-Time-Code AutoFill and retains the existing Engine verification callback.
- The launch reveal displays "welcome to frozenapps" word by word.
- The install-only Stats card uses the icon from the signed app bundle and actual Engine progress/stage data. Its Progress Stack reads Engine.stepStates and appears only during an active install.
- App-owned interface colors are grayscale, the app tint is white, and the launch background is OLED black.

## Preserved behavior

Authentication, AccountStore, Keychain, two-factor answer handling, pairing, provisioning, signing, installation, file import/export, app catalog, update checks, Local Network permissions and the pinned upstream engine are kept in their existing implementations.

The React reference components are represented by native SwiftUI equivalents because the shipping target is a native iOS/iPadOS app; browser code is not embedded in the app.

## Verification limits

CI verifies source integration, monochrome assets, Metal compilation, Xcode compilation, app bundle metadata and unsigned IPA packaging. It cannot prove physical-device Apple authentication, pairing, signing or installation. The IPA remains unsigned until signed through a supported method.
