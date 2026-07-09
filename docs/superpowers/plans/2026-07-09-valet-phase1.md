# Valet Phase 1 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Ship Valet V1 — an open-source macOS menu bar manager that hides/shows menu bar items with three sections (Shown / Hidden / Always Hidden), a settings UI with real item introspection, global hotkey, auto-rehide, launch at login, and a manual-only update check.

**Architecture:** Menu-bar-only AppKit app with SwiftUI settings window. Hiding uses the expanding-spacer technique (our separator status items grow to 10,000 pt to push items off-screen). Item introspection via `CGWindowListCopyWindowInfo`; item images via ScreenCaptureKit; items are moved between sections by synthesizing Cmd-drag mouse events. All pure logic (visibility state machine, reconciliation, drag planning, settings persistence, version comparison) is TDD'd; AppKit/permission-gated behavior is verified via a manual checklist.

**Tech Stack:** Swift 6.1 (language mode 5), Swift Package Manager (NO Xcode project — this machine has Command Line Tools only; `xcodebuild` does not exist here), Swift Testing (`import Testing`), AppKit + SwiftUI + ScreenCaptureKit + ServiceManagement + Carbon.HIToolbox. Zero third-party dependencies.

## Global Constraints

- macOS 14 (Sonoma) minimum: `platforms: [.macOS(.v14)]`.
- Zero third-party dependencies in Phase 1.
- The ONLY network code in the app lives in `Sources/Valet/Settings/UpdateChecker.swift` and runs ONLY when the user clicks "Check for Updates".
- No PII: persist only item keys (bundle IDs + index), section assignments, and behavior prefs via `UserDefaults`. Captured images stay in memory; never write them to disk.
- App name is "Valet". Never use the name "Bartender", its icon, or its marketing copy anywhere in code, UI strings, or docs.
- No App Sandbox (required for CGWindowList + synthesized events). Ad-hoc codesigning (`codesign -s -`) only; no developer account.
- Build/test commands: `swift build`, `swift test`, `Scripts/make-app.sh`. Never `xcodebuild`.
- Every task that completes a FEATURES.md line item updates its checkbox from `[ ]`/`[~]` to `[x]` in the same commit.
- Commit messages end with: `Co-Authored-By: Claude Fable 5 <noreply@anthropic.com>`

---

### Task 1: Package scaffold, app skeleton, bundle script

**Files:**
- Create: `Package.swift`
- Create: `Sources/Valet/ValetApp.swift`
- Create: `Resources/Info.plist`
- Create: `Scripts/make-app.sh`
- Create: `LICENSE`
- Modify: `.gitignore`

**Interfaces:**
- Consumes: nothing (first task).
- Produces: `AppDelegate: NSObject, NSApplicationDelegate` in `ValetApp.swift` — later tasks add properties/wiring inside `applicationDidFinishLaunching(_:)`. Executable target named `Valet`, test target `ValetTests`.

- [ ] **Step 1: Write Package.swift**

```swift
// swift-tools-version: 6.1
import PackageDescription

let package = Package(
    name: "Valet",
    platforms: [.macOS(.v14)],
    targets: [
        .executableTarget(
            name: "Valet",
            path: "Sources/Valet",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "ValetTests",
            dependencies: ["Valet"],
            path: "Tests/ValetTests",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
```

- [ ] **Step 2: Write the app entry point**

`Sources/Valet/ValetApp.swift`:

```swift
import AppKit

@main
enum ValetMain {
    static let appDelegate = AppDelegate()

    static func main() {
        let app = NSApplication.shared
        app.delegate = appDelegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(
            systemSymbolName: "chevron.left",
            accessibilityDescription: "Valet"
        )
        statusItem = item
    }
}
```

(The placeholder status item is replaced by `MenuBarManager` in Task 5.)

- [ ] **Step 3: Write Resources/Info.plist**

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleExecutable</key>
	<string>Valet</string>
	<key>CFBundleIdentifier</key>
	<string>app.valet.Valet</string>
	<key>CFBundleName</key>
	<string>Valet</string>
	<key>CFBundlePackageType</key>
	<string>APPL</string>
	<key>CFBundleShortVersionString</key>
	<string>0.1.0</string>
	<key>CFBundleVersion</key>
	<string>1</string>
	<key>LSMinimumSystemVersion</key>
	<string>14.0</string>
	<key>LSUIElement</key>
	<true/>
	<key>NSHighResolutionCapable</key>
	<true/>
</dict>
</plist>
```

- [ ] **Step 4: Write Scripts/make-app.sh**

```bash
#!/bin/bash
# Assembles Valet.app from the SPM build product and ad-hoc signs it.
# Usage: Scripts/make-app.sh [--universal]
set -euo pipefail
cd "$(dirname "$0")/.."

if [[ "${1:-}" == "--universal" ]]; then
    swift build -c release --arch arm64 --arch x86_64
    BIN=".build/apple/Products/Release/Valet"
else
    swift build -c release
    BIN=".build/release/Valet"
fi

APP="build/Valet.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources"
cp "$BIN" "$APP/Contents/MacOS/Valet"
cp Resources/Info.plist "$APP/Contents/Info.plist"
codesign --force -s - "$APP"
echo "Built $APP"
```

Then: `chmod +x Scripts/make-app.sh`

- [ ] **Step 5: Write LICENSE (MIT) and update .gitignore**

`LICENSE`: standard MIT license text with the line `Copyright (c) 2026 Valet contributors`.

Append to `.gitignore`:

```
.build/
```

- [ ] **Step 6: Verify build and bundle**

Run: `swift build && Scripts/make-app.sh && codesign -dv build/Valet.app 2>&1 | head -3`
Expected: `Build complete!`, `Built build/Valet.app`, codesign output showing `Signature=adhoc`.

- [ ] **Step 7: Manual smoke test**

Run: `open build/Valet.app`, confirm a chevron icon appears in the menu bar and no Dock icon appears. Quit via Activity Monitor or `pkill Valet`.

- [ ] **Step 8: Commit**

```bash
git add Package.swift Sources Resources Scripts LICENSE .gitignore
git commit -m "feat: scaffold Valet app skeleton with SPM and bundle script"
```

---

### Task 2: BarSection, Hotkey, SettingsStore (TDD)

**Files:**
- Create: `Sources/Valet/Settings/BarSection.swift`
- Create: `Sources/Valet/Settings/Hotkey.swift`
- Create: `Sources/Valet/Settings/SettingsStore.swift`
- Test: `Tests/ValetTests/SettingsStoreTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum BarSection: String, Codable, CaseIterable, Equatable { case shown, hidden, alwaysHidden }` with `var displayName: String`.
  - `struct Hotkey: Codable, Equatable { var keyCode: UInt32; var carbonModifiers: UInt32 }`.
  - `final class SettingsStore: ObservableObject` with `init(defaults: UserDefaults)`, `@Published var assignments: [String: BarSection]`, `@Published var autoRehide: Bool` (default `true`), `@Published var rehideDelay: TimeInterval` (default `15`), `@Published var toggleHotkey: Hotkey?` (default `nil`). All persist on set, restore on init.

- [ ] **Step 1: Write the failing tests**

`Tests/ValetTests/SettingsStoreTests.swift`:

```swift
import Foundation
import Testing
@testable import Valet

private func freshDefaults() -> UserDefaults {
    let suite = "ValetTests-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}

@Suite struct SettingsStoreTests {
    @Test func defaultsOnFirstLaunch() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.assignments.isEmpty)
        #expect(store.autoRehide == true)
        #expect(store.rehideDelay == 15)
        #expect(store.toggleHotkey == nil)
    }

    @Test func persistsAndRestores() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.assignments = ["com.example.app#0": .hidden]
        store.autoRehide = false
        store.rehideDelay = 30
        store.toggleHotkey = Hotkey(keyCode: 11, carbonModifiers: 256)

        let restored = SettingsStore(defaults: defaults)
        #expect(restored.assignments == ["com.example.app#0": .hidden])
        #expect(restored.autoRehide == false)
        #expect(restored.rehideDelay == 30)
        #expect(restored.toggleHotkey == Hotkey(keyCode: 11, carbonModifiers: 256))
    }

    @Test func sectionDisplayNames() {
        #expect(BarSection.shown.displayName == "Shown")
        #expect(BarSection.hidden.displayName == "Hidden")
        #expect(BarSection.alwaysHidden.displayName == "Always Hidden")
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SettingsStoreTests`
Expected: build failure — `cannot find 'SettingsStore' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/Valet/Settings/BarSection.swift`:

```swift
enum BarSection: String, Codable, CaseIterable, Equatable {
    case shown
    case hidden
    case alwaysHidden

    var displayName: String {
        switch self {
        case .shown: return "Shown"
        case .hidden: return "Hidden"
        case .alwaysHidden: return "Always Hidden"
        }
    }
}
```

`Sources/Valet/Settings/Hotkey.swift`:

```swift
struct Hotkey: Codable, Equatable {
    var keyCode: UInt32
    var carbonModifiers: UInt32
}
```

`Sources/Valet/Settings/SettingsStore.swift`:

```swift
import Foundation

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let assignments = "assignments"
        static let autoRehide = "autoRehide"
        static let rehideDelay = "rehideDelay"
        static let toggleHotkey = "toggleHotkey"
    }

    private let defaults: UserDefaults

    @Published var assignments: [String: BarSection] {
        didSet { saveJSON(assignments, key: Keys.assignments) }
    }
    @Published var autoRehide: Bool {
        didSet { defaults.set(autoRehide, forKey: Keys.autoRehide) }
    }
    @Published var rehideDelay: TimeInterval {
        didSet { defaults.set(rehideDelay, forKey: Keys.rehideDelay) }
    }
    @Published var toggleHotkey: Hotkey? {
        didSet { saveJSON(toggleHotkey, key: Keys.toggleHotkey) }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.assignments = Self.loadJSON([String: BarSection].self, key: Keys.assignments, defaults: defaults) ?? [:]
        self.autoRehide = defaults.object(forKey: Keys.autoRehide) as? Bool ?? true
        self.rehideDelay = defaults.object(forKey: Keys.rehideDelay) as? TimeInterval ?? 15
        self.toggleHotkey = Self.loadJSON(Hotkey.self, key: Keys.toggleHotkey, defaults: defaults)
    }

    private func saveJSON<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SettingsStoreTests`
Expected: all 3 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Valet/Settings Tests/ValetTests/SettingsStoreTests.swift
git commit -m "feat: add BarSection, Hotkey, and persisted SettingsStore"
```

