# Valet — a free, open-source Bartender alternative for macOS

Valet is a free, open-source (MIT) **menu bar manager for macOS 14+** — a **Bartender alternative** that hides and shows menu bar items on demand, keeping your menu bar tidy without giving up quick access to anything. Everything is free (there is no paid tier), everything runs **100% locally**, and the entire codebase is small enough to audit in an afternoon.

## Features

- **Three sections** for your menu bar items: **Shown**, **Hidden**, and **Always Hidden**
- **One-click toggle** — click Valet's ⋯ button to reveal or hide the Hidden section
- **Option-click** the Valet button to also reveal the Always Hidden section
- **Global hotkey** to toggle from anywhere (recordable in Settings → Hotkeys)
- **Auto-rehide** after a configurable delay (default 15 seconds, adjustable or off)
- **Settings window** with a live list of your menu bar items — drag rows between sections; Valet saves the choice and, with Accessibility granted, moves the real icons for you
- **Launch at login** (via Apple's `SMAppService`, toggleable in Settings → Behavior)
- **Multi-display aware** — Valet's control items appear on each display's menu bar
- **Manual-only update check** — the single network request in the entire app, and it never fires unless you click the button

## Valet vs. Bartender

If you're looking for a Bartender alternative, here's the honest picture. Valet covers the core menu-bar management workflow today, with the rest of the feature set on a public roadmap ([FEATURES.md](FEATURES.md)):

| Capability | Bartender (paid) | Valet (free) |
| --- | --- | --- |
| Hide/show menu bar items, Shown + Hidden + Always Hidden sections | ✅ | ✅ |
| Global hotkey, auto-rehide, click to toggle | ✅ | ✅ |
| Menu bar item list, drag between sections | ✅ | ✅ |
| Auto-handling of newly appearing items | ✅ | ✅ |
| Show items on hover/swipe, menu bar item search | ✅ | 🔜 roadmap |
| Triggers (battery, Wi-Fi, app-based) | ✅ | 🔜 roadmap |
| Menu bar styling, secondary bar | ✅ | 🔜 roadmap |
| Price | Paid license | Free forever (MIT) |
| Source code | Closed | Open — audit every line |
| Network traffic | — | None, except the update button **you** click |

## Privacy & security

Everything Valet does stays on your Mac, and the attack surface is deliberately tiny and fully auditable:

- **No analytics, no telemetry, no background network activity.** The only network request the app can make is the manual **Check for Updates** button in Settings → About, which fetches the latest release info from GitHub — and only when you click it.
- **Settings contain no personal data.** Valet stores only app identifiers (bundle IDs of your menu bar apps) and your preferences (hotkey, delays, section assignments) in its own `UserDefaults` domain.
- **Menu bar item images stay in memory.** Icons captured for the Settings item list are never written to disk and never leave the app.
- **No known security issues, and easy to verify.** Zero third-party dependencies, no dynamic code loading, and exactly one file that can touch the network (`Sources/Valet/Settings/UpdateChecker.swift`) — you can confirm each of these claims yourself with a few greps. Every release passes an adversarial code review and the [TESTING.md](TESTING.md) checklist before it is tagged.

## Install

1. Download the latest release zip and unzip it.
2. Move `Valet.app` to `/Applications`.
3. Open `Valet.app`.

> [!NOTE]
> On first launch, macOS may warn that it *"could not verify Valet is free of malware"*. **This is expected and the app is completely safe** — Valet is open source and built by GitHub Actions straight from this repository, but it is not notarized by Apple (notarization requires a paid developer account). The warning only offers **Done** and **Move to Bin**, so:
>
> 1. Click **Done** (not Move to Bin).
> 2. Open **System Settings → Privacy & Security**, scroll down to *"Valet" was blocked to protect your Mac*, and click **Open Anyway**.
> 3. Confirm, and Valet launches. This is needed only once.
>
> Alternatively, run `xattr -d com.apple.quarantine /Applications/Valet.app` in Terminal and open the app normally.
>
> The entire source is right here: you can audit it and build it yourself (below) if you prefer not to trust a downloaded binary.

## Build from source

Requires only the **Xcode Command Line Tools** (`xcode-select --install`) — no Xcode, no dependencies.

```bash
git clone https://github.com/masudurHimel/Valet.git
cd Valet
Scripts/make-app.sh
open build/Valet.app
```

`Scripts/make-app.sh` builds a release binary with Swift Package Manager, assembles `build/Valet.app`, and ad-hoc signs it. Pass `--universal` for an arm64 + x86_64 binary, and `--install` to copy the result to `/Applications` and launch it (quitting any running copy first). Run the tests with `swift test`.

> Heads-up when rebuilding: each build re-signs the app with a new ad-hoc signature, which makes macOS forget any Screen Recording/Accessibility grants you made — re-grant them in System Settings after installing an update you built yourself.

## Usage

- **Click the Valet button** in the menu bar to show or hide the Hidden section. Hidden items slide back into view; click again (or wait for auto-rehide) to tuck them away.
- **Option-click the Valet button** to also reveal the Always Hidden section.
- **Right-click the Valet button** for a menu with **Show All Items** (reveals the Always Hidden section too), **Settings…**, and **Quit Valet**.
- **Assign items to sections** either way:
  - **Cmd-drag** icons in the menu bar itself. Valet places two `|` separators: icons **between** them are Hidden, icons **left of the leftmost** one are Always Hidden, and icons to the right of both (next to the Valet button) are Shown. Reveal everything first (Option-click the Valet button) so both separators are on screen, then drag.
  - Or open **Settings → Items** and drag rows between the Shown / Hidden / Always Hidden lists (right-click a row for a "move to" menu). Valet saves the choice and asks you to Cmd-drag the icon across the `|` separators yourself; with Accessibility granted, Valet performs the Cmd-drag for you.
- **Safe launches:** your hidden arrangement persists across relaunches, and Valet verifies it before collapsing — if an icon appeared while Valet was closed and would start the session invisible, the separators reset to the far left instead and everything stays visible. Relaunching Valet never makes an item disappear.
- **Settings → Behavior** for auto-rehide and its delay, plus launch at login. **Settings → Hotkeys** to record a global toggle hotkey.

## Permissions

**Valet never asks for any permission.** There are no prompts, and everything above works out of the box: the item list shows each owning app's icon and name, and moving an item saves your choice and asks you to Cmd-drag the icon yourself. Two optional grants add convenience for power users — make them yourself in **System Settings → Privacy & Security**, and revoke them at any time:

| Optional grant | What it adds |
| --- | --- |
| **Accessibility** | Valet moves icons between sections for you by simulating the Cmd-drag. |
| **Screen Recording** | The Settings item list shows each item's exact menu bar glyph (still images, kept in memory only). |

> Why does macOS call this one "Screen & System Audio Recording"? That wording is Apple's and can't be changed by the app. Valet contains no audio code and records no video: it takes still snapshots of individual menu bar items only, and the entire capture path is one small file you can audit, `Sources/Valet/Introspection/ItemImageCapturer.swift`.

## License

[MIT](LICENSE)
