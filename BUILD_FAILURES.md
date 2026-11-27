# Build / CI failure record

## Resolved validator failures

### 1. read() received a string instead of Path

- Observed message: AttributeError: 'str' object has no attribute 'is_absolute'
- Observed at: scripts/check-screen-coverage.py:11
- Actions evidence: run 45850780601, commit 70385417e95080c2c705d04ffe8f8219324f6f37.
- Root cause: read() called path.is_absolute() even though call sites passed path strings.
- Fix: normalize with path = Path(path) at the start of read().
- Fix commit: 398544106d664894e869fba33ec0e3af29921c64 (fix(ci): normalize screen audit paths before reading).

### 2. RootView assertion executed before RootView was loaded

- Observed message: NameError: name 'root_view' is not defined
- Observed at: scripts/check-screen-coverage.py:54
- Actions evidence: run 45851830418, commit 398544106d664894e869fba33ec0e3af29921c64.
- Root cause: the screen audit checked the existing two-factor callback before assigning the source returned by read(APP / RootView.swift).
- Fix: load RootView before the callback assertion and remove the later duplicate assignment.
- Fix commit: a1872364d9ce54aa7503b5656017adb704a6c391 (fix(build): define RootView before screen coverage assertions).

## Green build evidence

- Fix commit: a1872364d9ce54aa7503b5656017adb704a6c391.
- Actions run: 46010473811 — completed successfully.
- Build: Rust device and simulator static libraries built; Xcode app build succeeded; Metal shader compilation succeeded.
- Validation: app bundle, asset catalog, app icon set, bundle metadata, minimum iOS and both arm64 architectures passed.
- IPA: unsigned IPA package passed ZIP CRC, required-entry and metadata checks.
- Limitation: these Actions checks validate compilation and packaging, not physical-device Apple sign-in, pairing, signing, installation, visual quality or performance.

## Non-failing tool warnings

The run emitted Node.js 20 and Node package deprecation warnings (punycode and url.parse). They were warnings from the GitHub Actions toolchain, not Rust, Metal or Xcode build errors.
