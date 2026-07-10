import Foundation

enum LaunchPlan: Equatable {
    case keepPositions
    case resetPositions
}

/// The layer-25 window list holds phantom windows that are not in the menu
/// bar at all: Control Center keeps one per module, and TextInputMenuAgent
/// parks one at the far left of the screen — permanently inside any hidden
/// zone, which made `launchPlan` reset the separators at every launch. Real
/// status items pack right-to-left with no gaps, so keep only the items
/// whose windows connect to the right-anchored contiguous run. The separator
/// frames count as connectors (Valet's own windows are excluded from the
/// item list); the chevron still leaves a ~31 pt hole, which the tolerance
/// bridges. Only valid on a revealed layout — collapsed spacers push hidden
/// items off-screen, detaching them from the run.
func packedStrip(
    items: [MenuBarItemInfo],
    separators: SeparatorFrames,
    tolerance: CGFloat = 48
) -> [MenuBarItemInfo] {
    let connectors = [separators.hidden, separators.alwaysHidden]
    let frames = (items.map(\.frame) + connectors).sorted { $0.maxX > $1.maxX }
    guard var runMinX = frames.first?.maxX else { return [] }
    for frame in frames where frame.maxX >= runMinX - tolerance {
        runMinX = min(runMinX, frame.minX)
    }
    let leftEdge = runMinX
    return items.filter { $0.frame.maxX >= leftEdge - tolerance }
}

/// Decide, from the state macOS restored at launch, whether the separators
/// may stay where they are. They may only if every item physically inside a
/// hidden zone is there by the user's recorded choice — an item at least as
/// visible as its assignment is fine, but an unassigned item (or one more
/// hidden than assigned) means the restored boundary swallowed something the
/// user never hid, so the separators must reset to the far left and every
/// item starts the session Shown.
func launchPlan(
    items: [MenuBarItemInfo],
    separators: SeparatorFrames,
    assignments: [String: BarSection]
) -> LaunchPlan {
    func rank(_ section: BarSection) -> Int {
        switch section {
        case .shown: return 0
        case .hidden: return 1
        case .alwaysHidden: return 2
        }
    }
    for item in items {
        let actual = actualSection(of: item, separators: separators)
        let assigned = assignments[item.key] ?? .shown
        if rank(actual) > rank(assigned) { return .resetPositions }
    }
    return .keepPositions
}
