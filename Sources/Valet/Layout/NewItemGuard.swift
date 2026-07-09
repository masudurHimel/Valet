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
    private let assigner: SectionAssigner
    private var cancellable: AnyCancellable?

    init(store: SettingsStore, introspector: ItemIntrospector, assigner: SectionAssigner) {
        self.store = store
        self.assigner = assigner
        cancellable = introspector.$items.sink { [weak self] items in
            self?.process(items)
        }
    }

    private func process(_ items: [MenuBarItemInfo]) {
        guard !assigner.isMoving else { return }
        guard let separators = assigner.currentSeparatorFrames() else { return }

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
