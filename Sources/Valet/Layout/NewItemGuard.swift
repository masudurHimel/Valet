import AppKit
import Combine

enum NewItemDecision: Equatable {
    case rescueToShown
    case adoptAssignment(BarSection)
    case none
}

/// macOS places newly created status items at the far left of the item
/// area — inside Valet's hidden zone while collapsed. Decide what to do
/// with an unassigned item found in a hidden zone based on whether we
/// watched it sit in the Shown strip earlier THIS session:
/// - seen in Shown this session + now in a hidden zone: the user Cmd-dragged
///   it there manually → adopt that as its assignment
/// - first sighting this session already inside a hidden zone: it spawned
///   there (or a separator was restored around it) → rescue to Shown
/// - assigned or in the shown strip: leave it alone
func newItemDecision(seenInShownThisSession: Bool, assignment: BarSection?, actual: BarSection) -> NewItemDecision {
    guard assignment == nil, actual != .shown else { return .none }
    return seenInShownThisSession ? .adoptAssignment(actual) : .rescueToShown
}

@MainActor
final class NewItemGuard {
    private let store: SettingsStore
    private let assigner: SectionAssigner
    private var cancellable: AnyCancellable?
    /// Keys observed sitting in the Shown strip earlier this session.
    /// Deliberately in-memory only: persisted knowledge can't distinguish a
    /// user's Cmd-drag from a separator being restored around the item at launch.
    private var seenInShown: Set<String> = []

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

        let sections = items.map { ($0.key, actualSection(of: $0, separators: separators)) }
        let decisions = sections.map { key, actual in
            (key, newItemDecision(
                seenInShownThisSession: seenInShown.contains(key),
                assignment: store.assignments[key],
                actual: actual
            ))
        }
        for (key, actual) in sections where actual == .shown {
            seenInShown.insert(key)
        }

        for (key, decision) in decisions {
            switch decision {
            case .none:
                break
            case .adoptAssignment(let section):
                store.assignments[key] = section
            case .rescueToShown:
                // Rescue needs the simulated drag; without Accessibility the
                // item stays a rescue candidate for a later refresh.
                guard PermissionsService.hasAccessibility() else { continue }
                Task { await assigner.move(key: key, to: .shown) }
                return  // one rescue per refresh cycle; the next pass handles the rest
            }
        }
    }
}