---

### Task 3: MenuBarItemInfo, item keys, reconciliation (TDD)

**Files:**
- Create: `Sources/Valet/Introspection/MenuBarItemInfo.swift`
- Create: `Sources/Valet/Introspection/Reconciler.swift`
- Test: `Tests/ValetTests/ReconcilerTests.swift`

**Interfaces:**
- Consumes: `BarSection` (Task 2).
- Produces:
  - `struct MenuBarItemInfo: Equatable, Identifiable` with `windowID: UInt32`, `ownerPID: pid_t`, `ownerName: String`, `bundleID: String?`, `frame: CGRect`, `key: String` (empty until keyed), `var id: String { key.isEmpty ? String(windowID) : key }`, `var ownerIdentity: String { bundleID ?? ownerName }`.
  - `func keyedItems(_ items: [MenuBarItemInfo]) -> [MenuBarItemInfo]` — returns items sorted left-to-right with `key` = `"<ownerIdentity>#<index>"` where index is the item's left-to-right position among its owner's items.
  - `func reconcile(assignments: [String: BarSection], items: [MenuBarItemInfo]) -> [(item: MenuBarItemInfo, section: BarSection)]` — keys items, looks up each key, defaults to `.shown`. Never mutates or drops assignments.

- [ ] **Step 1: Write the failing tests**

`Tests/ValetTests/ReconcilerTests.swift`:

```swift
import Foundation
import Testing
@testable import Valet

private func item(_ windowID: UInt32, bundle: String?, owner: String = "App", x: CGFloat) -> MenuBarItemInfo {
    MenuBarItemInfo(
        windowID: windowID, ownerPID: 100, ownerName: owner,
        bundleID: bundle, frame: CGRect(x: x, y: 0, width: 30, height: 24), key: ""
    )
}

@Suite struct ReconcilerTests {
    @Test func keysSingleItemPerApp() {
        let keyed = keyedItems([item(1, bundle: "com.a", x: 50), item(2, bundle: "com.b", x: 10)])
        #expect(keyed.map(\.key) == ["com.b#0", "com.a#0"])  // sorted left-to-right
    }

    @Test func keysMultipleItemsFromOneAppByPosition() {
        let keyed = keyedItems([item(1, bundle: "com.a", x: 200), item(2, bundle: "com.a", x: 100)])
        #expect(keyed.map(\.key) == ["com.a#0", "com.a#1"])
        #expect(keyed[0].windowID == 2)  // leftmost gets index 0
    }

    @Test func fallsBackToOwnerNameWithoutBundleID() {
        let keyed = keyedItems([item(1, bundle: nil, owner: "SomeTool", x: 10)])
        #expect(keyed[0].key == "SomeTool#0")
    }

    @Test func reconcileAssignsSavedSectionsAndDefaultsToShown() {
        let items = [item(1, bundle: "com.a", x: 10), item(2, bundle: "com.b", x: 50)]
        let result = reconcile(assignments: ["com.a#0": .alwaysHidden], items: items)
        #expect(result.count == 2)
        #expect(result[0].section == .alwaysHidden)
        #expect(result[1].section == .shown)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ReconcilerTests`
Expected: build failure — `cannot find 'MenuBarItemInfo' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/Valet/Introspection/MenuBarItemInfo.swift`:

```swift
import Foundation

struct MenuBarItemInfo: Equatable, Identifiable {
    let windowID: UInt32
    let ownerPID: pid_t
    let ownerName: String
    let bundleID: String?
    let frame: CGRect
    var key: String

    var id: String { key.isEmpty ? String(windowID) : key }
    var ownerIdentity: String { bundleID ?? ownerName }
}
```

`Sources/Valet/Introspection/Reconciler.swift`:

```swift
import Foundation

func keyedItems(_ items: [MenuBarItemInfo]) -> [MenuBarItemInfo] {
    let sorted = items.sorted { $0.frame.minX < $1.frame.minX }
    var perOwnerCount: [String: Int] = [:]
    return sorted.map { item in
        var keyed = item
        let index = perOwnerCount[item.ownerIdentity, default: 0]
        keyed.key = "\(item.ownerIdentity)#\(index)"
        perOwnerCount[item.ownerIdentity] = index + 1
        return keyed
    }
}

func reconcile(
    assignments: [String: BarSection],
    items: [MenuBarItemInfo]
) -> [(item: MenuBarItemInfo, section: BarSection)] {
    keyedItems(items).map { ($0, assignments[$0.key] ?? .shown) }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ReconcilerTests`
Expected: all 4 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Valet/Introspection Tests/ValetTests/ReconcilerTests.swift
git commit -m "feat: add menu bar item model, keying, and reconciliation"
```

---

### Task 4: VisibilityEngine state machine (TDD)

**Files:**
- Create: `Sources/Valet/Layout/VisibilityEngine.swift`
- Test: `Tests/ValetTests/VisibilityEngineTests.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum RevealState: String, Equatable { case collapsed, revealed, revealedAll }`
  - `struct SpacerLengths: Equatable { var hidden: CGFloat; var alwaysHidden: CGFloat }`
  - `struct VisibilityEngine: Equatable` with `static let expandedLength: CGFloat = 10_000`, `static let separatorLength: CGFloat = 8`, `private(set) var state: RevealState` (initial `.collapsed`), `mutating func toggle()`, `mutating func toggleAll()`, `mutating func collapse()`, `var spacerLengths: SpacerLengths`, `func rehideDeadline(now: Date, delay: TimeInterval, autoRehide: Bool) -> Date?`.

- [ ] **Step 1: Write the failing tests**

`Tests/ValetTests/VisibilityEngineTests.swift`:

```swift
import Foundation
import Testing
@testable import Valet

@Suite struct VisibilityEngineTests {
    @Test func startsCollapsedWithBothSpacersExpanded() {
        let engine = VisibilityEngine()
        #expect(engine.state == .collapsed)
        #expect(engine.spacerLengths == SpacerLengths(hidden: 10_000, alwaysHidden: 10_000))
    }

    @Test func toggleRevealsHiddenButNotAlwaysHidden() {
        var engine = VisibilityEngine()
        engine.toggle()
        #expect(engine.state == .revealed)
        #expect(engine.spacerLengths == SpacerLengths(hidden: 8, alwaysHidden: 10_000))
        engine.toggle()
        #expect(engine.state == .collapsed)
    }

    @Test func toggleAllRevealsEverything() {
        var engine = VisibilityEngine()
        engine.toggleAll()
        #expect(engine.state == .revealedAll)
        #expect(engine.spacerLengths == SpacerLengths(hidden: 8, alwaysHidden: 8))
        engine.toggleAll()
        #expect(engine.state == .collapsed)
    }

    @Test func toggleFromRevealedAllCollapses() {
        var engine = VisibilityEngine()
        engine.toggleAll()
        engine.toggle()
        #expect(engine.state == .collapsed)
    }

