# Valet

Valet is a free, open-source (MIT) **menu bar manager for macOS 14+**. It hides and shows menu bar items on demand, keeping your menu bar tidy without giving up quick access to anything.

## Features

- **Three sections** for your menu bar items: **Shown**, **Hidden**, and **Always Hidden**
- **One-click toggle** — click Valet's ⋯ button to reveal or hide the Hidden section
- **Option-click** the Valet button to also reveal the Always Hidden section
- **Global hotkey** to toggle from anywhere (recordable in Settings → Hotkeys)
- **Auto-rehide** after a configurable delay (default 15 seconds, adjustable or off)
- **Settings window** with a live list of your menu bar items — drag rows between sections and Valet moves the real icons for you
- **Launch at login** (via Apple's `SMAppService`, toggleable in Settings → Behavior)
- **Multi-display aware** — Valet's control items appear on each display's menu bar
- **Manual-only update check** — the single network request in the entire app, and it never fires unless you click the button

## Privacy

Everything Valet does stays on your Mac.

- **No analytics, no telemetry, no background network activity.** The only network request the app can make is the manual **Check for Updates** button in Settings → About, which fetches the latest release info from GitHub — and only when you click it.
- **Settings contain no personal data.** Valet stores only app identifiers (bundle IDs of your menu bar apps) and your preferences (hotkey, delays, section assignments) in its own `UserDefaults` domain.
- **Menu bar item images stay in memory.** Icons captured for the Settings item list are never written to disk and never leave the app.

## Install

1. Download the latest release zip and unzip it.
2. Move `Valet.app` to `/Applications`.
3. The first time, **right-click (or Control-click) `Valet.app` and choose "Open"**, then confirm in the dialog.

That right-click step is needed because Valet is **not notarized** — it is built and ad-hoc signed without an Apple developer account, so Gatekeeper will refuse a plain double-click on first launch. The entire source is right here: you can audit it and build it yourself (below) if you prefer not to trust a downloaded binary.

## Build from source

Requires only the **Xcode Command Line Tools** (`xcode-select --install`) — no Xcode, no dependencies.

```bash
git clone https://github.com/valet-menu/valet.git
cd valet
Scripts/make-app.sh
open build/Valet.app
```

`Scripts/make-app.sh` builds a release binary with Swift Package Manager, assembles `build/Valet.app`, and ad-hoc signs it. Pass `--universal` for an arm64 + x86_64 binary, and `--install` to copy the result to `/Applications` and launch it (quitting any running copy first). Run the tests with `swift test`.

> Heads-up when rebuilding: each build re-signs the app with a new ad-hoc signature, which makes macOS forget its Screen Recording/Accessibility grants — re-grant them in System Settings after installing an update you built yourself.

> Note: the repository URL above will be finalized when the project is published; it matches the slug the in-app update checker uses.

## Usage

- **Click the Valet button** in the menu bar to show or hide the Hidden section. Hidden items slide back into view; click again (or wait for auto-rehide) to tuck them away.
- **Option-click the Valet button** to also reveal the Always Hidden section.
- **Right-click the Valet button** for a menu with **Settings…** and **Quit Valet**.
- **Assign items to sections** either way:
  - **Cmd-drag** icons in the menu bar itself. Valet places two `|` separators: icons **between** them are Hidden, icons **left of the leftmost** one are Always Hidden, and icons to the right of both (next to the Valet button) are Shown. Reveal everything first (Option-click the Valet button) so both separators are on screen, then drag.
  - Or open **Settings → Items** and drag rows between the Shown / Hidden / Always Hidden lists (right-click a row for a "move to" menu). With Accessibility granted, Valet performs the Cmd-drag for you.
- **Settings → Behavior** for auto-rehide and its delay, plus launch at login. **Settings → Hotkeys** to record a global toggle hotkey.

## Permissions

Valet asks for two optional permissions. **It works without both** — you just lose some convenience, and nothing ever leaves your Mac either way.

| Permission | What it enables | Without it |
| --- | --- | --- |
| **Screen Recording** | Shows each item's exact menu bar glyph in the Settings item list (still images, kept in memory only). | The item list still works, showing each owning app's icon and name instead. |
| **Accessibility** | Lets Valet move icons between sections for you by simulating the Cmd-drag. | Section assignments still save; you Cmd-drag the icons yourself in the menu bar. |

> Why does the Screen Recording prompt mention audio? Recent macOS versions label this single permission "Screen & System Audio Recording" — that wording is Apple's and can't be changed by the app. Valet contains no audio code and records no video: it takes still snapshots of individual menu bar items only, and the entire capture path is one small file you can audit, `Sources/Valet/Introspection/ItemImageCapturer.swift`.

You can grant, decline, or revoke either at any time in **System Settings → Privacy & Security**; the Settings → Permissions tab shows live status with request buttons and shortcuts to the right System Settings pane.

## License

[MIT](LICENSE)
