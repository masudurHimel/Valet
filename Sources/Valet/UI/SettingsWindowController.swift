import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let makeRoot: () -> AnyView

    init(makeRoot: @escaping () -> AnyView) {
        self.makeRoot = makeRoot
    }

    func show() {
        if window == nil {
            let hosting = NSHostingController(rootView: makeRoot())
            let w = NSWindow(contentViewController: hosting)
            w.title = "Valet"
            w.styleMask = [.titled, .closable, .miniaturizable]
            w.isReleasedWhenClosed = false
            w.setContentSize(NSSize(width: 420, height: 360))
            w.center()
            window = w
        }
        NSApp.activate(ignoringOtherApps: true)
        window?.makeKeyAndOrderFront(nil)
    }
}
