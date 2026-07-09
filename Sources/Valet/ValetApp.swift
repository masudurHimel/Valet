import AppKit
import Combine

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
    }

    private func applyHotkey(_ hotkey: Hotkey?) {
        if let hotkey {
            hotkeyManager.register(hotkey)
        } else {
            hotkeyManager.unregister()
        }
    }
}
