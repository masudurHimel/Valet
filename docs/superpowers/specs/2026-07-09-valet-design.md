# Valet — Design Spec

**Date:** 2026-07-09
**Status:** Approved by owner (all sections)

## What

Valet is an open-source macOS menu bar manager: it hides, shows, and organizes
menu bar items, matching the full feature set of commercial menu bar managers
(Bartender-class functionality) while being 100% free, open source, and local.

Valet replicates *functionality only*. It uses its own name, icon, UI, and
copy — no third-party assets or branding are copied.

## Goals & constraints

- **Feature parity target:** the full Bartender 5 feature set, delivered in phases.
- **Fully local:** no analytics, no telemetry, no background network. The only
  network call in the entire app is a *manual* "Check for Updates" button
  (one GitHub Releases API request, only on explicit click, result opens the
  releases page in the browser).
- **No PII:** settings store only app bundle identifiers, layout geometry, and
  behavior preferences in a local `UserDefaults` plist. Captured menu-bar
  images live in memory only and are never written to disk.
- **No Apple developer account:** builds are ad-hoc signed with free Xcode.
  Not notarized; README documents the right-click → Open first launch.
  Distribution: GitHub Releases (zip) + Homebrew cask.
- **Quality bar:** each phase ships only when its features pass the manual
  verification checklist and unit tests; FEATURES.md tracks status honestly.

## Platform & stack

- macOS 14 (Sonoma) and later; Apple Silicon + Intel (universal binary).
- Swift, SwiftUI for the settings window, AppKit for the menu bar layer.
- Menu-bar-only app (`LSUIElement = true`, no Dock icon).
- MIT license.

## Privacy & security model

The app **cannot be App Sandboxed**: enumerating and moving other apps' menu
bar items requires `CGWindowList` and synthesized Cmd-drag events, which the
sandbox forbids (Bartender and Ice are unsandboxed for the same reason).
Privacy is guaranteed by auditable code instead:

- No network code paths except the manual update check (isolated in one file,
  `UpdateChecker`, easy to audit or delete).
- Hardened runtime enabled where possible with ad-hoc signing.
- No dynamic code loading, no embedded third-party analytics SDKs,
  zero third-party dependencies in Phase 1.

Two macOS permissions, both optional with graceful degradation:

| Permission | Used for | If refused |
|---|---|---|
| Screen Recording | Reading menu bar item names/images (menu bar strip only, in-memory only) | Hiding still works; settings show a generic item list |
| Accessibility | Moving items between sections via simulated Cmd-drag | User arranges items manually with Cmd-drag |

Permissions are requested with in-app explanation screens, never on first
launch ambush.

## Core mechanism

Hiding uses the **expanding-spacer technique**: Valet owns two status items —
a separator and a toggle chevron. To hide, the separator's length expands so
that every item to its left is pushed off-screen. This is the same proven,
public-API mechanism used by Ice and Hidden Bar.

On top of that, Valet introspects the real menu bar:

- `CGWindowListCopyWindowInfo` enumerates menu bar item windows (owning app,
  frame, level).
- ScreenCaptureKit captures item images for the settings UI, search, and the
  future secondary bar. Captures are cropped to the menu bar strip and never
  persisted.
- Items are moved between sections by synthesizing Cmd-drag mouse events
  (Accessibility permission).

## Components

- **MenuBarManager** — owns the separator + toggle status items; expands the
  spacer to hide; handles show-then-auto-rehide timing and multi-display.
- **ItemIntrospector** — enumerates item windows, captures images, reconciles
  items across refreshes by owning-app bundle ID (position as tiebreaker for
  apps with multiple items).
- **LayoutEngine** — state machine for the three sections (Shown / Hidden /
  Always Hidden); computes required item order; drives simulated drags.
  The most heavily unit-tested unit in the app.
- **SettingsStore** — `UserDefaults`-backed; section assignments keyed by
  bundle ID + behavior preferences. No PII by construction.
- **HotkeyManager** — global toggle hotkey via the Carbon hotkey API
  (no permission required).
- **UpdateChecker** — manual-only version check against GitHub Releases.
- **SettingsUI** — SwiftUI window: item list with live images, drag-to-assign
  sections, behavior / hotkeys / permissions / about tabs.

**Data flow:** menu bar change notifications + periodic refresh →
ItemIntrospector → published app state → SettingsUI renders it and
LayoutEngine reacts; user actions (toggle, drag, hotkey) → LayoutEngine →
MenuBarManager.

## Phased feature plan

Tracked as checkboxes in `FEATURES.md` at the repo root, updated with every
change. Summary:

- **Phase 1 (V1):** hide/show toggle (click + global hotkey), three sections,
  settings UI with real items and drag-to-assign, auto-rehide delay, launch at
  login (`SMAppService`), multi-display basics, permissions onboarding,
  manual update check.
- **Phase 2:** show on hover, show on swipe, menu bar item search with
  activate-from-results.
- **Phase 3:** triggers — show items on battery/power state, Wi-Fi change,
  app running, time of day, script output.
- **Phase 4:** menu bar styling (tint, gradient, corner shape), notch-aware
  layout, secondary bar (floating clickable panel of hidden items).
- **Phase 5:** per-display layouts, item spacing controls, settings
  import/export.

## Error handling

- Permission denied → guidance screen with a deep link to System Settings;
  app remains functional in degraded mode.
- Items appearing/disappearing mid-session → reconciliation by bundle ID,
  orphaned assignments retained (apps may relaunch).
- Display connect/disconnect/notch changes → full layout rebuild.
- Simulated drag failure (item moved mid-drag, screen locked) → abort,
  re-introspect, retry once, then surface a non-blocking notice.
- macOS behavior changes across minor versions are the top regression risk;
  the manual test checklist runs on every supported major version available.

## Testing

- **Unit tests:** LayoutEngine transitions, reconciliation logic,
  SettingsStore round-trips, version comparison in UpdateChecker.
- **Manual release checklist:** scripted steps covering hide/show, drag
  assignment, hotkeys, permission flows, multi-display, login item — run
  before any release tag (menu bar manipulation is not CI-able).
- Each phase's features are checked off in FEATURES.md only after both pass.

## Distribution

GitHub public repo (MIT) → tagged releases with an ad-hoc-signed universal
zip → Homebrew cask after first stable release. README covers Gatekeeper
first-launch, permission rationale, and a privacy statement ("the only
network request this app can make is the update button you click").
