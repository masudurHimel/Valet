import Foundation
import Testing
@testable import Valet

@Suite struct NewItemGuardTests {
    // Collapsed-state geometry from a real capture: both spacers expanded,
    // alwaysHidden spans [-8916, -3900], hidden spans [-3900, 1116].
    let collapsedSeps = SeparatorFrames(
        hidden: CGRect(x: -3900, y: 0, width: 5016, height: 24),
        alwaysHidden: CGRect(x: -8916, y: 0, width: 5016, height: 24)
    )

    private func item(x: CGFloat, width: CGFloat = 37) -> MenuBarItemInfo {
        MenuBarItemInfo(
            windowID: 1, ownerPID: 100, ownerName: "App", bundleID: "com.a",
            frame: CGRect(x: x, y: 0, width: width, height: 24), key: "com.a#0"
        )
    }

    @Test func actualSectionInCollapsedState() {
        // Freshly spawned item lands far left, past the always-hidden separator.
        #expect(actualSection(of: item(x: -8977), separators: collapsedSeps) == .alwaysHidden)
        // Between the separators.
        #expect(actualSection(of: item(x: -3950, width: 30) , separators: collapsedSeps) == .hidden)
        // Right of the hidden separator (visible strip).
        #expect(actualSection(of: item(x: 1142), separators: collapsedSeps) == .shown)
    }

    @Test func actualSectionInRevealedState() {
        let revealed = SeparatorFrames(
            hidden: CGRect(x: 500, y: 0, width: 8, height: 24),
            alwaysHidden: CGRect(x: 300, y: 0, width: 8, height: 24)
        )
        #expect(actualSection(of: item(x: 100), separators: revealed) == .alwaysHidden)
        #expect(actualSection(of: item(x: 400, width: 30), separators: revealed) == .hidden)
        #expect(actualSection(of: item(x: 600), separators: revealed) == .shown)
    }

    @Test func firstSightingInHiddenZoneUnassignedIsRescued() {
        // Covers both a freshly spawned item and one seen only in PAST sessions
        // (e.g. it spawned while Valet was closed and the restored separator
        // landed to its right): nothing persisted feeds this decision, so an
        // app relaunch always starts from "not seen in Shown this session".
        #expect(newItemDecision(seenInShownThisSession: false, assignment: nil, actual: .alwaysHidden)
            == .rescueToShown)
        #expect(newItemDecision(seenInShownThisSession: false, assignment: nil, actual: .hidden)
            == .rescueToShown)
    }

    @Test func seenInShownThenHiddenUnassignedAdoptsManualDrag() {
        #expect(newItemDecision(seenInShownThisSession: true, assignment: nil, actual: .hidden)
            == .adoptAssignment(.hidden))
        #expect(newItemDecision(seenInShownThisSession: true, assignment: nil, actual: .alwaysHidden)
            == .adoptAssignment(.alwaysHidden))
    }

    @Test func assignedOrShownItemsAreLeftAlone() {
        #expect(newItemDecision(seenInShownThisSession: false, assignment: .hidden, actual: .hidden) == .none)
        #expect(newItemDecision(seenInShownThisSession: true, assignment: .hidden, actual: .shown) == .none)
        #expect(newItemDecision(seenInShownThisSession: false, assignment: nil, actual: .shown) == .none)
        #expect(newItemDecision(seenInShownThisSession: true, assignment: nil, actual: .shown) == .none)
    }
}