    @Test func rehideDeadlineOnlyWhenRevealedAndEnabled() {
        var engine = VisibilityEngine()
        let now = Date(timeIntervalSince1970: 1000)
        #expect(engine.rehideDeadline(now: now, delay: 15, autoRehide: true) == nil)
        engine.toggle()
        #expect(engine.rehideDeadline(now: now, delay: 15, autoRehide: true)
            == Date(timeIntervalSince1970: 1015))
        #expect(engine.rehideDeadline(now: now, delay: 15, autoRehide: false) == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter VisibilityEngineTests`
Expected: build failure — `cannot find 'VisibilityEngine' in scope`.

- [ ] **Step 3: Write the implementation**

`Sources/Valet/Layout/VisibilityEngine.swift`:

```swift
import Foundation

enum RevealState: String, Equatable {
    case collapsed
    case revealed
    case revealedAll
}

struct SpacerLengths: Equatable {
    var hidden: CGFloat
    var alwaysHidden: CGFloat
}

struct VisibilityEngine: Equatable {
    static let expandedLength: CGFloat = 10_000
    static let separatorLength: CGFloat = 8

    private(set) var state: RevealState = .collapsed

    mutating func toggle() {
        state = (state == .collapsed) ? .revealed : .collapsed
    }

    mutating func toggleAll() {
        state = (state == .revealedAll) ? .collapsed : .revealedAll
    }

    mutating func collapse() {
        state = .collapsed
    }

    var spacerLengths: SpacerLengths {
        switch state {
        case .collapsed:
            return SpacerLengths(hidden: Self.expandedLength, alwaysHidden: Self.expandedLength)
        case .revealed:
            return SpacerLengths(hidden: Self.separatorLength, alwaysHidden: Self.expandedLength)
        case .revealedAll:
            return SpacerLengths(hidden: Self.separatorLength, alwaysHidden: Self.separatorLength)
        }
    }

    func rehideDeadline(now: Date, delay: TimeInterval, autoRehide: Bool) -> Date? {
        guard autoRehide, state != .collapsed else { return nil }
        return now.addingTimeInterval(delay)
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter VisibilityEngineTests`
Expected: all 5 tests PASS.

- [ ] **Step 5: Commit**

```bash
git add Sources/Valet/Layout Tests/ValetTests/VisibilityEngineTests.swift
git commit -m "feat: add visibility state machine with spacer lengths and rehide deadline"
```

---

### Task 5: MenuBarManager — control items, hide/show, auto-rehide

**Files:**
- Create: `Sources/Valet/MenuBar/MenuBarManager.swift`
- Modify: `Sources/Valet/ValetApp.swift` (replace placeholder status item)

**Interfaces:**
- Consumes: `VisibilityEngine`, `SpacerLengths`, `RevealState` (Task 4); `SettingsStore` (Task 2).
- Produces: `@MainActor final class MenuBarManager` with:
  - `init(store: SettingsStore)`
  - `func toggle()`, `func toggleAll()`, `func collapse()` — mutate engine, apply lengths, restart rehide timer.
  - `var onOpenSettings: (() -> Void)?` — called from the right-click menu item "Settings…".
  - `var separatorWindowIDs: (hidden: UInt32?, alwaysHidden: UInt32?)` — window numbers of the two separator items (used by Task 8's drag planning).
  - `func revealAllTemporarily()` / `func endTemporaryReveal()` — used by Task 11 during drag-move orchestration.

- [ ] **Step 1: Write MenuBarManager**

`Sources/Valet/MenuBar/MenuBarManager.swift`:

```swift
import AppKit

@MainActor
final class MenuBarManager {
    private let store: SettingsStore
    private var engine = VisibilityEngine()
    private var rehideTimer: Timer?
    private var stateBeforeTemporaryReveal: RevealState?

    private var chevronItem: NSStatusItem!
    private var hiddenSeparator: NSStatusItem!
    private var alwaysHiddenSeparator: NSStatusItem!

    var onOpenSettings: (() -> Void)?

    var separatorWindowIDs: (hidden: UInt32?, alwaysHidden: UInt32?) {
        (windowID(of: hiddenSeparator), windowID(of: alwaysHiddenSeparator))
    }

    init(store: SettingsStore) {
        self.store = store
        // Creation order matters: newer status items appear further LEFT,
        // so create chevron first -> [alwaysHiddenSep][hiddenSep][chevron].
        chevronItem = makeChevron()
        hiddenSeparator = makeSeparator(autosaveName: "valet-hidden-separator")
        alwaysHiddenSeparator = makeSeparator(autosaveName: "valet-always-hidden-separator")
        apply()
    }

    func toggle() {
        engine.toggle()
        apply()
    }

    func toggleAll() {
        engine.toggleAll()
        apply()
    }

    func collapse() {
        engine.collapse()
        apply()
    }

    func revealAllTemporarily() {
        guard stateBeforeTemporaryReveal == nil else { return }
        stateBeforeTemporaryReveal = engine.state
        engine.toggleAll()
        if engine.state != .revealedAll { engine.toggleAll() }
        apply()
    }

    func endTemporaryReveal() {
        guard let previous = stateBeforeTemporaryReveal else { return }
        stateBeforeTemporaryReveal = nil
        switch previous {
        case .collapsed:
            engine.collapse()
        case .revealed:
            engine.collapse()
            engine.toggle()  // collapsed -> revealed
        case .revealedAll:
            break  // already in .revealedAll
        }
        apply()
    }

    // MARK: - Private

    private func makeChevron() -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.autosaveName = "valet-chevron"
        if let button = item.button {
            button.target = self
            button.action = #selector(chevronClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }
        return item
    }

    private func makeSeparator(autosaveName: String) -> NSStatusItem {
        let item = NSStatusBar.system.statusItem(withLength: VisibilityEngine.separatorLength)
        item.autosaveName = NSStatusItem.AutosaveName(autosaveName)
        item.button?.title = "|"
        item.button?.appearsDisabled = true
        return item
    }

    @objc private func chevronClicked() {
        guard let event = NSApp.currentEvent else { return toggle() }
        if event.type == .rightMouseUp {
            showMenu()
        } else if event.modifierFlags.contains(.option) {
            toggleAll()
        } else {
            toggle()
        }
    }

    private func showMenu() {
        let menu = NSMenu()
        let settings = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: ",")
        settings.target = self
        menu.addItem(settings)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit Valet", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))
        chevronItem.menu = menu
        chevronItem.button?.performClick(nil)
        chevronItem.menu = nil  // so left-click keeps toggling
    }

    @objc private func openSettings() {
        onOpenSettings?()
    }

    private func apply() {
        let lengths = engine.spacerLengths
        hiddenSeparator.length = lengths.hidden
        alwaysHiddenSeparator.length = lengths.alwaysHidden
        chevronItem.button?.image = NSImage(
            systemSymbolName: engine.state == .collapsed ? "chevron.left" : "chevron.right",
            accessibilityDescription: "Valet"
        )
        scheduleRehide()
    }

    private func scheduleRehide() {
        rehideTimer?.invalidate()
        rehideTimer = nil
        guard stateBeforeTemporaryReveal == nil,
              let deadline = engine.rehideDeadline(
                  now: Date(), delay: store.rehideDelay, autoRehide: store.autoRehide
              ) else { return }
        let timer = Timer(fire: deadline, interval: 0, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.collapse() }
        }
        RunLoop.main.add(timer, forMode: .common)
        rehideTimer = timer
    }

    private func windowID(of item: NSStatusItem?) -> UInt32? {
        guard let window = item?.button?.window else { return nil }
        return UInt32(window.windowNumber)
    }
}
```

- [ ] **Step 2: Wire into AppDelegate**

Replace the body of `AppDelegate` in `Sources/Valet/ValetApp.swift`:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var settingsStore: SettingsStore!
    private(set) var menuBarManager: MenuBarManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore(defaults: .standard)
        menuBarManager = MenuBarManager(store: settingsStore)
    }
}
```

- [ ] **Step 3: Build and run tests**

Run: `swift build && swift test`
Expected: build succeeds, all existing tests still PASS.

- [ ] **Step 4: Manual verification checklist**

Run: `Scripts/make-app.sh && open build/Valet.app`, then verify:
1. Chevron + one visible `|` separator appear (the always-hidden separator and anything left of the hidden separator are pushed off-screen — collapsed is the default).
2. Cmd-drag any third-party menu bar icon to the LEFT of the `|`… wait, while collapsed the separator region is off-screen; first click the chevron to reveal, then Cmd-drag an icon between the two `|` separators.
3. Click chevron → hidden items appear, chevron flips direction. Click again → they hide.
4. Option-click chevron → always-hidden items also appear.
5. Wait 15 s after revealing → auto-collapses.
6. Right-click chevron → menu with "Settings…" (does nothing yet) and "Quit Valet" (quits).
7. On a second display (if available): chevron and separators replicate; toggling works there too.

`pkill Valet` when done.

- [ ] **Step 5: Update FEATURES.md and commit**

In `FEATURES.md` mark these Phase 1 lines `[x]`: "Menu bar separator + toggle chevron control items", "Hide/show via expanding spacer", "Toggle by clicking the chevron", "Auto-rehide after configurable delay", "Multi-display basics (control items on active display)". Mark "Three sections: Shown / Hidden / Always Hidden" as `[~]` (mechanics exist; settings UI pending).

```bash
git add Sources/Valet/MenuBar Sources/Valet/ValetApp.swift FEATURES.md
git commit -m "feat: add menu bar control items with expanding-spacer hide/show and auto-rehide"
```

---

### Task 6: Window filtering + live ItemIntrospector (TDD for filter)

**Files:**
- Create: `Sources/Valet/Introspection/WindowFilter.swift`
- Create: `Sources/Valet/Introspection/ItemIntrospector.swift`
- Test: `Tests/ValetTests/WindowFilterTests.swift`

**Interfaces:**
- Consumes: `MenuBarItemInfo`, `keyedItems` (Task 3).
- Produces:
  - `func menuBarItemInfos(from raw: [[String: Any]], excludingPIDs: Set<pid_t>) -> [MenuBarItemInfo]` — pure filter over `CGWindowListCopyWindowInfo`-shaped dictionaries. Keeps windows with layer 25, y == 0, height ≤ 40, width ≤ 500, not in `excludingPIDs`. Returned items have empty `key` and `bundleID: nil` (live wrapper fills bundle IDs).
  - `@MainActor final class ItemIntrospector: ObservableObject` with `@Published private(set) var items: [MenuBarItemInfo]`, `func refresh()`, `func startAutoRefresh(interval: TimeInterval)`, `func frame(ofWindowID: UInt32) -> CGRect?`.

- [ ] **Step 1: Write the failing tests**

`Tests/ValetTests/WindowFilterTests.swift`:

```swift
import Foundation
import Testing
@testable import Valet

private func rawWindow(
    layer: Int = 25, pid: Int = 500, windowID: Int = 1,
    x: Double = 100, y: Double = 0, w: Double = 30, h: Double = 24,
    owner: String = "SomeApp"
) -> [String: Any] {
    [
        "kCGWindowLayer": layer,
        "kCGWindowOwnerPID": pid,
        "kCGWindowNumber": windowID,
        "kCGWindowOwnerName": owner,
        "kCGWindowBounds": ["X": x, "Y": y, "Width": w, "Height": h],
    ]
}

@Suite struct WindowFilterTests {
    @Test func keepsStatusItemWindows() {
        let infos = menuBarItemInfos(from: [rawWindow()], excludingPIDs: [])
        #expect(infos.count == 1)
        #expect(infos[0].windowID == 1)
        #expect(infos[0].ownerName == "SomeApp")
        #expect(infos[0].frame == CGRect(x: 100, y: 0, width: 30, height: 24))
    }

