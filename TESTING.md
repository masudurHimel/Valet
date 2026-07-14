# Valet — Manual Test Checklist (Phase 1 / v0.1.0)

Walk this checklist against a fresh build before tagging a release. Check every line.

## Setup

Build and launch:

```bash
swift test && Scripts/make-app.sh && open build/Valet.app
```

Notes before you start:

- **Valet never prompts for permissions.** Screen Recording / Accessibility are granted manually in System Settings → Privacy & Security where the checklist calls for them.
- **Ad-hoc re-signing resets permission grants.** Every rebuild produces a new ad-hoc signature, which resets any Screen Recording / Accessibility grants you made in System Settings (TCC). Walk the whole checklist against the **same built bundle**; if you rebuild mid-run, re-grant permissions.
- **Reset app state** with `defaults delete app.valet.Valet` and relaunch. (A misordered or item-swallowing separator layout resets itself at the next launch — see the launch check, steps 26 and 30–32.)
- **Reset first-run onboarding** to re-test it: `defaults delete app.valet.Valet hasOnboarded` (when run from the bundle, the defaults domain is `app.valet.Valet`).
- Quit between scenarios with `pkill -x Valet` or the right-click → Quit Valet menu.

## App skeleton (Task 1)

1. Launch `build/Valet.app`: the Valet button (⋯) appears in the menu bar and **no Dock icon** appears.
2. `codesign -dv build/Valet.app` reports `Signature=adhoc`.

## Control items, hide/show, auto-rehide (Task 5)

3. On first launch, the Valet button appears and both `|` separators spawn at the far left — the hidden zones start empty and every item is Shown. The bar starts revealed for under a second (the launch check), then collapses.
4. Option-click the Valet button to reveal everything (so both `|` separators are on screen), then Cmd-drag a third-party menu bar icon **between the two `|` separators**.
5. Click the Valet button: hidden items appear and the ⋯ becomes a circled ⋯. Click again: they hide.
6. Option-click the Valet button: always-hidden items also appear.
7. Reveal and wait 15 seconds (default delay): the bar auto-collapses.
8. Right-click the Valet button: a menu appears with "Show All Items" (reveals the Always Hidden zone too), "Settings…" (opens the settings window), and "Quit Valet" (quits the app).

## Settings window + Behavior tab + launch at login (Task 10)

9. Right-click the Valet button → "Settings…" opens the settings window with 4 tabs: Items, Behavior, Hotkeys, About.
10. Behavior tab: the auto-rehide toggle and delay stepper work, and changed values persist across relaunch.
11. Launch at login toggle: when the app is **not** in /Applications, toggling it on shows an error message and the toggle reverts. (With the app in /Applications, the toggle sticks and registers with `SMAppService`.)

## Items tab — icons, drag-to-assign, real moves (Task 11)

12. Open Settings → Items **without** Screen Recording granted: rows show each owning app's icon plus its name (no banner, no prompt).
13. Grant Screen Recording manually in System Settings → Privacy & Security (Valet never prompts), then relaunch: real item icons appear in the list.
14. Capture behavior for a **hidden** item: while the bar is collapsed, check a Hidden-section row in the Items tab. Off-screen items may show a generic icon rather than their real image — this is a known limitation; observe and note the actual behavior.
15. Grant Accessibility manually in System Settings, then drag an item row from Shown to Hidden: the real menu bar icon physically moves left of the `|` separator, and after a relaunch it is hidden again (see step 26).
16. Right-click an item row → "Move to Always Hidden": works the same way (icon moves left of the leftmost separator).
17. **Without** Accessibility: moving an item shows the orange guidance message and still saves the assignment.
18. With the Hidden section **empty** (the two separators adjacent), use the Items tab to move an item to Hidden: a plain click on the Valet button reveals it (regression check for the drag-planner clamp — the item must land between the separators, not in Always Hidden).

## Hotkeys tab, onboarding (Task 12)

