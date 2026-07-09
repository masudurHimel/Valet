import AppKit
import SwiftUI

enum SettingsTab: String, CaseIterable {
    case items, behavior, hotkeys, permissions, about
}

@MainActor
final class SettingsWindowController {
    private var window: NSWindow?
    private let makeRoot: (Binding<SettingsTab>) -> AnyView
    private var selectedTab = SettingsTab.items

    init(makeRoot: @escaping (Binding<SettingsTab>) -> AnyView) {
        self.makeRoot = makeRoot
    }

    func show(tab: SettingsTab = .items) {
        selectedTab = tab
        if window == nil {
            let binding = Binding<SettingsTab>(
                get: { [weak self] in self?.selectedTab ?? .items },
                set: { [weak self] in self?.selectedTab = $0 }
            )
            let hosting = NSHostingController(rootView: makeRoot(binding))
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
