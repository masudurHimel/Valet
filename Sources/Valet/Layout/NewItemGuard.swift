import AppKit
import Combine

enum NewItemDecision: Equatable {
    case rescueToShown
    case adoptAssignment(BarSection)
    case none
}

/// macOS places newly created status items at the far left of the item
/// area — inside Valet's hidden zone while collapsed. Decide what to do
/// with an item based on whether we've seen it before and where it is:
/// - never seen + unassigned + hidden zone: it spawned there → rescue to Shown
/// - seen before + unassigned + hidden zone: the user Cmd-dragged it there
///   manually → adopt that as its assignment
/// - assigned or in the shown strip: leave it alone
func newItemDecision(isKnown: Bool, assignment: BarSection?, actual: BarSection) -> NewItemDecision {
    guard assignment == nil, actual != .shown else { return .none }
    return isKnown ? .adoptAssignment(actual) : .rescueToShown
}

@MainActor
final class NewItemGuard {
    private let store: SettingsStore
    private let introspector: ItemIntrospector
    private let assigner: SectionAssigner
    private let menuBarManager: MenuBarManager
    private var cancellable: AnyCancellable?

    init(store: SettingsStore, introspector: ItemIntrospector,
         assigner: SectionAssigner, menuBarManager: MenuBarManager) {
        self.store = store
        self.introspector = introspector
        self.assigner = assigner
        self.menuBarManager = menuBarManager
        cancellable = introspector.$items.sink { [weak self] items in
            self?.process(items)
        }
    }

    private func process(_ items: [MenuBarItemInfo]) {
        guard !assigner.isMoving else { return }
        let ids = menuBarManager.separatorWindowIDs
        guard let hiddenID = ids.hidden, let alwaysID = ids.alwaysHidden,
              let hiddenFrame = introspector.frame(ofWindowID: hiddenID),
              let alwaysFrame = introspector.frame(ofWindowID: alwaysID)
        else { return }
        let separators = SeparatorFrames(hidden: hiddenFrame, alwaysHidden: alwaysFrame)

        for item in items {
            let key = item.key
            let decision = newItemDecision(
                isKnown: store.knownKeys.contains(key),
                assignment: store.assignments[key],
                actual: actualSection(of: item, separators: separators)
            )
            switch decision {
            case .none:
                if !store.knownKeys.contains(key) {
                    store.knownKeys.insert(key)
                }
            case .adoptAssignment(let section):
                store.assignments[key] = section
            case .rescueToShown:
                // Rescue needs the simulated drag; without Accessibility the
                // item stays a rescue candidate for a later refresh.
                guard PermissionsService.hasAccessibility() else { continue }
                store.knownKeys.insert(key)
                Task { await assigner.move(key: key, to: .shown) }
                return  // one rescue per refresh cycle; the next pass handles the rest
            }
        }
    }
}
