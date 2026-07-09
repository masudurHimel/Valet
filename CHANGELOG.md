# Changelog

All notable changes to Valet are documented here. The format follows
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and Valet adheres to
[Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Bump the version in this file and in `VERSION` together, in the same pull
request, when you intend to ship. Merging that PR to `master` cuts the release.

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
