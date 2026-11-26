# SideStick 1.2.2 — OLED LiquidChrome redesign

## Scope

This branch is based on the published 1.2.2 release and replaces its legacy presentation layer with native SwiftUI and Metal components.

- A single monochrome LiquidChrome Metal renderer sits behind Welcome, account setup, verification and every workspace page. The requested white defaults are pinned; Reduce Motion, Reduce Transparency, Increase Contrast and Low Power Mode have explicit renderer behaviour.
- The previous IMG_2135.jpeg wallpaper is no longer added to the asset catalog or referenced by the workspace backdrop.
- The iPad vertical rail and previous command bar are removed. One six-destination, shape-based black liquid-lens dock is shared by iPhone and iPad; original navigation destinations and actions are retained.
- The animated account form follows the real Apple ID/password values and active field, without revealing password content.
- The secure-access OTP card keeps the single real One-Time-Code AutoFill field, six animated slots, verification/error feedback and the original Engine callback.
- The launch reveal displays "welcome to frozenapps" word by word, with an immediate completion path under Reduce Motion.
- The install-only Stats card uses the icon from the signed app bundle and actual Engine percentage/stage data. Its three-step Progress Stack follows active, waiting, failed and final states and appears only while the Engine reports an active installation.
- App-owned interface colors are grayscale, the app tint is white, and the launch background is OLED black. App-owned screen icons use the central AppIcon resolver and original local SVG vector assets, with a monochrome system fallback for dynamic or unmapped icons.

## Preserved behavior

Authentication, AccountStore, Keychain, two-factor answer handling, pairing, provisioning, signing, installation, file import/export, app catalog, update checks, Local Network permissions and the pinned upstream engine are kept in their existing implementations.

The React reference components are represented by native SwiftUI equivalents because the shipping target is a native iOS/iPadOS app; browser code is not embedded in the app.

## Verification limits

CI verifies source integration, icon migration and vector import, monochrome assets, the LiquidChrome parameter/accessibility contract, Metal compilation, screen coverage, Xcode compilation, app bundle metadata and unsigned IPA packaging. Static source checks do not establish visual quality, clipping, animation smoothness, VoiceOver behaviour, Dynamic Type layout, physical-device Apple authentication, pairing, signing or installation. Those require iPhone/iPad testing with screenshots and interaction recordings. The IPA remains unsigned until signed using a supported method.
