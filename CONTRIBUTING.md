# Contributing to KCleaner

Thank you for helping improve KCleaner. Open an issue describing a reproducible bug or a proposed change before starting a large contribution. Include macOS version, chip architecture, app version, permission state, and steps to reproduce. Do not include private typed content or credentials.

## Develop

Fork this repository, clone your fork, create a branch, and run `bash build.sh` on macOS. The app uses Swift, SwiftUI, AppKit, CoreGraphics, and Carbon; there are no external package dependencies. Keep input interception, emergency exits, and privacy behavior easy to review.

Submit a focused pull request with the problem, changed behavior, and validation performed. Contributions are provided under the repository's MIT License. Be respectful and constructive in discussions.

## Manual validation before merging input-related changes

Use a Mac on which you can safely test input blocking. Save other work first.

- Permission denied: clear explanation; no stuck input.
- Keyboard-only mode: typing is blocked, key highlights update, pointer remains usable, and hold-to-finish unlocks.
- Timed pointer mode: the selected timer restores keyboard and pointer input.
- Esc + Delete held for three seconds: unlocks and exits.
- Sleep, lock, user switching, and process termination: input is restored.
- Ten-minute maximum and all timer choices: unlock as expected.
- Caps Lock, media keys, external keyboards, and Secure Keyboard Entry: document observed limitations.
- Uninstall: inspect the plan before confirming; test only with disposable app/source copies.

A successful compile does not validate Accessibility permissions, timing, or hardware behavior. Record the actual Mac and macOS versions used.
