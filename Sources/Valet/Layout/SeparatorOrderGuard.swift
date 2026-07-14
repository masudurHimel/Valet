import AppKit
import Combine
import Foundation

/// Which of Valet's two separators is the subject of an order fix.
enum SeparatorRole: Equatable {
    case hidden
    case alwaysHidden
}

/// The separators that currently sit illegally to the right of the chevron,
/// in the order they must be dragged back to rebuild
/// `[alwaysHidden][hidden][chevron]`: `.hidden` first (to just left of the
/// chevron), then `.alwaysHidden` (to just left of the now-fixed hidden one).
struct SeparatorFix: Equatable {
    var misordered: [SeparatorRole]
}

/// Reports when the separators are NOT in the canonical
/// `[alwaysHidden][hidden][chevron]` order, so the guard can bounce them back.
/// Returns `nil` when healthy. Two kinds of disorder, both judged by the
/// left→right ordering of frame edges (reliable in any reveal state — the
/// collapsed layout distorts spacer widths, not edge ordering), and both using
/// fully-past (`minX >= maxX`) comparisons so adjacent-edge jitter can't cause a
/// false positive:
/// - a separator dragged right of the chevron (`separator.minX >= chevron.maxX`),
///   reported in `misordered`;
/// - the two separators swapped, i.e. alwaysHidden sitting right of hidden
///   (`alwaysHidden.minX >= hidden.maxX`). A pure swap with both still left of
///   the chevron yields a non-nil fix with an empty `misordered` list — the
///   recovery rebuilds both separators regardless, so the list is informational.
func separatorOrderFix(chevron: CGRect, separators: SeparatorFrames) -> SeparatorFix? {
    var misordered: [SeparatorRole] = []
    if separators.hidden.minX >= chevron.maxX { misordered.append(.hidden) }
    if separators.alwaysHidden.minX >= chevron.maxX { misordered.append(.alwaysHidden) }
    let swapped = separators.alwaysHidden.minX >= separators.hidden.maxX
    guard !misordered.isEmpty || swapped else { return nil }
    return SeparatorFix(misordered: misordered)
}

/// Watches each introspection refresh for a separator that has ended up to the
/// right of the chevron. While the layout is healthy it records each separator's
/// position as "last known-good"; when it finds a separator right of the chevron
/// it asks the manager to bounce that separator back to its recorded good
/// position (permission-free — no simulated drag needed).
/// Detection is purely geometric in every reveal state (see `separatorOrderFix`):
/// it pre-empts while revealed and self-recovers from the already-collapsed,
/// chevron-pushed-off-screen state alike. Because it compares actual frame
/// ordering, an off-screen chevron caused by a sleeping/disconnected display —
/// separators still in their normal left positions — correctly reads as healthy
/// and triggers nothing.
@MainActor
final class SeparatorOrderGuard {
    private let introspector: ItemIntrospector
    private let assigner: SectionAssigner
    private let menuBarManager: MenuBarManager
    private var cancellable: AnyCancellable?

    init(introspector: ItemIntrospector, assigner: SectionAssigner, menuBarManager: MenuBarManager) {
        self.introspector = introspector
        self.assigner = assigner
        self.menuBarManager = menuBarManager
        cancellable = introspector.$items.sink { [weak self] _ in
            self?.process()
        }
    }

    private func process() {
        guard !assigner.isMoving else {
            persistenceLog.info("orderguard: skip (isMoving)")
            return
        }
        guard let chevronID = menuBarManager.chevronWindowID,
              let chevron = introspector.frame(ofWindowID: chevronID),
              let separators = assigner.currentSeparatorFrames()
        else {
            persistenceLog.info("orderguard: UNRESOLVED frames (chevronID=\(self.menuBarManager.chevronWindowID.map(String.init) ?? "nil", privacy: .public))")
            return
        }
        let fix = separatorOrderFix(chevron: chevron, separators: separators)
        persistenceLog.notice("orderguard: chevron=[\(chevron.minX, privacy: .public)..\(chevron.maxX, privacy: .public)] hidden=[\(separators.hidden.minX, privacy: .public)..\(separators.hidden.maxX, privacy: .public)] aHidden=[\(separators.alwaysHidden.minX, privacy: .public)..\(separators.alwaysHidden.maxX, privacy: .public)] fix=\(String(describing: fix), privacy: .public)")
        guard let fix else {
            // Healthy: remember where the separators sit so we can bounce them
            // back here if the user later drags one right of the chevron.
            menuBarManager.recordGoodSeparatorPositions()
            return
        }
        persistenceLog.notice("orderguard: DETECTED \(String(describing: fix.misordered), privacy: .public) -> restore to last-good")
        menuBarManager.restoreSeparatorsToLastGood(fix.misordered)
    }
}
