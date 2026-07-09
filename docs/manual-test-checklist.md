# Valet — Manual Test Checklist (Phase 1 / v0.1.0)

Walk this checklist against a fresh build before tagging a release. Check every line.

## Setup

Build and launch:

```bash
swift test && Scripts/make-app.sh && open build/Valet.app
```

Notes before you start:

- **Ad-hoc re-signing resets permission grants.** Every rebuild produces a new ad-hoc signature, which resets the app's Screen Recording / Accessibility grants in System Settings (TCC). Walk the whole checklist against the **same built bundle**; if you rebuild mid-run, re-grant permissions.
- **Reset separator positions** if they end up misordered during testing: `defaults delete app.valet.Valet` and relaunch (macOS autosaves status item positions after first run).
- **Reset first-run onboarding** to re-test it: `defaults delete app.valet.Valet hasOnboarded` (when run from the bundle, the defaults domain is `app.valet.Valet`).
- Quit between scenarios with `pkill -x Valet` or the right-click → Quit Valet menu.

## App skeleton (Task 1)

1. Launch `build/Valet.app`: the Valet button (⋯) appears in the menu bar and **no Dock icon** appears.
2. `codesign -dv build/Valet.app` reports `Signature=adhoc`.

## Control items, hide/show, auto-rehide (Task 5)

3. On launch, the Valet button and one visible `|` separator appear. The always-hidden separator (and anything left of the hidden separator) is pushed off-screen — collapsed is the default.
4. Option-click the Valet button to reveal everything (so both `|` separators are on screen), then Cmd-drag a third-party menu bar icon **between the two `|` separators**.
5. Click the Valet button: hidden items appear and the ⋯ becomes a circled ⋯. Click again: they hide.
6. Option-click the Valet button: always-hidden items also appear.
7. Reveal and wait 15 seconds (default delay): the bar auto-collapses.
8. Right-click the Valet button: a menu appears with "Settings…" (opens the settings window) and "Quit Valet" (quits the app).

## Settings window + Behavior tab + launch at login (Task 10)

9. Right-click the Valet button → "Settings…" opens the settings window with 5 tabs: Items, Behavior, Hotkeys, Permissions, About.
10. Behavior tab: the auto-rehide toggle and delay stepper work, and changed values persist across relaunch.
11. Launch at login toggle: when the app is **not** in /Applications, toggling it on shows an error message and the toggle reverts. (With the app in /Applications, the toggle sticks and registers with `SMAppService`.)

## Items tab — icons, drag-to-assign, real moves (Task 11)

12. Open Settings → Items **without** Screen Recording granted: a yellow banner shows, and rows show generic icons plus app names.
13. Grant Screen Recording, then relaunch: real item icons appear in the list.
14. Capture behavior for a **hidden** item: while the bar is collapsed, check a Hidden-section row in the Items tab. Off-screen items may show a generic icon rather than their real image — this is a known limitation; observe and note the actual behavior.
15. Grant Accessibility, then drag an item row from Shown to Hidden: the real menu bar icon physically moves left of the `|` separator, and the assignment persists after relaunch.
16. Right-click an item row → "Move to Always Hidden": works the same way (icon moves left of the leftmost separator).
17. **Without** Accessibility: moving an item shows the orange guidance message and still saves the assignment.
18. With the Hidden section **empty** (the two separators adjacent), use the Items tab to move an item to Hidden: a plain click on the Valet button reveals it (regression check for the drag-planner clamp — the item must land between the separators, not in Always Hidden).

## Hotkeys tab, Permissions tab, onboarding (Task 12)

19. Reset onboarding (`defaults delete app.valet.Valet hasOnboarded`) and relaunch: settings opens on the Permissions tab. Both permission rows show status; the Request buttons trigger system prompts; status flips to green within about 2 seconds of granting.
20. Hotkeys tab → Record → press ⌥⌘B: the recorder shows "⌥⌘B". Press the hotkey while another app is frontmost: hidden items toggle.
21. Clear the hotkey: pressing ⌥⌘B no longer toggles.
22. Record the hotkey again and relaunch: the hotkey persists and still works.

## About tab + update check (Task 13)

23. About tab shows the app version (0.1.0).
24. Click "Check for Updates": it returns the "Couldn't check" message gracefully (repo not published yet). No update request ever fires without a click.

## Cross-cutting

25. **Multi-display:** on a second display (if available), the Valet button and separators replicate, and toggling works there too.
26. **Relaunch persistence:** section assignments, the recorded hotkey, and behavior settings (auto-rehide, delay, launch at login) all survive quitting and relaunching.
27. **Permission-revoked degradation:** with both permissions granted and the app running, revoke Screen Recording and Accessibility in System Settings → Privacy & Security. The app must not crash: the Items tab falls back to the yellow banner and generic icons, and moving items shows the orange guidance message while still saving assignments.
28. **Items list stability (regression):** open Settings → Items, then (a) leave the bar collapsed with at least one item assigned to Hidden, and (b) put another app into full screen and come back. In both cases, wait at least 10 seconds: no rows may disappear from the list. (Regression check for the on-screen-only enumeration bug that emptied the list whenever the menu bar wasn't displayed.)
29. **New-item rescue:** with Accessibility granted and Valet collapsed, quit and relaunch a menu bar app (or launch one you don't have running). macOS spawns its icon into the hidden zone; within ~10 seconds Valet must move it into the visible Shown strip (the bar flashes briefly during the rescue). Without Accessibility, the icon stays hidden but remains listed in Settings → Items and is revealed by Option-clicking the Valet button.
