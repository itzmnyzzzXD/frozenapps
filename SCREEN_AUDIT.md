# SideStick screen audit — static source review

This audit records implementation coverage and the evidence available in the source. It is not a screenshot-based visual scorecard: no physical iPhone or iPad runtime capture has been produced in this CI environment.

## Screen coverage

| Screen / surface | Source evidence | Static result |
|---|---|---|
| App root and LiquidChrome | One shared Metal renderer behind onboarding, account, verification and workspace content; app root owns touch interaction | Integrated; device rendering still needs validation |
| Welcome | Three-word reveal, completion callback, Reduce Motion immediate reveal | Integrated |
| Account setup | Real email/password bindings, field focus state, readiness progress, upstream AccountStore save action retained | Integrated |
| Two-factor verification | Six-digit slots, One-Time-Code AutoFill, status/error/working UI; existing Engine answer path retained | Integrated |
| Home / Signer | Existing signer engine and account state; shared workspace panels and search/filter primitives | Requires device review |
| App Catalog and Batch Actions | Repository source model, filters, release lookup and IPA import path | Requires device review |
| Certificate Health | Local profile/certificate metadata and bundle pattern pre-check; explicitly does not infer revocation | Requires device review |
| Frozen Center / Tools | Live Engine status and navigation to certificate, JIT, tracker, library, device, network, alerts, status, guide, catalog and batch tools | Requires device review |
| Device Center | OS path diagnostics and copyable report that labels pairing/JIT as unverified | Requires device review |
| IPA Library | Import progress, library entries, metadata and file actions; import summary now uses an immutable concurrency snapshot | CI compile required |
| JIT Center | Helper connection/discovery, paired-device selection and eligible-app view | Requires device review |
| Network | OS-reported path, Local Network prompt/discovery and nearby-service list | Requires device review |
| Signer install catalog | App categories, release/IPA selection and download/import path | Requires device review |
| Workspace navigation | Six original destinations retained in one shape-based monochrome liquid-lens dock; 44pt minimum button targets | Integrated; device layout still needs validation |
| Install progress | Real app bundle icon, Engine progress and step states; three visible stages follow active/failure/final states; card appears only while Engine is running | Integrated; live installation needs device validation |

## Design review rubric for device captures

When screenshots and recordings are available, score each surface from 1–5 on:
1. Hierarchy — primary action and current state are immediately apparent.
2. Rhythm — spacing and alignment are consistent across cards, rows and sections.
3. Token discipline — OLED black, white and the allowed opacity steps only.
4. Legibility — compact labels remain readable at iPhone and iPad widths.
5. Motion — animations clarify state changes and respect Reduce Motion.
6. Accessibility — controls expose names/states, preserve Dynamic Type where possible and meet touch-target requirements.

No numeric visual scores are assigned here because static Swift source cannot establish rendered balance, clipping, optical alignment, animation smoothness or actual hit-target behavior.

## Verification boundary

The CI pipeline checks icon migration, vector asset import, screen wiring, monochrome rules, LiquidChrome parameters/accessibility flags, Metal compilation, Rust/Xcode compilation, app bundle validation and unsigned IPA integrity. Physical-device sign-in, AutoFill behavior, pairing, signing, install progress, VoiceOver, Dynamic Type, thermal behavior and frame rate remain device-test items.
