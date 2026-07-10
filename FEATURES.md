# Valet — Feature Checklist

Status legend: `[ ]` planned · `[~]` in progress · `[x]` done (tests + manual verification passed)

## Phase 1 — Core (V1)

- [x] Menu bar separator + toggle chevron control items
- [x] Hide/show via expanding spacer
- [x] Three sections: Shown / Hidden / Always Hidden
- [x] Toggle by clicking the chevron
- [x] Global hotkey toggle
- [x] Auto-rehide after configurable delay
- [x] Item introspection (CGWindowList enumeration)
- [x] Item image capture (ScreenCaptureKit, in-memory only)
- [x] Settings UI: item list with images, drag-to-assign sections
- [x] Settings UI: items / behavior / hotkeys / about tabs
- [x] Move items between sections via simulated Cmd-drag
- [x] Zero-permission operation — the app never prompts; Accessibility (auto-move) and Screen Recording (real icons) are optional manual grants
- [x] Verified launches — hidden arrangement persists across relaunches, but the restored layout is checked before collapsing and resets to all-visible if it would swallow an item the user never hid; hidden-section auto-assignment only from drags Valet watched
- [x] "Show All Items" in the chevron's right-click menu
- [x] Launch at login (SMAppService)
- [x] Multi-display basics (control items on active display)
- [x] Manual "Check for Updates" button (only network call in the app)
- [x] Local-only settings storage (bundle IDs + prefs, no PII)
- [~] New items spawning into the hidden zone are auto-rescued to Shown (needs Accessibility; manual verify pending)

## Phase 2 — Reveal & search

- [ ] Show hidden items on hover over the menu bar
- [ ] Show hidden items on trackpad swipe
- [ ] Menu bar item search (hotkey-invoked)
- [ ] Activate an item from search results

## Phase 3 — Triggers

- [ ] Show item on battery level / power source change
- [ ] Show item on Wi-Fi network change
- [ ] Show item while a given app is running
- [ ] Show item on time-of-day schedule
- [ ] Show item based on script output

## Phase 4 — Styling & secondary bar

- [ ] Menu bar tint / gradient / custom color
- [ ] Menu bar corner shape styling
- [ ] Notch-aware layout handling
- [ ] Secondary bar (floating clickable panel of hidden items)

## Phase 5 — Polish

- [ ] Per-display layouts
- [ ] Item spacing controls
- [ ] Settings import/export (local file)
