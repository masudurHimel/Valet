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
