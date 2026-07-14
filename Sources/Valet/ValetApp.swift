import AppKit
import Combine
import SwiftUI

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
    private(set) var settingsStore: SettingsStore!
    private(set) var menuBarManager: MenuBarManager!
    private(set) var hotkeyManager = HotkeyManager()
    private(set) var introspector: ItemIntrospector!
    private var settingsWindow: SettingsWindowController!
    private var newItemGuard: NewItemGuard?
    private var separatorOrderGuard: SeparatorOrderGuard?
    private var hotkeyObservation: AnyCancellable?

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

        introspector = ItemIntrospector()
        introspector.startAutoRefresh(interval: 5)
        let assigner = SectionAssigner(
            store: settingsStore, introspector: introspector,
            mover: ItemMover(), menuBarManager: menuBarManager
        )
        // Launch check: the bar starts revealed; give the restored status
        // items a moment to settle, verify that nothing sits in a hidden
        // zone without the user's recorded choice, then collapse (resetting
        // the separators to the far left if something would be swallowed).
        // NewItemGuard is created after, so its first snapshot is clean.
        Task { @MainActor [weak self] in
            guard let self else { return }
            var plan = LaunchPlan.resetPositions  // unverifiable zones → don't hide
            for _ in 0..<5 {  // separator windows can take a moment to exist
                try? await Task.sleep(for: .milliseconds(300))
                self.introspector.refresh()
                guard let separators = assigner.currentSeparatorFrames() else { continue }
                plan = launchPlan(
                    items: packedStrip(items: self.introspector.items, separators: separators),
                    separators: separators,
                    assignments: self.settingsStore.assignments
                )
                break
            }
            self.menuBarManager.completeLaunchReconcile(plan)
            self.newItemGuard = NewItemGuard(
                store: self.settingsStore, introspector: self.introspector, assigner: assigner
            )
            self.separatorOrderGuard = SeparatorOrderGuard(
                introspector: self.introspector, assigner: assigner,
                menuBarManager: self.menuBarManager
            )
        }
        settingsWindow = SettingsWindowController {
            AnyView(SettingsRootView())
        }
        menuBarManager.onOpenSettings = { [weak self] in
            self?.settingsWindow.show()
        }

        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded")
        if !hasOnboarded {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
            settingsWindow.show()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        menuBarManager.captureSeparatorPositionsForTermination()
    }

    private func applyHotkey(_ hotkey: Hotkey?) {
        if let hotkey {
            hotkeyManager.register(hotkey)
        } else {
            hotkeyManager.unregister()
        }
    }
}
