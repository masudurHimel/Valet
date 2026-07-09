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
