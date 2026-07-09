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
        let store = settingsStore!
        let intro = introspector!
        settingsWindow = SettingsWindowController { binding in
            AnyView(SettingsRootView(store: store, introspector: intro,
                                     assigner: assigner, selectedTab: binding))
        }
        menuBarManager.onOpenSettings = { [weak self] in
            self?.settingsWindow.show(tab: .items)
        }

        let hasOnboarded = UserDefaults.standard.bool(forKey: "hasOnboarded")
        if !hasOnboarded {
            UserDefaults.standard.set(true, forKey: "hasOnboarded")
            settingsWindow.show(tab: .permissions)
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