    @Test func rejectsWrongLayer() {
        let infos = menuBarItemInfos(from: [rawWindow(layer: 0)], excludingPIDs: [])
        #expect(infos.isEmpty)
    }

    @Test func rejectsOwnPID() {
        let infos = menuBarItemInfos(from: [rawWindow(pid: 42)], excludingPIDs: [42])
        #expect(infos.isEmpty)
    }

    @Test func rejectsNonMenuBarGeometry() {
        #expect(menuBarItemInfos(from: [rawWindow(y: 200)], excludingPIDs: []).isEmpty)
        #expect(menuBarItemInfos(from: [rawWindow(w: 2000)], excludingPIDs: []).isEmpty)
        #expect(menuBarItemInfos(from: [rawWindow(h: 100)], excludingPIDs: []).isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter WindowFilterTests`
Expected: build failure — `cannot find 'menuBarItemInfos' in scope`.

- [ ] **Step 3: Write the filter implementation**

`Sources/Valet/Introspection/WindowFilter.swift`:

```swift
import Foundation

func menuBarItemInfos(from raw: [[String: Any]], excludingPIDs: Set<pid_t>) -> [MenuBarItemInfo] {
    raw.compactMap { dict in
        guard
            let layer = dict["kCGWindowLayer"] as? Int, layer == 25,
            let pid = dict["kCGWindowOwnerPID"] as? Int, !excludingPIDs.contains(pid_t(pid)),
            let windowID = dict["kCGWindowNumber"] as? Int,
            let bounds = dict["kCGWindowBounds"] as? [String: Any],
            let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
            let w = bounds["Width"] as? Double, let h = bounds["Height"] as? Double,
            y == 0, h <= 40, w <= 500
        else { return nil }
        return MenuBarItemInfo(
            windowID: UInt32(windowID),
            ownerPID: pid_t(pid),
            ownerName: dict["kCGWindowOwnerName"] as? String ?? "Unknown",
            bundleID: nil,
            frame: CGRect(x: x, y: y, width: w, height: h),
            key: ""
        )
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter WindowFilterTests`
Expected: all 4 tests PASS.

- [ ] **Step 5: Write the live introspector**

`Sources/Valet/Introspection/ItemIntrospector.swift`:

```swift
import AppKit

@MainActor
final class ItemIntrospector: ObservableObject {
    @Published private(set) var items: [MenuBarItemInfo] = []
    private var timer: Timer?

    func refresh() {
        guard let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return }
        let ownPID = pid_t(ProcessInfo.processInfo.processIdentifier)
        let infos = menuBarItemInfos(from: raw, excludingPIDs: [ownPID]).map { info in
            var copy = info
            copy = MenuBarItemInfo(
                windowID: info.windowID,
                ownerPID: info.ownerPID,
                ownerName: info.ownerName,
                bundleID: NSRunningApplication(processIdentifier: info.ownerPID)?.bundleIdentifier,
                frame: info.frame,
                key: ""
            )
            return copy
        }
        items = keyedItems(infos)
    }

    func startAutoRefresh(interval: TimeInterval) {
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func frame(ofWindowID windowID: UInt32) -> CGRect? {
        guard let raw = CGWindowListCopyWindowInfo(
            [.optionOnScreenOnly], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        for dict in raw {
            guard let num = dict["kCGWindowNumber"] as? Int, UInt32(num) == windowID,
                  let bounds = dict["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
                  let w = bounds["Width"] as? Double, let h = bounds["Height"] as? Double
            else { continue }
            return CGRect(x: x, y: y, width: w, height: h)
        }
        return nil
    }
}
```

Note: `frame(ofWindowID:)` intentionally has no geometry filter — it also looks up our own separator windows for drag planning (Task 8).

- [ ] **Step 6: Build and run all tests**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

- [ ] **Step 7: Update FEATURES.md and commit**

Mark "Item introspection (CGWindowList enumeration)" as `[x]` in FEATURES.md.

```bash
git add Sources/Valet/Introspection Tests/ValetTests/WindowFilterTests.swift FEATURES.md
git commit -m "feat: add menu bar window filtering and live item introspector"
```

---

### Task 7: PermissionsService + ItemImageCapturer

**Files:**
- Create: `Sources/Valet/Permissions/PermissionsService.swift`
- Create: `Sources/Valet/Introspection/ItemImageCapturer.swift`

**Interfaces:**
- Consumes: nothing.
- Produces:
  - `enum PermissionsService` with `static func hasScreenRecording() -> Bool`, `static func requestScreenRecording()`, `static func hasAccessibility() -> Bool`, `static func requestAccessibility()`, `static func openScreenRecordingSettings()`, `static func openAccessibilitySettings()`.
  - `final class ItemImageCapturer` with `func capture(windowID: UInt32) async -> CGImage?`. Returns `nil` without Screen Recording permission (graceful degradation). Images are never written to disk.

- [ ] **Step 1: Write PermissionsService**

`Sources/Valet/Permissions/PermissionsService.swift`:

```swift
import AppKit
import ApplicationServices

enum PermissionsService {
    static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func requestScreenRecording() {
        CGRequestScreenCaptureAccess()
    }

    static func hasAccessibility() -> Bool {
        AXIsProcessTrusted()
    }

    static func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    static func openScreenRecordingSettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")
    }

    static func openAccessibilitySettings() {
        open("x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")
    }

    private static func open(_ urlString: String) {
        guard let url = URL(string: urlString) else { return }
        NSWorkspace.shared.open(url)
    }
}
```

- [ ] **Step 2: Write ItemImageCapturer**

`Sources/Valet/Introspection/ItemImageCapturer.swift`:

```swift
import ScreenCaptureKit

final class ItemImageCapturer {
    /// Captures a single menu bar item's window image. In-memory only —
    /// never persist the result. Returns nil if permission is missing or
    /// the window has vanished.
    func capture(windowID: UInt32) async -> CGImage? {
        guard PermissionsService.hasScreenRecording() else { return nil }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
              ),
              let window = content.windows.first(where: { $0.windowID == windowID })
        else { return nil }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(window.frame.width) * 2)
        config.height = max(1, Int(window.frame.height) * 2)
        config.showsCursor = false
        return try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config
        )
    }
}
```

- [ ] **Step 3: Build and test**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS (no new unit tests — both classes are thin wrappers over permission-gated system APIs; covered by manual checklist below and in Task 11).

- [ ] **Step 4: Update FEATURES.md and commit**

Mark "Item image capture (ScreenCaptureKit, in-memory only)" as `[~]` (verified end-to-end in Task 11's UI).

```bash
git add Sources/Valet/Permissions Sources/Valet/Introspection/ItemImageCapturer.swift FEATURES.md
git commit -m "feat: add permissions service and in-memory item image capture"
```

---

### Task 8: Drag planning (TDD) + ItemMover

**Files:**
- Create: `Sources/Valet/Layout/DragPlanner.swift`
- Create: `Sources/Valet/Layout/ItemMover.swift`
- Test: `Tests/ValetTests/DragPlannerTests.swift`

**Interfaces:**
- Consumes: `MenuBarItemInfo` (Task 3), `BarSection` (Task 2).
- Produces:
  - `struct SeparatorFrames: Equatable { var hidden: CGRect; var alwaysHidden: CGRect }`
  - `struct DragPlan: Equatable { var from: CGPoint; var to: CGPoint }`
  - `func dragPlan(item: MenuBarItemInfo, target: BarSection, separators: SeparatorFrames) -> DragPlan?` — pure. All frames are CG global coordinates (top-left origin), as returned by CGWindowList. Returns `nil` if the item is already on the correct side.
  - `final class ItemMover` with `func perform(_ plan: DragPlan) async` — synthesizes a Cmd-drag. Requires Accessibility permission to have an effect.

Coordinate convention (menu bar, x grows rightward):
`[always-hidden items] |alwaysHiddenSep| [hidden items] |hiddenSep| [shown items] [chevron] [clock]`
- `.shown` → item must be RIGHT of `hiddenSep` (`item.frame.minX >= hidden.maxX`).
- `.hidden` → between the separators.
- `.alwaysHidden` → LEFT of `alwaysHiddenSep` (`item.frame.maxX <= alwaysHidden.minX`).

- [ ] **Step 1: Write the failing tests**

`Tests/ValetTests/DragPlannerTests.swift`:

```swift
import Foundation
import Testing
@testable import Valet

@Suite struct DragPlannerTests {
    // Layout: alwaysHiddenSep at x 300-308, hiddenSep at x 500-508.
    let seps = SeparatorFrames(
        hidden: CGRect(x: 500, y: 0, width: 8, height: 24),
        alwaysHidden: CGRect(x: 300, y: 0, width: 8, height: 24)
    )

    private func item(x: CGFloat, width: CGFloat = 30) -> MenuBarItemInfo {
        MenuBarItemInfo(
            windowID: 1, ownerPID: 100, ownerName: "App", bundleID: "com.a",
            frame: CGRect(x: x, y: 0, width: width, height: 24), key: "com.a#0"
        )
    }

    @Test func movesShownItemIntoHiddenSection() {
        let plan = dragPlan(item: item(x: 600), target: .hidden, separators: seps)
        #expect(plan != nil)
        #expect(plan!.from == CGPoint(x: 615, y: 12))
        #expect(plan!.to.x < 500)          // left of hidden separator
        #expect(plan!.to.x > 308)          // right of always-hidden separator
        #expect(plan!.to.y == 12)
    }

    @Test func movesHiddenItemToShown() {
        let plan = dragPlan(item: item(x: 400), target: .shown, separators: seps)
        #expect(plan != nil)
        #expect(plan!.to.x > 508)          // right of hidden separator
    }

    @Test func movesItemToAlwaysHidden() {
        let plan = dragPlan(item: item(x: 600), target: .alwaysHidden, separators: seps)
        #expect(plan != nil)
        #expect(plan!.to.x < 300)          // left of always-hidden separator
    }

    @Test func returnsNilWhenAlreadyInTargetSection() {
        #expect(dragPlan(item: item(x: 600), target: .shown, separators: seps) == nil)
        #expect(dragPlan(item: item(x: 400), target: .hidden, separators: seps) == nil)
        #expect(dragPlan(item: item(x: 100), target: .alwaysHidden, separators: seps) == nil)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter DragPlannerTests`
Expected: build failure — `cannot find 'SeparatorFrames' in scope`.

- [ ] **Step 3: Write the planner implementation**

`Sources/Valet/Layout/DragPlanner.swift`:

```swift
import Foundation

struct SeparatorFrames: Equatable {
    var hidden: CGRect
    var alwaysHidden: CGRect
}

struct DragPlan: Equatable {
    var from: CGPoint
    var to: CGPoint
}

func dragPlan(item: MenuBarItemInfo, target: BarSection, separators: SeparatorFrames) -> DragPlan? {
    let gap: CGFloat = 12
    let halfWidth = item.frame.width / 2
    let y = item.frame.midY
    let from = CGPoint(x: item.frame.midX, y: y)

    let alreadyThere: Bool
    let targetX: CGFloat
    switch target {
    case .shown:
        alreadyThere = item.frame.minX >= separators.hidden.maxX
        targetX = separators.hidden.maxX + gap + halfWidth
    case .hidden:
        alreadyThere = item.frame.maxX <= separators.hidden.minX
            && item.frame.minX >= separators.alwaysHidden.maxX
        targetX = max(
            separators.hidden.minX - gap - halfWidth,
            (separators.alwaysHidden.maxX + separators.hidden.minX) / 2
        )
    case .alwaysHidden:
        alreadyThere = item.frame.maxX <= separators.alwaysHidden.minX
        targetX = separators.alwaysHidden.minX - gap - halfWidth
    }
    if alreadyThere { return nil }
    return DragPlan(from: from, to: CGPoint(x: targetX, y: y))
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter DragPlannerTests`
Expected: all 4 tests PASS.

- [ ] **Step 5: Write ItemMover**

`Sources/Valet/Layout/ItemMover.swift`:

```swift
import CoreGraphics
import Foundation

final class ItemMover {
    /// Synthesizes a Cmd-drag from plan.from to plan.to in global display
    /// coordinates. Requires Accessibility permission.
    func perform(_ plan: DragPlan) async {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        func post(_ type: CGEventType, at point: CGPoint) {
            let event = CGEvent(
                mouseEventSource: source, mouseType: type,
                mouseCursorPosition: point, mouseButton: .left
            )
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }

        post(.leftMouseDown, at: plan.from)
        try? await Task.sleep(for: .milliseconds(60))
        let steps = 12
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = plan.from.x + (plan.to.x - plan.from.x) * t
            post(.leftMouseDragged, at: CGPoint(x: x, y: plan.to.y))
            try? await Task.sleep(for: .milliseconds(20))
        }
        post(.leftMouseUp, at: plan.to)
        try? await Task.sleep(for: .milliseconds(60))
    }
}
```

- [ ] **Step 6: Build and run all tests**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

- [ ] **Step 7: Commit**

```bash
git add Sources/Valet/Layout Tests/ValetTests/DragPlannerTests.swift
git commit -m "feat: add drag planning and synthesized cmd-drag item mover"
```

---

### Task 9: HotkeyManager + modifier conversion (TDD)

**Files:**
- Create: `Sources/Valet/Hotkeys/HotkeyManager.swift`
- Create: `Sources/Valet/Hotkeys/ModifierConversion.swift`
- Test: `Tests/ValetTests/ModifierConversionTests.swift`
- Modify: `Sources/Valet/ValetApp.swift`

**Interfaces:**
- Consumes: `Hotkey` (Task 2), `MenuBarManager.toggle()` (Task 5), `SettingsStore.toggleHotkey` (Task 2).
- Produces:
  - `func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32` and `func hotkeyDisplayString(_ hotkey: Hotkey) -> String` (pure, testable).
  - `final class HotkeyManager` with `var onTrigger: (() -> Void)?`, `func register(_ hotkey: Hotkey)`, `func unregister()`.

- [ ] **Step 1: Write the failing tests**

`Tests/ValetTests/ModifierConversionTests.swift`:

```swift
import AppKit
import Testing
@testable import Valet

@Suite struct ModifierConversionTests {
    @Test func convertsEachModifier() {
        #expect(carbonModifiers(from: [.command]) == 256)       // cmdKey
        #expect(carbonModifiers(from: [.shift]) == 512)         // shiftKey
        #expect(carbonModifiers(from: [.option]) == 2048)       // optionKey
        #expect(carbonModifiers(from: [.control]) == 4096)      // controlKey
        #expect(carbonModifiers(from: [.command, .option]) == 2304)
    }

    @Test func displayStringShowsModifiersAndKey() {
        // keyCode 11 is "B" on ANSI layouts
        let s = hotkeyDisplayString(Hotkey(keyCode: 11, carbonModifiers: 256 | 2048))
        #expect(s.contains("⌘"))
        #expect(s.contains("⌥"))
        #expect(!s.isEmpty)
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter ModifierConversionTests`
Expected: build failure — `cannot find 'carbonModifiers' in scope`.

- [ ] **Step 3: Write conversion + manager**

`Sources/Valet/Hotkeys/ModifierConversion.swift`:

```swift
import AppKit
import Carbon.HIToolbox

func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var result: UInt32 = 0
    if flags.contains(.command) { result |= UInt32(cmdKey) }
    if flags.contains(.shift) { result |= UInt32(shiftKey) }
    if flags.contains(.option) { result |= UInt32(optionKey) }
    if flags.contains(.control) { result |= UInt32(controlKey) }
    return result
}

func hotkeyDisplayString(_ hotkey: Hotkey) -> String {
    var parts = ""
    if hotkey.carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
    if hotkey.carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
    if hotkey.carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
    if hotkey.carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
    return parts + keyName(for: hotkey.keyCode)
}

private func keyName(for keyCode: UInt32) -> String {
    let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N",
        46: "M", 18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6", 26: "7",
        28: "8", 25: "9", 29: "0", 49: "Space", 36: "Return", 48: "Tab",
        53: "Esc", 42: "\\", 24: "=", 27: "-",
    ]
    return names[keyCode] ?? "Key\(keyCode)"
}
```

`Sources/Valet/Hotkeys/HotkeyManager.swift`:

```swift
import Carbon.HIToolbox
import Foundation

final class HotkeyManager {
    var onTrigger: (() -> Void)?
    private var hotKeyRef: EventHotKeyRef?
    private var handlerRef: EventHandlerRef?

    func register(_ hotkey: Hotkey) {
        unregister()
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let callback: EventHandlerUPP = { _, _, userData in
            guard let userData else { return noErr }
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            DispatchQueue.main.async { manager.onTrigger?() }
            return noErr
        }
        InstallEventHandler(
            GetApplicationEventTarget(), callback, 1, &eventType,
            Unmanaged.passUnretained(self).toOpaque(), &handlerRef
        )
        let hotKeyID = EventHotKeyID(signature: OSType(0x564C5431), id: 1)  // "VLT1"
        RegisterEventHotKey(
            hotkey.keyCode, hotkey.carbonModifiers, hotKeyID,
            GetApplicationEventTarget(), 0, &hotKeyRef
        )
    }

    func unregister() {
        if let hotKeyRef { UnregisterEventHotKey(hotKeyRef) }
        if let handlerRef { RemoveEventHandler(handlerRef) }
        hotKeyRef = nil
        handlerRef = nil
    }

    deinit { unregister() }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter ModifierConversionTests`
Expected: both tests PASS.

- [ ] **Step 5: Wire into AppDelegate**

In `Sources/Valet/ValetApp.swift`, extend `AppDelegate`:

```swift
final class AppDelegate: NSObject, NSApplicationDelegate {
    private(set) var settingsStore: SettingsStore!
    private(set) var menuBarManager: MenuBarManager!
    private(set) var hotkeyManager = HotkeyManager()
    private var hotkeyObservation: Any?

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore(defaults: .standard)
        menuBarManager = MenuBarManager(store: settingsStore)

        hotkeyManager.onTrigger = { [weak self] in
            self?.menuBarManager.toggle()
        }
        applyHotkey(settingsStore.toggleHotkey)
        hotkeyObservation = settingsStore.$toggleHotkey.sink { [weak self] hotkey in
            self?.applyHotkey(hotkey)
        }
    }

    private func applyHotkey(_ hotkey: Hotkey?) {
        if let hotkey {
            hotkeyManager.register(hotkey)
        } else {
            hotkeyManager.unregister()
        }
    }
}
```

Add `import Combine` at the top of `ValetApp.swift` and change `hotkeyObservation`'s type to `AnyCancellable?`.

- [ ] **Step 6: Build, test, manual verify**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

Manual: temporarily verify after Task 12's recorder UI exists (hotkey has no default). No manual step here.

- [ ] **Step 7: Commit**

```bash
git add Sources/Valet/Hotkeys Tests/ValetTests/ModifierConversionTests.swift Sources/Valet/ValetApp.swift
git commit -m "feat: add Carbon global hotkey manager wired to visibility toggle"
```

---

### Task 10: Settings window scaffold + Behavior tab

**Files:**
- Create: `Sources/Valet/UI/SettingsWindowController.swift`
- Create: `Sources/Valet/UI/SettingsRootView.swift`
- Create: `Sources/Valet/UI/BehaviorView.swift`
- Modify: `Sources/Valet/ValetApp.swift`

**Interfaces:**
- Consumes: `SettingsStore` (Task 2), `ItemIntrospector` (Task 6), `MenuBarManager.onOpenSettings` (Task 5).
- Produces:
  - `@MainActor final class SettingsWindowController` with `init(rootView: SettingsRootView)` and `func show(tab: SettingsTab)`.
  - `enum SettingsTab: String, CaseIterable { case items, behavior, hotkeys, permissions, about }`
  - `struct SettingsRootView: View` with `init(store: SettingsStore, introspector: ItemIntrospector, assigner: SectionAssigner?, selectedTab: Binding<SettingsTab>)`. For THIS task, `assigner` is declared as `Any?` placeholder-free by simply not including it yet — the initializer for this task is `init(store:introspector:selectedTab:)`; Task 11 adds the assigner parameter. Tabs render: Items (temporary `Text("Items")`), Behavior (real), Hotkeys (`Text("Hotkeys")` until Task 12), Permissions (`Text("Permissions")` until Task 12), About (`Text("About")` until Task 13).
  - `struct BehaviorView: View` — auto-rehide toggle, delay stepper, launch-at-login toggle via `SMAppService`.

- [ ] **Step 1: Write SettingsWindowController**

`Sources/Valet/UI/SettingsWindowController.swift`:

```swift
import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case items, behavior, hotkeys, permissions, about
}

@MainActor
final class SettingsWindowController {
    private final class TabSelection: ObservableObject {
        @Published var tab: SettingsTab = .items
    }

    private struct RootHost: View {
        @ObservedObject var selection: TabSelection
        let content: (Binding<SettingsTab>) -> AnyView

        var body: some View {
            content($selection.tab)
        }
    }

    private var window: NSWindow?
    private let makeRoot: (Binding<SettingsTab>) -> AnyView
    private let selection = TabSelection()

    init(makeRoot: @escaping (Binding<SettingsTab>) -> AnyView) {
        self.makeRoot = makeRoot
    }

    func show(tab: SettingsTab = .items) {
        selection.tab = tab
        if window == nil {
            let hosting = NSHostingController(
                rootView: RootHost(selection: selection, content: makeRoot)
            )
            let w = NSWindow(contentViewController: hosting)
            w.title = "Valet"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 560, height: 420))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
```

- [ ] **Step 2: Write SettingsRootView and BehaviorView**

`Sources/Valet/UI/SettingsRootView.swift`:

```swift
import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var introspector: ItemIntrospector
    @Binding var selectedTab: SettingsTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Text("Items")
                .tabItem { Label("Items", systemImage: "menubar.rectangle") }
                .tag(SettingsTab.items)
            BehaviorView(store: store)
                .tabItem { Label("Behavior", systemImage: "gearshape") }
                .tag(SettingsTab.behavior)
            Text("Hotkeys")
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
                .tag(SettingsTab.hotkeys)
            Text("Permissions")
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
            Text("About")
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
```

`Sources/Valet/UI/BehaviorView.swift`:

```swift
import ServiceManagement
import SwiftUI

struct BehaviorView: View {
    @ObservedObject var store: SettingsStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var suppressLoginItemChange = false

    var body: some View {
        Form {
            Toggle("Automatically re-hide items", isOn: $store.autoRehide)
            Stepper(
                "Re-hide after \(Int(store.rehideDelay)) seconds",
                value: $store.rehideDelay, in: 2...120, step: 1
            )
            .disabled(!store.autoRehide)

            Divider()

            Toggle("Launch Valet at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enable in
                    if suppressLoginItemChange {
                        suppressLoginItemChange = false
                        return
                    }
                    do {
                        if enable {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        loginItemError = nil
                    } catch {
                        loginItemError = "Couldn't update login item: \(error.localizedDescription). "
                            + "Run Valet from /Applications (built via Scripts/make-app.sh) and try again."
                        let actual = SMAppService.mainApp.status == .enabled
                        if actual != launchAtLogin {
                            suppressLoginItemChange = true
                            launchAtLogin = actual
                        }
                    }
                }
            if let loginItemError {
                Text(loginItemError).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(20)
    }
}
```

- [ ] **Step 3: Wire into AppDelegate**

In `Sources/Valet/ValetApp.swift`, add to `AppDelegate`:

```swift
    private(set) var introspector = ItemIntrospector()
    private var settingsWindow: SettingsWindowController!
```

At the end of `applicationDidFinishLaunching`:

```swift
        introspector.startAutoRefresh(interval: 5)
        let store = settingsStore!
        let intro = introspector
        settingsWindow = SettingsWindowController { binding in
            AnyView(SettingsRootView(store: store, introspector: intro, selectedTab: binding))
        }
        menuBarManager.onOpenSettings = { [weak self] in
            self?.settingsWindow.show(tab: .items)
        }
```

- [ ] **Step 4: Build, test, manual verify**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

Manual: `Scripts/make-app.sh && open build/Valet.app` → right-click chevron → "Settings…" opens the window with 5 tabs; Behavior tab toggles work; delay stepper changes persist across relaunch. (Launch-at-login may error unless the app is in /Applications — the error message must appear and the toggle must revert.) `pkill Valet`.

- [ ] **Step 5: Update FEATURES.md and commit**

Mark "Settings UI: behavior / hotkeys / permissions / about tabs" as `[~]`, "Launch at login (SMAppService)" as `[x]`, "Local-only settings storage (bundle IDs + prefs, no PII)" as `[x]`.

```bash
git add Sources/Valet/UI Sources/Valet/ValetApp.swift FEATURES.md
git commit -m "feat: add settings window with behavior tab and launch at login"
```

---

### Task 11: Items tab — item list with images and drag-to-assign

**Files:**
- Create: `Sources/Valet/Layout/SectionAssigner.swift`
- Create: `Sources/Valet/UI/ItemListView.swift`
- Modify: `Sources/Valet/UI/SettingsRootView.swift`
- Modify: `Sources/Valet/ValetApp.swift`

**Interfaces:**
- Consumes: `reconcile` (Task 3), `ItemIntrospector` (Task 6), `ItemImageCapturer` (Task 7), `dragPlan`/`ItemMover`/`SeparatorFrames` (Task 8), `MenuBarManager.separatorWindowIDs`, `revealAllTemporarily()`, `endTemporaryReveal()` (Task 5), `SettingsStore.assignments` (Task 2).
- Produces:
  - `@MainActor final class SectionAssigner: ObservableObject` with `init(store: SettingsStore, introspector: ItemIntrospector, mover: ItemMover, menuBarManager: MenuBarManager)` and `func move(key: String, to section: BarSection) async`.
  - `struct ItemListView: View` with `init(store: SettingsStore, introspector: ItemIntrospector, assigner: SectionAssigner)`.
  - `SettingsRootView.init` gains `assigner: SectionAssigner` and the Items tab renders `ItemListView`.

- [ ] **Step 1: Write SectionAssigner**

`Sources/Valet/Layout/SectionAssigner.swift`:

```swift
import AppKit

@MainActor
final class SectionAssigner: ObservableObject {
    private let store: SettingsStore
    private let introspector: ItemIntrospector
    private let mover: ItemMover
    private let menuBarManager: MenuBarManager
    @Published private(set) var isMoving = false
    @Published var lastError: String?

    init(store: SettingsStore, introspector: ItemIntrospector,
         mover: ItemMover, menuBarManager: MenuBarManager) {
        self.store = store
        self.introspector = introspector
        self.mover = mover
        self.menuBarManager = menuBarManager
    }

    /// Moves the real menu bar item, then records the assignment.
    /// Flow: reveal everything -> re-introspect (fresh frames) -> plan -> drag
    /// -> re-introspect -> restore reveal state.
    func move(key: String, to section: BarSection) async {
        guard !isMoving else { return }
        guard PermissionsService.hasAccessibility() else {
            store.assignments[key] = section
            lastError = "Accessibility permission is off, so Valet saved your choice but can't "
                + "move the icon for you. Grant it in Permissions, or hold Cmd and drag the icon "
                + "relative to the | separators yourself."
            return
        }
        isMoving = true
        defer { isMoving = false }
        lastError = nil

        menuBarManager.revealAllTemporarily()
        try? await Task.sleep(for: .milliseconds(300))
        introspector.refresh()

        let ids = menuBarManager.separatorWindowIDs
        guard let item = introspector.items.first(where: { $0.key == key }),
              let hiddenID = ids.hidden, let alwaysID = ids.alwaysHidden,
              let hiddenFrame = introspector.frame(ofWindowID: hiddenID),
              let alwaysFrame = introspector.frame(ofWindowID: alwaysID)
        else {
            lastError = "Couldn't locate the item or separators. Try again with the menu bar visible."
            menuBarManager.endTemporaryReveal()
            return
        }

        let separators = SeparatorFrames(hidden: hiddenFrame, alwaysHidden: alwaysFrame)
        if let plan = dragPlan(item: item, target: section, separators: separators) {
            await mover.perform(plan)
        }
        store.assignments[key] = section
        introspector.refresh()
        menuBarManager.endTemporaryReveal()
    }
}
```

- [ ] **Step 2: Write ItemListView**

`Sources/Valet/UI/ItemListView.swift`:

```swift
import SwiftUI
import UniformTypeIdentifiers

struct ItemListView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var introspector: ItemIntrospector
    @ObservedObject var assigner: SectionAssigner
    @State private var images: [String: CGImage] = [:]
    private let capturer = ItemImageCapturer()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !PermissionsService.hasScreenRecording() {
                Label(
                    "Grant Screen Recording in the Permissions tab to see item icons. Everything stays on this Mac.",
                    systemImage: "eye.slash"
                )
                .font(.caption)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
            if let error = assigner.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach([BarSection.shown, .hidden, .alwaysHidden], id: \.self) { section in
                    sectionColumn(section)
                }
            }
            Text("Drag items between sections, or right-click an item to move it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .task { await refreshImages() }
        .onReceive(introspector.$items) { _ in
            Task { await refreshImages() }
        }
    }

    private func sectionColumn(_ section: BarSection) -> some View {
        let rows = reconcile(assignments: store.assignments, items: introspector.items)
            .filter { $0.section == section }
        return VStack(alignment: .leading, spacing: 4) {
            Text(section.displayName).font(.headline)
            List(rows, id: \.item.key) { row in
                itemRow(row.item)
            }
            .frame(minHeight: 220)
        }
        .frame(maxWidth: .infinity)
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let key = object as? String else { return }
                Task { @MainActor in
                    await assigner.move(key: key, to: section)
                }
            }
            return true
        }
    }

    private func itemRow(_ item: MenuBarItemInfo) -> some View {
        HStack(spacing: 6) {
            if let cg = images[item.key] {
                Image(cg, scale: 2, label: Text(item.ownerName))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
            } else {
                Image(systemName: "app.dashed").frame(height: 18)
            }
            Text(item.ownerName).lineLimit(1)
        }
        .onDrag { NSItemProvider(object: item.key as NSString) }
        .contextMenu {
            ForEach(BarSection.allCases, id: \.self) { target in
                Button("Move to \(target.displayName)") {
                    Task { await assigner.move(key: item.key, to: target) }
                }
            }
        }
    }

    @MainActor
    private func refreshImages() async {
        for item in introspector.items {
            if let image = await capturer.capture(windowID: item.windowID) {
                images[item.key] = image
            }
        }
    }
}
```

- [ ] **Step 3: Wire assigner through SettingsRootView and AppDelegate**

In `SettingsRootView.swift`, add `@ObservedObject var assigner: SectionAssigner` and replace the Items tab placeholder:

```swift
            ItemListView(store: store, introspector: introspector, assigner: assigner)
                .tabItem { Label("Items", systemImage: "menubar.rectangle") }
                .tag(SettingsTab.items)
```

In `ValetApp.swift` `applicationDidFinishLaunching`, before creating `settingsWindow`:

```swift
        let assigner = SectionAssigner(
            store: settingsStore, introspector: introspector,
            mover: ItemMover(), menuBarManager: menuBarManager
        )
```

and pass `assigner: assigner` into `SettingsRootView(...)` inside the closure (capture it like `store`/`intro`).

- [ ] **Step 4: Build, test, manual verify**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

Manual (`Scripts/make-app.sh && open build/Valet.app`):
1. Open Settings → Items. Without Screen Recording: yellow banner shows, rows show generic icons + app names.
2. Grant Screen Recording (Permissions flow lands in Task 12 — for now grant via System Settings manually after triggering capture once). Relaunch → real item icons appear.
3. Grant Accessibility. Drag an item row from Shown to Hidden → the real menu bar icon physically moves left of the `|` separator; assignment persists after relaunch.
4. Right-click an item row → "Move to Always Hidden" works the same way.
5. Without Accessibility: moving shows the orange guidance message and still saves the assignment.

`pkill Valet` when done.

- [ ] **Step 5: Update FEATURES.md and commit**

Mark `[x]`: "Three sections: Shown / Hidden / Always Hidden", "Item image capture (ScreenCaptureKit, in-memory only)", "Settings UI: item list with images, drag-to-assign sections", "Move items between sections via simulated Cmd-drag".

```bash
git add Sources/Valet/Layout/SectionAssigner.swift Sources/Valet/UI FEATURES.md Sources/Valet/ValetApp.swift
git commit -m "feat: add items tab with live icons, drag-to-assign, and real item moving"
```

---

### Task 12: Hotkeys tab + Permissions tab + first-run onboarding

**Files:**
- Create: `Sources/Valet/UI/HotkeyRecorderView.swift`
- Create: `Sources/Valet/UI/PermissionsView.swift`
- Modify: `Sources/Valet/UI/SettingsRootView.swift`
- Modify: `Sources/Valet/ValetApp.swift`

**Interfaces:**
- Consumes: `Hotkey`, `SettingsStore.toggleHotkey` (Task 2), `carbonModifiers(from:)`, `hotkeyDisplayString` (Task 9), `PermissionsService` (Task 7), `SettingsWindowController.show(tab:)` (Task 10).
- Produces:
  - `struct HotkeyRecorderView: View` with `init(store: SettingsStore)` — shows current hotkey, "Record" captures the next keydown-with-modifiers via a local NSEvent monitor, "Clear" sets it to nil.
  - `struct PermissionsView: View` — one row per permission: status indicator, what it's for, why it's safe, Request + Open System Settings buttons.

- [ ] **Step 1: Write HotkeyRecorderView**

`Sources/Valet/UI/HotkeyRecorderView.swift`:

```swift
import AppKit
import SwiftUI

struct HotkeyRecorderView: View {
    @ObservedObject var store: SettingsStore
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Form {
            HStack {
                Text("Toggle hidden items:")
                Text(store.toggleHotkey.map(hotkeyDisplayString) ?? "None")
                    .fontWeight(.semibold)
                    .frame(minWidth: 80)
                Button(isRecording ? "Press keys…" : "Record") { startRecording() }
                    .disabled(isRecording)
                Button("Clear") { store.toggleHotkey = nil }
                    .disabled(store.toggleHotkey == nil)
            }
            Text("The shortcut must include at least one of ⌘ ⌥ ⌃ ⇧.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = carbonModifiers(from: event.modifierFlags)
            if event.keyCode == 53 && mods == 0 {  // Esc cancels
                stopRecording()
                return nil
            }
            guard mods != 0 else { return nil }  // require a modifier
            store.toggleHotkey = Hotkey(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
```

- [ ] **Step 2: Write PermissionsView**

`Sources/Valet/UI/PermissionsView.swift`:

```swift
import SwiftUI

struct PermissionsView: View {
    @State private var screenRecording = PermissionsService.hasScreenRecording()
    @State private var accessibility = PermissionsService.hasAccessibility()
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            permissionRow(
                granted: screenRecording,
                title: "Screen Recording",
                purpose: "Lets Valet show the icons and names of your menu bar items.",
                privacy: "Captures only menu bar item images, kept in memory, never saved or sent anywhere.",
                request: PermissionsService.requestScreenRecording,
                openSettings: PermissionsService.openScreenRecordingSettings
            )
            permissionRow(
                granted: accessibility,
                title: "Accessibility",
                purpose: "Lets Valet move icons between sections for you (simulated Cmd-drag).",
                privacy: "Used only to perform the drag you request. Without it, you can Cmd-drag icons manually.",
                request: PermissionsService.requestAccessibility,
                openSettings: PermissionsService.openAccessibilitySettings
            )
            Text("Valet works without these permissions, with reduced convenience. Nothing ever leaves this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .onReceive(timer) { _ in
            screenRecording = PermissionsService.hasScreenRecording()
            accessibility = PermissionsService.hasAccessibility()
        }
    }

    private func permissionRow(
        granted: Bool, title: String, purpose: String, privacy: String,
        request: @escaping () -> Void, openSettings: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(granted ? .green : .secondary)
                Text(title).font(.headline)
                Spacer()
                if !granted {
                    Button("Request", action: request)
                    Button("Open System Settings", action: openSettings)
                }
            }
            Text(purpose).font(.callout)
            Text(privacy).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
```

- [ ] **Step 3: Replace tab placeholders and add first-run onboarding**

In `SettingsRootView.swift`, replace `Text("Hotkeys")` with `HotkeyRecorderView(store: store)` and `Text("Permissions")` with `PermissionsView()` (keep the same `.tabItem`/`.tag` modifiers).

In `ValetApp.swift`, at the end of `applicationDidFinishLaunching`:

```swift
        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded")
        if !hasOnboarded {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
            settingsWindow.show(tab: .permissions)
        }
```

- [ ] **Step 4: Build, test, manual verify**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

Manual (`Scripts/make-app.sh && open build/Valet.app` — first delete the onboarding flag: `defaults delete app.valet.Valet hasOnboarded` — note: when run from the bundle, the defaults domain is `app.valet.Valet`):
1. First launch → settings opens on Permissions tab; both rows show status; Request buttons trigger system prompts; status flips to green within 2 s of granting.
2. Hotkeys tab → Record → press ⌥⌘B → shows "⌥⌘B"; press the hotkey with the app in background → hidden items toggle. Clear → hotkey stops working.
3. Hotkey persists across relaunch.

`pkill Valet` when done.

- [ ] **Step 5: Update FEATURES.md and commit**

Mark `[x]`: "Global hotkey toggle", "Permissions onboarding with graceful degradation". Keep "Settings UI: behavior / hotkeys / permissions / about tabs" at `[~]` (About lands in Task 13).

```bash
git add Sources/Valet/UI Sources/Valet/ValetApp.swift FEATURES.md
git commit -m "feat: add hotkey recorder, permissions tab, and first-run onboarding"
```

---

### Task 13: About tab + manual update check (TDD for SemVer)

**Files:**
- Create: `Sources/Valet/Settings/UpdateChecker.swift`
- Create: `Sources/Valet/UI/AboutView.swift`
- Modify: `Sources/Valet/UI/SettingsRootView.swift`
- Test: `Tests/ValetTests/SemVerTests.swift`

**Interfaces:**
- Consumes: nothing new.
- Produces:
  - `struct SemVer: Comparable, Equatable` with `init?(_ string: String)` (accepts `"1.2.3"` and `"v1.2.3"`), `let major: Int, minor: Int, patch: Int`.
  - `final class UpdateChecker` with `static let repoSlug = "valet-menu/valet"` (single constant — change when the repo is published), `static let currentVersion = "0.1.0"`, `enum Status: Equatable { case upToDate; case updateAvailable(String); case failed }`, `func check() async -> Status`. THE ONLY NETWORK CALL IN THE APP; runs only when invoked from the About tab button.
  - `struct AboutView: View` — app name, version, MIT notice, repo link, "Check for Updates" button + result line.

- [ ] **Step 1: Write the failing tests**

`Tests/ValetTests/SemVerTests.swift`:

```swift
import Testing
@testable import Valet

@Suite struct SemVerTests {
    @Test func parsesPlainAndPrefixedVersions() {
        #expect(SemVer("1.2.3") == SemVer(major: 1, minor: 2, patch: 3))
        #expect(SemVer("v0.1.0") == SemVer(major: 0, minor: 1, patch: 0))
        #expect(SemVer("2.0") == SemVer(major: 2, minor: 0, patch: 0))
        #expect(SemVer("garbage") == nil)
        #expect(SemVer("") == nil)
    }

    @Test func comparesCorrectly() {
        #expect(SemVer("1.0.0")! < SemVer("1.0.1")!)
        #expect(SemVer("1.9.9")! < SemVer("2.0.0")!)
        #expect(SemVer("0.1.0")! < SemVer("0.2.0")!)
        #expect(!(SemVer("1.0.0")! < SemVer("1.0.0")!))
    }
}
```

- [ ] **Step 2: Run tests to verify they fail**

Run: `swift test --filter SemVerTests`
Expected: build failure — `cannot find 'SemVer' in scope`.

- [ ] **Step 3: Write SemVer + UpdateChecker**

`Sources/Valet/Settings/UpdateChecker.swift`:

```swift
import Foundation

struct SemVer: Comparable, Equatable {
    let major: Int
    let minor: Int
    let patch: Int

    init(major: Int, minor: Int, patch: Int) {
        self.major = major
        self.minor = minor
        self.patch = patch
    }

    init?(_ string: String) {
        var s = string
        if s.hasPrefix("v") { s.removeFirst() }
        let parts = s.split(separator: ".").map { Int($0) }
        guard !parts.isEmpty, parts.allSatisfy({ $0 != nil }) else { return nil }
        major = parts[0]!
        minor = parts.count > 1 ? parts[1]! : 0
        patch = parts.count > 2 ? parts[2]! : 0
    }

    static func < (lhs: SemVer, rhs: SemVer) -> Bool {
        (lhs.major, lhs.minor, lhs.patch) < (rhs.major, rhs.minor, rhs.patch)
    }
}

/// THE ONLY NETWORK CODE IN VALET. Runs exclusively when the user clicks
/// "Check for Updates" in the About tab. One GET to the GitHub Releases API.
final class UpdateChecker {
    static let repoSlug = "valet-menu/valet"  // update when the public repo exists
    static let currentVersion = "0.1.0"

    enum Status: Equatable {
        case upToDate
        case updateAvailable(String)
        case failed
    }

    func check() async -> Status {
        guard let url = URL(string: "https://api.github.com/repos/\(Self.repoSlug)/releases/latest"),
              let (data, response) = try? await URLSession.shared.data(from: url),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let tag = json["tag_name"] as? String,
              let latest = SemVer(tag),
              let current = SemVer(Self.currentVersion)
        else { return .failed }
        return current < latest ? .updateAvailable(tag) : .upToDate
    }
}
```

- [ ] **Step 4: Run tests to verify they pass**

Run: `swift test --filter SemVerTests`
Expected: both tests PASS.

- [ ] **Step 5: Write AboutView and wire the tab**

`Sources/Valet/UI/AboutView.swift`:

```swift
import SwiftUI

struct AboutView: View {
    @State private var checking = false
    @State private var result: String?
    private let checker = UpdateChecker()

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "menubar.arrow.up.rectangle")
                .font(.system(size: 40))
            Text("Valet").font(.title.bold())
            Text("Version \(UpdateChecker.currentVersion)")
                .foregroundStyle(.secondary)
            Text("Open-source menu bar manager. MIT licensed.\nEverything stays on this Mac — the only network request Valet can make is the button below.")
                .multilineTextAlignment(.center)
                .font(.callout)
            Link("Source code on GitHub",
                 destination: URL(string: "https://github.com/\(UpdateChecker.repoSlug)")!)
            Button(checking ? "Checking…" : "Check for Updates") {
                checking = true
                result = nil
                Task {
                    switch await checker.check() {
                    case .upToDate: result = "You're up to date."
                    case .updateAvailable(let tag): result = "Version \(tag) is available on GitHub."
                    case .failed: result = "Couldn't check. Are you online? (Valet never checks by itself.)"
                    }
                    checking = false
                }
            }
            .disabled(checking)
            if let result { Text(result).font(.caption) }
            Spacer()
        }
        .padding(24)
    }
}
```

In `SettingsRootView.swift`, replace `Text("About")` with `AboutView()` (keep `.tabItem`/`.tag`).

- [ ] **Step 6: Build, test, manual verify**

Run: `swift build && swift test`
Expected: build succeeds, all tests PASS.

Manual: About tab shows version; "Check for Updates" returns the "Couldn't check" message gracefully (repo not published yet) and never fires without a click.

- [ ] **Step 7: Update FEATURES.md and commit**

Mark `[x]`: "Manual \"Check for Updates\" button (only network call in the app)", "Settings UI: behavior / hotkeys / permissions / about tabs".

```bash
git add Sources/Valet/Settings/UpdateChecker.swift Sources/Valet/UI Tests/ValetTests/SemVerTests.swift FEATURES.md
git commit -m "feat: add about tab with manual-only update check"
```

---

### Task 14: README, release checklist, full manual verification, v0.1.0 tag

**Files:**
- Create: `README.md`
- Create: `docs/manual-test-checklist.md`
- Modify: `FEATURES.md`

**Interfaces:**
- Consumes: everything.
- Produces: release-ready repo.

- [ ] **Step 1: Write README.md**

Content requirements (write in full, no placeholders):
- What Valet is: free, open-source (MIT) menu bar manager for macOS 14+; hides/shows menu bar items with Shown / Hidden / Always Hidden sections; global hotkey; auto-rehide; launch at login.
- Privacy section: everything is local; no analytics or telemetry; the only network request is the manual "Check for Updates" button; settings contain only app identifiers and preferences; menu bar images stay in memory.
- Install: download the release zip, unzip, move `Valet.app` to /Applications, then **right-click → Open** the first time (the app is not notarized because it's built without an Apple developer account — the source is right here to audit and build yourself).
- Build from source: `git clone`, `Scripts/make-app.sh`, requires only Xcode Command Line Tools.
- Permissions table (Screen Recording, Accessibility): what each enables, and that Valet works without them.
- Usage: click chevron to toggle; Option-click to reveal Always Hidden; right-click for Settings; Cmd-drag icons between the `|` separators, or use the Items tab.

- [ ] **Step 2: Write docs/manual-test-checklist.md**

A numbered checklist consolidating every "Manual verification" step from Tasks 1, 5, 10, 11, 12, 13, plus:
- Multi-display: toggle works on a second display.
- Relaunch persistence: assignments, hotkey, behavior settings survive relaunch.
- Permission-revoked: revoke Screen Recording and Accessibility in System Settings; app degrades per Tasks 11/12 (banner, guidance message) without crashing.

- [ ] **Step 3: Run everything**

Run: `swift test && Scripts/make-app.sh && open build/Valet.app`
Expected: all tests PASS; app builds; walk the full manual checklist and check every line.

- [ ] **Step 4: Finalize FEATURES.md**

Every Phase 1 line should now be `[x]`. If any line isn't, the corresponding task is not done — go back.

- [ ] **Step 5: Commit and tag**

```bash
git add README.md docs/manual-test-checklist.md FEATURES.md
git commit -m "docs: add README, manual test checklist; complete Phase 1"
git tag v0.1.0
```

(Do NOT push or create a GitHub repo — that's the user's call.)

---

## Self-Review Notes

- **Spec coverage:** All 16 Phase 1 FEATURES.md lines map to tasks: control items/spacer/toggle/auto-rehide/multi-display (Task 5), sections (Tasks 4, 5, 11), hotkey (Tasks 9, 12), introspection (Task 6), image capture (Tasks 7, 11), settings UI (Tasks 10–13), simulated drag (Tasks 8, 11), permissions onboarding (Task 12), launch at login (Task 10), update check (Task 13), local-only storage (Task 2). README/privacy/distribution (Task 14).
- **Known risks called out to implementers:** status item creation order vs. autosaved positions (macOS restores saved positions after first run — the creation-order comment in Task 5 only governs FIRST launch; if separators end up misordered during testing, reset with `defaults delete app.valet.Valet` and relaunch); `CGRequestScreenCaptureAccess()` only prompts once per app signature — subsequent grants go through System Settings, which is why every permission row has an "Open System Settings" button; ad-hoc re-signing after a rebuild resets TCC grants (expected during development — re-grant after each rebuild, or use the same built bundle while walking the checklist).
- **Type consistency check:** `MenuBarItemInfo` field order in every initializer call matches the struct definition (windowID, ownerPID, ownerName, bundleID, frame, key); `reconcile` returns labeled tuple `(item:section:)` and Task 11 consumes `$0.item`/`$0.section`; `SeparatorFrames(hidden:alwaysHidden:)` argument order consistent between Tasks 8 and 11.