19. Reset onboarding (`defaults delete app.valet.Valet hasOnboarded`) and relaunch: settings opens on the Items tab, and no permission prompt appears at any point — Valet never asks.
20. Hotkeys tab → Record → press ⌥⌘B: the recorder shows "⌥⌘B". Press the hotkey while another app is frontmost: hidden items toggle.
21. Clear the hotkey: pressing ⌥⌘B no longer toggles.
22. Record the hotkey again and relaunch: the hotkey persists and still works.

## About tab + update check (Task 13)

23. About tab shows the app version (0.1.0).
24. Click "Check for Updates": it returns the "Couldn't check" message gracefully (repo not published yet). No update request ever fires without a click.

## Cross-cutting

25. **Multi-display:** on a second display (if available), the Valet button and separators replicate, and toggling works there too.
26. **Relaunch persistence:** the recorded hotkey, behavior settings (auto-rehide, delay, launch at login), section assignments, and the hidden arrangement itself all survive quitting and relaunching — items you hid stay hidden, provided every hidden-zone item is there by your recorded assignment (otherwise see step 32).
27. **Permission-revoked degradation:** with both permissions granted and the app running, revoke Screen Recording and Accessibility in System Settings → Privacy & Security. The app must not crash: the Items tab falls back to owning-app icons, and moving items shows the orange guidance message while still saving assignments.
28. **Items list stability (regression):** open Settings → Items, then (a) leave the bar collapsed with at least one item assigned to Hidden, and (b) put another app into full screen and come back. In both cases, wait at least 10 seconds: no rows may disappear from the list. (Regression check for the on-screen-only enumeration bug that emptied the list whenever the menu bar wasn't displayed.)
29. **New-item rescue:** with Accessibility granted and Valet collapsed, quit and relaunch a menu bar app (or launch one you don't have running). macOS spawns its icon into the hidden zone; within ~10 seconds Valet must move it into the visible Shown strip (the bar flashes briefly during the rescue). Without Accessibility, the icon stays hidden but remains listed in Settings → Items and is revealed by Option-clicking the Valet button. Either way, the item must **not** be auto-assigned to a hidden section — hidden assignments happen only when Valet watches you drag an item there.
30. **Fresh launch, busy menu bar:** with plenty of third-party menu bar apps running and no assignments saved, launch Valet fresh (`defaults delete app.valet.Valet`): every third-party item stays visible — nothing starts the session swallowed into a hidden zone.
31. **Show All Items:** with items in the Always Hidden zone, right-click the Valet button → "Show All Items": the Always Hidden zone is revealed (same effect as Option-clicking the button).
32. **Launch-swallow regression:** Cmd-drag an item to Hidden, quit Valet, launch a new menu bar app (macOS spawns its icon at the far left), then relaunch Valet: every item — including the new one — is visible, and the new app gets no hidden assignment. Relaunching Valet must never make an item disappear.

## Separator order guard — chevron protection (Task: separator-order-guard)

Requires a fresh build (`Scripts/make-app.sh --install`) so TCC grants are known.

33. **Pre-empt while revealed (Accessibility granted):** reveal the bar, then Cmd-drag the `|` hidden separator to the RIGHT of the ⋯ chevron. Within ~5 seconds the bar self-corrects: the separator returns to the left of the chevron, the arrangement is preserved, and the chevron stays clickable throughout.
34. **Self-recover from the stuck state:** Cmd-drag the hidden separator right of the chevron, then immediately collapse (click the chevron or wait for auto-rehide) so the chevron is pushed off-screen. Within ~5 seconds the guard reveals the bar, moves the separator back, and re-collapses — no user action needed, and the chevron is usable again.
35. **Degrade without Accessibility:** revoke Accessibility for Valet in System Settings → Privacy & Security, then repeat step 33. The separators reset to the far left, a guidance message appears in Settings, and the app stays usable (the session starts all-Shown). No permission prompt is ever triggered.
36. **No false positives:** with a healthy layout, confirm the bar does NOT flicker or reveal itself during normal use over a minute or two of idling.
