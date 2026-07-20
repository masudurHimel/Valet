import AppKit
import os

/// Local-only diagnostics for the separator persistence pipeline (unified
/// log, subsystem app.valet.Valet). Never leaves the machine.
let persistenceLog = Logger(subsystem: "app.valet.Valet", category: "persistence")

@MainActor
final class MenuBarManager {
    private let store: SettingsStore
    private var engine = VisibilityEngine()
    private var rehideTimer: Timer?
    private var stateBeforeTemporaryReveal: RevealState?

    private var chevronItem: NSStatusItem!
    private var hiddenSeparator: NSStatusItem!
    private var alwaysHiddenSeparator: NSStatusItem!

    /// Last preferred-position value seen while the layout was healthy, keyed by
    /// autosave name. The order guard records these on healthy refreshes and
    /// asks to restore them when a separator lands right of the chevron.
    private var lastGoodPositions: [String: CGFloat] = [:]

    var onOpenSettings: (() -> Void)?

    var separatorWindowIDs: (hidden: UInt32?, alwaysHidden: UInt32?) {
        (windowID(of: hiddenSeparator), windowID(of: alwaysHiddenSeparator))
    }

    var chevronWindowID: UInt32? { windowID(of: chevronItem) }

    init(store: SettingsStore) {
        self.store = store
        // Drop any corrupted preferred-position macOS restored before we create
        // the status items, so a stray past drag can't strand a separator
        // off-screen (see sanitizeRestoredSeparatorPositions).
        Self.sanitizeRestoredSeparatorPositions()
        // Creation order matters: newer status items appear further LEFT,
        // so create chevron first -> [alwaysHiddenSep][hiddenSep][chevron].
        chevronItem = makeChevron()
        hiddenSeparator = makeSeparator(autosaveName: "valet-hidden-separator")
        alwaysHiddenSeparator = makeSeparator(autosaveName: "valet-always-hidden-separator")
        // Start revealed: macOS restored the separators to their saved
        // positions, and collapsing before the launch check runs could
        // swallow an item that spawned further left while Valet was closed.
        // completeLaunchReconcile() collapses once the zones are verified.
        engine.toggleAll()
        apply()
    }

    /// Finish the launch check (see `launchPlan`). Keeps the restored
    /// separator positions when every hidden-zone item is hidden by the
    /// user's recorded choice; otherwise recreates the separators at the far
    /// left so the session starts with every item Shown. Collapses either way.
    func completeLaunchReconcile(_ plan: LaunchPlan) {
        persistenceLog.info("launch reconcile: \(String(describing: plan), privacy: .public)")
        if plan == .resetPositions {
            resetSeparatorPositions()
        }
        engine.collapse()
        apply()
    }

    /// Remove both separators, clear their saved preferred positions, and
    /// recreate them at the far-left anchor (newer status items appear further
    /// left, so recreating hidden then alwaysHidden keeps alwaysHidden leftmost).
    /// Used by the launch safety reset and by the separator-order guard's
    /// no-Accessibility degrade path. Caller is responsible for the following
    /// `apply()`/reveal-state restore.
    func resetSeparatorPositions() {
        NSStatusBar.system.removeStatusItem(hiddenSeparator)
        NSStatusBar.system.removeStatusItem(alwaysHiddenSeparator)
        for name in ["valet-hidden-separator", "valet-always-hidden-separator"] {
            UserDefaults.standard.removeObject(forKey: "NSStatusItem Preferred Position \(name)")
        }
        hiddenSeparator = makeSeparator(autosaveName: "valet-hidden-separator")
        alwaysHiddenSeparator = makeSeparator(autosaveName: "valet-always-hidden-separator")
    }

    /// Discard any restored "NSStatusItem Preferred Position" that would place a
    /// separator off-screen (see `isValidRestoredPosition`). macOS writes these
    /// keys on user drags, and a bad value parks the separator where it hides
    /// nothing — which the launch swallow-check reads as healthy, so it survives
    /// every launch. Removing the key lets the separator spawn at the far-left
    /// anchor (clean all-Shown state) instead. Called before the status items
    /// are created, so macOS never restores the bad value in the first place.
    static func sanitizeRestoredSeparatorPositions() {
        let screenWidth = NSScreen.screens.map { $0.frame.width }.max() ?? 0
        guard screenWidth > 0 else { return }
        for name in ["valet-hidden-separator", "valet-always-hidden-separator"] {
            let key = "NSStatusItem Preferred Position \(name)"
            guard UserDefaults.standard.object(forKey: key) != nil else { continue }
            let value = CGFloat(UserDefaults.standard.double(forKey: key))
            if !isValidRestoredPosition(value, screenWidth: screenWidth) {
                persistenceLog.notice("sanitize: DROP \(name, privacy: .public) invalid restored position \(value, privacy: .public) (screenWidth \(screenWidth, privacy: .public))")
                UserDefaults.standard.removeObject(forKey: key)
            }
        }
    }

