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
    private(set) var settingsStore: SettingsStore!
    private(set) var menuBarManager: MenuBarManager!

    func applicationDidFinishLaunching(_ notification: Notification) {
        settingsStore = SettingsStore(defaults: .standard)
        menuBarManager = MenuBarManager(store: settingsStore)
    }
}
