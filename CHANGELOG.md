# Changelog

All notable changes to Valet are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Valet adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Bump the version in this file and in `VERSION` together, in the same pull
request, when you intend to ship. Merging that PR to `master` cuts the release.

## [0.1.1] - 2026-07-10

### Fixed
- Launch no longer swallows menu bar items. Previously the separators were restored mid-bar and anything that had spawned further left while Valet was closed (macOS spawns all new status items at the far left) started the session invisible in the Always Hidden zone — and was wrongly given a persisted `alwaysHidden` assignment. Now Valet verifies the restored layout before collapsing: hidden arrangements still persist across relaunches, but if any item sits in a hidden zone without your recorded choice, the separators reset to the far left and that session starts with every item visible. Phantom menu bar windows that are not part of the packed item strip (Control Center keeps one per module; the input-menu agent parks one at the far left of the screen) are ignored by this check — previously the far-left phantom made every launch look like a swallowed item, so the separators reset every time and hidden arrangements never survived a relaunch.
- Items are auto-assigned to a hidden section only when Valet watches you drag them there during the session; an item first sighted inside a hidden zone is treated as freshly spawned and rescued instead.

### Added
- "Show All Items" in the Valet button's right-click menu to reveal the Always Hidden zone.

### Removed
- The Permissions settings tab. Valet never prompts for or requires any permission: the item list shows owning-app icons and moves save with Cmd-drag guidance by default. Accessibility (automatic Cmd-drag) and Screen Recording (exact menu bar glyphs) remain optional grants made manually in System Settings. First-launch onboarding now opens the Items tab.

## [0.1.0] - 2026-07-09

Phase 1 — first public release.

### Added
- Menu bar management with three sections: Shown, Hidden, and Always Hidden.
- One-click toggle on the Valet (⋯) button to reveal/hide the Hidden section; Option-click also reveals Always Hidden.
- Global, recordable hotkey to toggle from anywhere.
- Auto-rehide after a configurable delay (default 15s, adjustable or off).
- Settings window (Items, Behavior, Hotkeys, Permissions, About) with a live item list and drag-to-assign between sections.
- Automatic Cmd-drag of real menu bar icons when Accessibility is granted; assignments still save without it.
- Rescue of newly spawned menu bar items out of the hidden zone into the Shown strip.
- Launch at login via `SMAppService`.
- Multi-display support.
- Manual-only "Check for Updates" against GitHub Releases — the sole network request in the app.
