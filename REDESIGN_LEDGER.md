# LiquidChrome redesign execution ledger

Repository: `itzmnyzzzXD/frozenapps`
Working branch: `redesign/1.2.2-oled-liquidchrome`
Verified base HEAD: `398544106d664894e869fba33ec0e3af29921c64`
Status values are authoritative. No requirement is DONE without its acceptance output and a commit SHA.

## Requirement status

| id | status | commit SHA | evidence | last verified (date and SHA) |
|---|---|---|---|---|
| R1 | IN PROGRESS | 090ce24a5d6eafa88bdd2b306f3bcb38de7e9244 | R1.1 and R1.3 complete; R1.2 remains in progress until current-head CI, full build/IPA and aggregate verify-all pass. | 2026-11-27 / 090ce24a5d6eafa88bdd2b306f3bcb38de7e9244 |
| R2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R8 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R9 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R10 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Unverified; queue begins after R1 build is green. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |

## Acceptance-check status

| id | status | commit SHA | evidence / acceptance check | last verified (date and SHA) |
|---|---|---|---|---|
| R1.1 | DONE | a1872364d9ce54aa7503b5656017adb704a6c391 | `fix(build): define RootView before screen coverage assertions`; only `scripts/check-screen-coverage.py` changed (1 addition/1 deletion). Previous blob `dbff2a27a4102f8aed939e8637acd92d6018bab`, new blob `fe50ae59dd7dc1d0abdd0932171c6d0ee1f2d07e`. | 2026-11-27 / a1872364d9ce54aa7503b5656017adb704a6c391 |
| R1.2 | IN PROGRESS | aab50a6810ba9d6d7871a3c45e559bc1a7734903 | Fixed CI checkout to fetch full history (`fetch-depth: 0`), so verify-all can resolve older ledger commit SHAs. Awaiting current-head aggregate verification and full build/IPA. | 2026-11-27 / aab50a6810ba9d6d7871a3c45e559bc1a7734903 |
| R1.3 | DONE | ef6774007129be1551878c428fc11708cd57c17e | BUILD_FAILURES.md records both observed validator errors, exact file:line, root causes, fixing commits and the later green build evidence. | 2026-11-27 / ef6774007129be1551878c428fc11708cd57c17e |
| R2.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | scripts/check-monochrome.sh exists and is committed. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R2.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The monochrome script output reports zero violations. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R2.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | AccentColor is white and the app root applies .tint(.white). | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R2.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The app root applies .preferredColorScheme(.dark). | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R2.5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Repository Swift source has no system Material usage. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R2.6 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Wallpaper and image-background references are absent; original assets are retained. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R2.7 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Black launch screen and light status-bar configuration are evidenced. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R2.8 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Source hex colors are restricted to #000000 and #FFFFFF. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | LiquidChromeBackground is a UIViewRepresentable backed by MTKView. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | SIM, SLOPE and CHROME pipelines use two ping-pong RG16Float state textures and one RG16Float slope texture. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The full required LiquidChrome defaults struct exactly matches the contract. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The real Metal compiler succeeds and output is captured. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The final luminance conversion line is present and referenced. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.6 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | One background instance is mounted at the app root with hit-testing disabled and safe-area coverage. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.7 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Touch constants and the six-stroke queue match the S1b formulas. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.8 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Inactive, low-power, thermal, off-screen and covered-view pause rules are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R3.9 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Reduce Motion freezes a still frame and unsupported Metal falls back to solid black. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R4.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Welcome is the first presented launch-path view. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R4.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The displayed text is exactly Welcome to FrozenApps. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R4.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Per-word opacity and blur use 0.5s ease-out with 0.2s word staggering. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R4.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The final hold, 0.4s crossfade and tap-to-skip behavior are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R4.5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | App initialization, store creation and auth restoration continue underneath the presentation. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R4.6 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Reduce Motion and one-element VoiceOver behavior are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R5.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Existing login fields, ordering, bindings, keyboard types and callbacks are unchanged. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R5.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Per-character fade and the three check-indicator timings match the source contract. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R5.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Field checks are driven by existing validation or the specified focus fallback. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R5.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Demo loop, demo text, Create Account title and brand row are absent. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R5.5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The form remains monochrome and respects Reduce Motion. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | OTP slot dimensions, radius, gaps and count match the iPhone/iPad contract. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | One hidden .oneTimeCode number-pad TextField supports digit filtering, paste and AutoFill. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The active slot ring glides using matchedGeometryEffect and the specified spring. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Success appears only after the existing verification callback reports success. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6.5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The original ParticleSphere replacement and 60s/30s ring rotations are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6.6 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | No OTP glow blobs, blurred circles, materials or sci-fi copy remain. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R6.7 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | VoiceOver count label and Reduce Motion behavior are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | A full-screen loading UI reads existing install/download state; no logic files are changed. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The selected app's actual icon is shown in grayscale. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Progress binds to the real fraction and documented pipeline stage mapping. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The three-row stack has active/upcoming/done scales, opacity and fades. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7.5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The Stats graph has a 3s comet following the specified curve. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7.6 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Completion, auto-dismiss, failure and UI-only dismissal states are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R7.7 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Reduce Motion disables travel/spin/slide while preserving useful state feedback. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R8.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Existing destinations, order, selection binding and iPad rail/compact behavior are preserved. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R8.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The three-tab position table and required spring are represented in code. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R8.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The exact scale and bar-width formulas are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R8.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | 44pt targets, selected VoiceOver trait and selection haptic are present. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R8.5 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Previews cover 3, 4 and 5 destination configurations. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R8.6 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Reduce Motion and Reduce Transparency behavior are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R9.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | ICON_MAP.md records usage, replacement concepts and Flaticon search keywords. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R9.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | AppIcon loads local vector imagesets with a single-weight SF fallback and importer. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R9.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | No raw SF Symbol calls or emoji remain outside the AppIcon fallback. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R9.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | THIRD_PARTY_NOTICES.md contains required upstream/community attribution and license evidence. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R10.1 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Each redesigned screen has a three-line brief and six rubric scores of at least 4/5. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R10.2 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | Idle, pressed, loading, success, error, empty and disabled states are implemented. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R10.3 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | The repository-wide banned-pattern review and verify-all checks pass. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |
| R10.4 | NOT STARTED | 398544106d664894e869fba33ec0e3af29921c64 | iPhone and iPad layouts are implemented and checked. | 2026-11-27 / 398544106d664894e869fba33ec0e3af29921c64 |

## Resume pointer

**R1 → R1.2:** inspect Actions on `aab50a6810ba9d6d7871a3c45e559bc1a7734903`; verify the full-history ledger scan, aggregate verify-all and IPA packaging.
