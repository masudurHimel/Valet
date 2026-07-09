# Valet — Feature Checklist

Status legend: `[ ]` planned · `[~]` in progress · `[x]` done (tests + manual verification passed)

## Phase 1 — Core (V1)

- [x] Menu bar separator + toggle chevron control items
- [x] Hide/show via expanding spacer
- [~] Three sections: Shown / Hidden / Always Hidden
- [x] Toggle by clicking the chevron
- [ ] Global hotkey toggle
- [x] Auto-rehide after configurable delay
- [x] Item introspection (CGWindowList enumeration)
- [~] Item image capture (ScreenCaptureKit, in-memory only)
- [ ] Settings UI: item list with images, drag-to-assign sections
- [~] Settings UI: behavior / hotkeys / permissions / about tabs
- [ ] Move items between sections via simulated Cmd-drag
- [ ] Permissions onboarding with graceful degradation
- [x] Launch at login (SMAppService)
- [x] Multi-display basics (control items on active display)
- [ ] Manual "Check for Updates" button (only network call in the app)
- [x] Local-only settings storage (bundle IDs + prefs, no PII)

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
