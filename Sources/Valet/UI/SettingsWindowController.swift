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
