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

    /// Live frames of the two separator windows, in the same coordinate
    /// space as introspected item frames. Works in any reveal state and
    /// needs no permissions.
    func currentSeparatorFrames() -> SeparatorFrames? {
        let ids = menuBarManager.separatorWindowIDs
        guard let hiddenID = ids.hidden, let alwaysID = ids.alwaysHidden,
              let hiddenFrame = introspector.frame(ofWindowID: hiddenID),
              let alwaysFrame = introspector.frame(ofWindowID: alwaysID)
        else { return nil }
        return SeparatorFrames(hidden: hiddenFrame, alwaysHidden: alwaysFrame)
    }

    /// Moves the real menu bar item, then records the assignment.
    /// Flow: reveal everything -> re-introspect (fresh frames) -> plan -> drag
    /// -> re-introspect -> restore reveal state.
    func move(key: String, to section: BarSection) async {
        guard !isMoving else { return }
        guard PermissionsService.hasAccessibility() else {
            store.assignments[key] = section
            lastError = "Valet saved your choice, but can't move icons itself without Accessibility "
                + "(System Settings > Privacy & Security). You can also hold Cmd and drag the icon "
                + "across the | separators yourself."
            return
        }
        isMoving = true
        defer { isMoving = false }
        lastError = nil

        menuBarManager.revealAllTemporarily()
        try? await Task.sleep(for: .milliseconds(300))
        introspector.refresh()

        guard let item = introspector.items.first(where: { $0.key == key }),
              let separators = currentSeparatorFrames()
        else {
            lastError = "Couldn't locate the item or separators. Try again with the menu bar visible."
            menuBarManager.endTemporaryReveal()
            return
        }

        if let plan = dragPlan(item: item, target: section, separators: separators) {
            await mover.perform(plan)
        }
        store.assignments[key] = section
        introspector.refresh()
        menuBarManager.endTemporaryReveal()
    }
}