    /// Return Valet to a clean slate without a quit/reinstall: forget every
    /// section assignment, clear the saved separator positions and rebuild the
    /// separators at the far-left anchor, then collapse. Equivalent to
    /// `defaults delete app.valet.Valet` for the layout/assignment keys.
    func reset() {
        store.assignments = [:]
        resetSeparatorPositions()
        engine.collapse()
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
        let showAll = NSMenuItem(title: "Show All Items", action: #selector(showAllItems), keyEquivalent: "")
        showAll.target = self
        menu.addItem(showAll)
        let resetItem = NSMenuItem(title: "Reset", action: #selector(resetFromMenu), keyEquivalent: "")
        resetItem.target = self
        menu.addItem(resetItem)
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

    @objc private func showAllItems() {
        // Always end in .revealedAll (toggleAll alternates revealedAll <-> collapsed).
        if engine.state != .revealedAll { toggleAll() }
    }

    @objc private func resetFromMenu() {
        reset()
    }

    /// macOS writes "NSStatusItem Preferred Position" only when the user
    /// drags the item — never on creation or at quit — so separators that
    /// were only ever placed by layout would restore nowhere and the hidden
    /// arrangement would be lost on relaunch. Record the positions ourselves
    /// whenever a separator's right edge is on-screen; macOS reads the keys
    /// back when the status items are created at the next launch.
    func captureSeparatorPositions() {
        capturePosition(of: hiddenSeparator, autosaveName: "valet-hidden-separator")
        capturePosition(of: alwaysHiddenSeparator, autosaveName: "valet-always-hidden-separator")
    }

    /// Terminate-time capture. Only meaningful while revealed: collapsed
    /// frames are distorted by the inflated spacer windows, and the capture
    /// taken during the collapse transition is already on disk.
    func captureSeparatorPositionsForTermination() {
        guard engine.state != .collapsed else {
            persistenceLog.info("terminate capture: SKIP (collapsed)")
            return
        }
        persistenceLog.info("terminate capture: running (state \(self.engine.state.rawValue, privacy: .public))")
        captureSeparatorPositions()
    }

    /// Snapshot the current separator positions as the last known-good layout.
    /// The order guard calls this on healthy refreshes. Uses the same maxX-fence
    /// math as `captureSeparatorPositions`, so it is valid in any reveal state.
    func recordGoodSeparatorPositions() {
        for (item, name) in [
            (hiddenSeparator, "valet-hidden-separator"),
            (alwaysHiddenSeparator, "valet-always-hidden-separator"),
        ] {
            guard let window = item?.button?.window, let screen = window.screen,
                  let position = separatorCapturePosition(windowFrame: window.frame, screenFrame: screen.frame)
            else { continue }
            lastGoodPositions[name] = position
        }
    }

    /// Bounce the given separators back to their last known-good positions by
    /// rewriting the preferred-position key and recreating the status item —
    /// macOS reads the key when the item is (re)created, so it lands back where
    /// it was. Permission-free (no simulated drag). A separator with no recorded
    /// good position falls back to the far-left anchor. Re-applies the current
    /// reveal state so the recreated separators get the right lengths.
    func restoreSeparatorsToLastGood(_ roles: [SeparatorRole]) {
        for role in roles {
            let name = role == .hidden ? "valet-hidden-separator" : "valet-always-hidden-separator"
            let key = "NSStatusItem Preferred Position \(name)"
            if let position = lastGoodPositions[name] {
                persistenceLog.notice("orderfix: RESTORE \(name, privacy: .public) -> \(position, privacy: .public)")
                UserDefaults.standard.set(position, forKey: key)
            } else {
                persistenceLog.notice("orderfix: RESTORE \(name, privacy: .public) -> far-left (no recorded good)")
                UserDefaults.standard.removeObject(forKey: key)
            }
            switch role {
            case .hidden:
                NSStatusBar.system.removeStatusItem(hiddenSeparator)
                hiddenSeparator = makeSeparator(autosaveName: name)
            case .alwaysHidden:
                NSStatusBar.system.removeStatusItem(alwaysHiddenSeparator)
                alwaysHiddenSeparator = makeSeparator(autosaveName: name)
            }
        }
        apply()
    }

    private func capturePosition(of item: NSStatusItem, autosaveName: String) {
        // window.screen is nil while the separator is pushed fully off-screen
        // by an inflated neighbor — keep the last good value then.
        guard let window = item.button?.window, let screen = window.screen else {
            persistenceLog.info("capture \(autosaveName, privacy: .public): SKIP window/screen nil (state \(self.engine.state.rawValue, privacy: .public))")
            return
        }
        guard let position = separatorCapturePosition(windowFrame: window.frame, screenFrame: screen.frame) else {
            persistenceLog.info("capture \(autosaveName, privacy: .public): SKIP frame=[\(window.frame.minX, privacy: .public)..\(window.frame.maxX, privacy: .public)] (state \(self.engine.state.rawValue, privacy: .public))")
            return
        }
        persistenceLog.info("capture \(autosaveName, privacy: .public): WROTE \(position, privacy: .public) frame=[\(window.frame.minX, privacy: .public)..\(window.frame.maxX, privacy: .public)] (state \(self.engine.state.rawValue, privacy: .public))")
        UserDefaults.standard.set(position, forKey: "NSStatusItem Preferred Position \(autosaveName)")
    }

    private func apply() {
        // Capture before mutating lengths, while frames still show the
        // current arrangement — then again once the new layout settles,
        // since revealed frames are the accurate ones.
        persistenceLog.info("apply: state -> \(self.engine.state.rawValue, privacy: .public)")
        captureSeparatorPositions()
        if engine.state != .collapsed {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { [weak self] in
                guard let self, self.engine.state != .collapsed else { return }
                persistenceLog.info("delayed capture firing")
                self.captureSeparatorPositions()
            }
        }
        let lengths = engine.spacerLengths
        hiddenSeparator.length = lengths.hidden
        alwaysHiddenSeparator.length = lengths.alwaysHidden
        // Three dots to echo the app icon; circled while revealed as a state cue.
        chevronItem.button?.image = NSImage(
            systemSymbolName: engine.state == .collapsed ? "ellipsis" : "ellipsis.circle",
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
        return UInt32(exactly: window.windowNumber)
    }
}
