<p align="center"><img src="Branding/engagetal-logo.png" alt="Engagetal Solutions" width="240"></p>

# KCleaner for Mac

**Lock your keyboard. Wipe it clean. Get back to work.**

KCleaner is a free, open-source macOS utility by [Engagetal Solutions](https://engagetal.com). It temporarily blocks keyboard input while you clean, shows which keys you have touched, and optionally blocks the trackpad and mouse with a timed unlock.

[Download the DMG](https://github.com/engagetal/KCleaner/releases/latest) · [Download source ZIP](https://github.com/engagetal/KCleaner/archive/refs/heads/main.zip) · [Report an issue](https://github.com/engagetal/KCleaner/issues)

[![GitHub-reported DMG downloads](https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.github.com%2Frepos%2Fengagetal%2FKCleaner%2Freleases%2Ftags%2Fv1.0.0&query=%24.assets%5B%3F%28%40.name%3D%3D%22KCleaner-1.0.dmg%22%29%5D.download_count&label=v1.0+DMG+downloads&color=2ea44f&cacheSeconds=300)](https://api.github.com/repos/engagetal/KCleaner/releases/tags/v1.0.0)

![MIT license](https://img.shields.io/badge/license-MIT-green)
![macOS 13 or later](https://img.shields.io/badge/macOS-13%2B-blue)
![Apple Silicon](https://img.shields.io/badge/chip-Apple%20Silicon-black)

## Install

The supplied release targets **Apple Silicon Macs running macOS 13 Ventura or later**.

1. Download `KCleaner-1.0.dmg` from [Releases](https://github.com/engagetal/KCleaner/releases/latest).
2. Open the DMG and copy KCleaner to Applications. Eject the disk image.
3. Open KCleaner. Grant Accessibility access when requested in **System Settings → Privacy & Security → Accessibility**.
4. If macOS cannot create the input blocker, quit and reopen the app, and check **Input Monitoring** as well.

The supplied DMG is distributed as provided by Engagetal. Developer ID signing and Apple notarization have not been verified for this artifact. macOS may prevent it from opening. You can build from the source below; do not disable Gatekeeper system-wide.

## Use

- Click **Start**, then wipe the keys. The on-screen map highlights touched key positions; it cannot measure physical cleanliness.
- Hold the on-screen finish button for one second to unlock.
- To clean the trackpad, turn on **Lock trackpad too** and choose a timer. Pointer input is blocked too, so wait for the timer or use the emergency exit.
- **Emergency exit:** hold **Esc + Delete** together for three seconds to unlock and quit.
- Clean mode has a maximum ten-minute timer and ends on sleep, screen lock, or user switching.

Touch ID/power is handled by hardware and cannot be blocked. Caps Lock can still change state. Secure Keyboard Entry and macOS behavior can affect event interception; do not rely on complete suppression of every system shortcut. Test the unlock controls before cleaning.

## Privacy

The reviewed source contains no networking, analytics, ads, accounts, or update checks. Clean mode tracks key positions and counts in memory, rather than recording typed text. The app uses Apple's event-tap APIs and needs Accessibility permission to intercept input. macOS may create preferences, caches, or diagnostic reports.

The build script includes a source-pattern check for networking APIs. This is a useful check, not a security audit or proof of runtime behavior.

## Get the complete source

```sh
git clone https://github.com/engagetal/KCleaner.git
cd KCleaner
bash build.sh
```

Or choose **Code → Download ZIP**, extract it, open Terminal in the extracted folder, and run `bash build.sh`.

Build requirements: macOS 13+, Apple's Xcode Command Line Tools (`xcode-select --install`), and the Swift compiler. No third-party package dependencies or Xcode project are required. The script builds for the host architecture and ad-hoc signs `build/KCleaner.app`; Intel builds are not validated.

To open the build:

```sh
open build/KCleaner.app
```

`bash build.sh --install` replaces `/Applications/KCleaner.app` and launches it. Quit existing copies first. After rebuilding, macOS may require removing and re-adding the app under Accessibility.

## DMG download count

The badge above displays the unrounded count for the v1.0 DMG. Badge images are cached and may lag; click the badge for the GitHub API response or run the script for a fresh query.

GitHub maintains an integer `download_count` for each release asset. The exact GitHub-reported count is available via the [release API](https://api.github.com/repos/engagetal/KCleaner/releases/tags/v1.0.0): find the asset named `KCleaner-1.0.dmg` and its `download_count`.

Run `python3 download-count.py` to display unrounded counts for **every DMG in every published release**, plus a total and a UTC retrieval timestamp. This queries GitHub directly and does not download the DMG.

Counts represent GitHub-recorded asset downloads, not unique users or installations. Repeated downloads can count again. Downloads hosted elsewhere, source ZIP downloads, and clones are separate. Deleting and re-uploading an asset loses that asset's previous count. Keep released assets intact; publish a new version for replacements.

## Project guide

| File | Purpose |
| --- | --- |
| `Sources/InputBlocker.swift` | System-wide keyboard and optional pointer event tap |
| `Sources/EmergencyExit.swift` | Esc + Delete hold gesture |
| `Sources/AppModel.swift` | Session state, timers, and lifecycle |
| `Sources/MainWindowView.swift` | Main UI, help, privacy, and About |
| `Sources/CleanModeView.swift` | Cleaning overlay and keyboard map |
| `Sources/KeyboardLayout.swift` | MacBook key positions |
| `Sources/Uninstall.swift` | Removal flow |
| `Sources/System.swift` | Permissions, menus, and app icon |
| `Sources/Brand.swift` / `Components.swift` | Branding, theme, and shared UI |
| `build.sh` | Local compile, resources, icon, and ad-hoc signing |

## Uninstall

Move KCleaner from Applications to Trash and remove its Accessibility/Input Monitoring permissions in System Settings. The app also offers **KCleaner → Uninstall KCleaner…**. Review its removal plan carefully: it can offer to remove other app copies, macOS-generated files, and the original source folder. Untick source-folder removal if you want to keep your checkout.

## Contribute and get help

See [CONTRIBUTING.md](CONTRIBUTING.md) for development and manual testing, [SECURITY.md](SECURITY.md) for private vulnerability reporting, and [RELEASING.md](RELEASING.md) for distribution and counting details.

## License and company

KCleaner is licensed under the [MIT License](LICENSE), copyright © 2026 Engagetal Solutions (OPC) Private Limited. The license does not grant trademark rights or imply endorsement by Engagetal.

[Website](https://engagetal.com) · [Apps](https://engagetal.com/apps) · [hello@engagetal.com](mailto:hello@engagetal.com) · New Delhi, India
