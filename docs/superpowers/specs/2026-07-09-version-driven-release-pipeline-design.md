# VERSION-driven release pipeline — design

**Date:** 2026-07-09
**Status:** Approved
**Scope:** Automate tagging + GitHub Release on merge to `master`, gated by a `VERSION` file, with a single source of truth for the app version and a maintained `CHANGELOG.md`.

## Goal

When work merges to `master`, cut a tagged GitHub Release **only when the release is intended** — signalled by bumping the `VERSION` file. Merges that do not change `VERSION` (docs, chores, refactors) must not release. The version the app reports (and the update checker compares against) must never drift from `VERSION`.

## Decisions (locked)

1. **Trigger = VERSION file bump.** CI reads `VERSION` on every push to `master`. If tag `v<VERSION>` does not yet exist → build, tag, release. If it already exists → no-op.
2. **Single source of truth.** `VERSION` is the only file a human edits for versioning. `Info.plist` and `UpdateChecker` derive from it.
3. **CHANGELOG.md maintained.** Release notes come from the CHANGELOG section for the version being released.

## Components

### 1. `VERSION` file (repo root)
- Plain text, single line, semver without a leading `v`. Initial contents: `0.1.0`.
- The one file a human edits to ship a release.

### 2. `Scripts/make-app.sh` (modified)
- After copying `Resources/Info.plist` into the bundle, read `VERSION` and stamp the bundle's Info.plist:
  - `CFBundleShortVersionString` ← contents of `VERSION`.
  - `CFBundleVersion` ← `$GITHUB_RUN_NUMBER` when set (CI), else `1` (local).
- Use `/usr/libexec/PlistBuddy -c "Set :CFBundleShortVersionString <v>" "$APP/Contents/Info.plist"`.
- Only the **bundle copy** is modified; the committed `Resources/Info.plist` keeps a placeholder value and is never rewritten by the build.
- Existing behaviour (`--universal`, `--install`, ad-hoc signing) is unchanged.

### 3. `Resources/Info.plist` (modified)
- `CFBundleShortVersionString` set to a stable placeholder (`0.0.0`) to make explicit that the real value is injected at build time. It is never the source of truth.

### 4. `Sources/Valet/Settings/UpdateChecker.swift` (modified)
- Replace `static let currentVersion = "0.1.0"` with a computed value read from the bundle:
  ```swift
  static var currentVersion: String {
      (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String) ?? "0.0.0"
  }
  ```
- Rationale: when launched from the built bundle, this reflects the injected `VERSION`. The `"0.0.0"` fallback covers non-bundle contexts (`swift run`, unit tests) and is harmless — it would only ever report "update available", never suppress a real update.
- `SemVer` and the network `check()` logic are unchanged. Existing tests exercise `SemVer` directly, not `currentVersion`, so they are unaffected.

### 5. `CHANGELOG.md` (new, repo root)
- [Keep a Changelog](https://keepachangelog.com) format, newest first.
- Sections keyed by version heading: `## [0.1.0] - 2026-07-09`.
- Seeded with a `0.1.0` entry describing the Phase 1 feature set.
- Editing the changelog is part of the same PR that bumps `VERSION`.

### 6. `.github/workflows/release.yml` (new)
- Runner: `macos-14`. Toolchain: Xcode Command Line Tools (preinstalled on the runner; `swift` available).
- `permissions: contents: write` (needed to push tags and create releases; uses the built-in `GITHUB_TOKEN`).
- `concurrency: { group: release-master, cancel-in-progress: false }` so two quick merges serialize rather than race on tag creation.

**Trigger `pull_request` → `master`** — job `test`:
1. Checkout.
2. `swift test`.
- No release side effects. This is the automated correctness gate.

**Trigger `push` → `master`** — job `release`:
1. Checkout with full history and tags (`fetch-depth: 0`).
2. `swift test` (gate — release aborts if tests fail).
3. `VERSION=$(cat VERSION)`.
4. **Idempotency guard:** if `git rev-parse "v$VERSION"` succeeds (tag exists) → log "v$VERSION already released, skipping" and exit 0. This is what makes non-bump merges no-ops.
5. `Scripts/make-app.sh --universal`.
6. Package: `ditto -c -k --keepParent build/Valet.app "Valet-$VERSION.zip"` (preserves the ad-hoc signature and bundle layout; `zip` does not).
7. Extract release notes: the `## [<VERSION>]` section body from `CHANGELOG.md`. If that section is missing, fall back to `--generate-notes`. Append the standard install note (unzip → move to `/Applications` → right-click → Open, because the app is unsigned/not notarized).
8. Create and push the annotated tag: `git tag -a "v$VERSION" -m "Valet v$VERSION"` then `git push origin "v$VERSION"`.
9. `gh release create "v$VERSION" "Valet-$VERSION.zip" --title "Valet v$VERSION" --latest --notes-file <notes>`.
   - `--latest` and a non-prerelease release are required so the app's `GET /releases/latest` update check sees it.

## Data flow

```
edit VERSION + CHANGELOG.md in a PR
   └─ PR CI: swift test (gate)
merge to master (push event)
   └─ release job:
        swift test
        VERSION=$(cat VERSION)
        tag v$VERSION exists? ── yes ──▶ exit 0 (no release)
                              └─ no ──▶ build --universal
                                        ditto → Valet-$VERSION.zip
                                        notes ← CHANGELOG [$VERSION]
                                        tag v$VERSION + push
                                        gh release create --latest
runtime: UpdateChecker.currentVersion
   = Bundle.main[CFBundleShortVersionString]   (injected from VERSION at build)
```

## Error handling / edge cases

- **Tests fail on master push:** release job aborts before any tag/release is created. No partial release.
- **VERSION unchanged since last release:** tag exists → step 4 exits cleanly. Common case for docs/chore merges.
- **VERSION malformed (not semver):** `SemVer(tag)` would reject it in the app; the workflow still tags/releases whatever string is in VERSION. Mitigation: a lightweight regex check (`^[0-9]+\.[0-9]+\.[0-9]+$`) at the top of the release job that fails fast with a clear message.
- **CHANGELOG section missing for VERSION:** fall back to `--generate-notes` so the release still publishes; not a hard failure.
- **Non-bundle runtime (tests, `swift run`):** `currentVersion` falls back to `0.0.0`; acceptable per component 4.
- **Manual first release:** current source is `0.1.0` and untagged. The first merge carrying a `VERSION` file cuts `v0.1.0`. TESTING.md must be walked before that merge.

## What CI does NOT cover

- **TESTING.md is manual.** It needs Screen Recording, Accessibility, live menu bar interaction, and multi-display — none runnable in CI. CI's automated gate is `swift test` only. The release discipline remains: **walk TESTING.md before bumping `VERSION`.** This is a deliberate, documented gap, not an oversight.

## Testing / verification

- `swift test` passes locally and in CI unchanged.
- Local `Scripts/make-app.sh` then `defaults read` / `PlistBuddy -c "Print CFBundleShortVersionString"` on `build/Valet.app` shows the `VERSION` value.
- Launch the built bundle → Settings → About shows the `VERSION` value (confirms `UpdateChecker.currentVersion` wiring end to end).
- Dry-run the idempotency guard: re-running the release logic when `v<VERSION>` already exists is a clean no-op.
- First real run: merge a VERSION-bearing PR, confirm `v0.1.0` release appears as **Latest**, and the app's "Check for Updates" returns "up to date".

## Out of scope (YAGNI)

- Notarization / Developer ID signing (project intentionally ships ad-hoc signed).
- Conventional-commit or auto-bump versioning.
- Homebrew cask / auto-update download+install (manual update check stays manual).
