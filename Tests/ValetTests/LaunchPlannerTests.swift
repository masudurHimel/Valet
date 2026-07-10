import CoreGraphics
import Testing
@testable import Valet

@Suite struct LaunchPlannerTests {
    // Separators at 8 pt, revealed: alwaysHidden at x 300, hidden at x 500.
    // Items left of 300 are Always Hidden, 300..<500 Hidden, else Shown.
    private let separators = SeparatorFrames(
        hidden: CGRect(x: 500, y: 0, width: 8, height: 24),
        alwaysHidden: CGRect(x: 300, y: 0, width: 8, height: 24)
    )

    private func item(x: CGFloat, key: String) -> MenuBarItemInfo {
        MenuBarItemInfo(
            windowID: 1, ownerPID: 1, ownerName: "App", bundleID: "com.app",
            frame: CGRect(x: x, y: 0, width: 24, height: 24), key: key
        )
    }

    @Test func keepsPositionsWhenEveryZoneItemIsAssignedThere() {
        let plan = launchPlan(
            items: [item(x: 100, key: "a#0"), item(x: 400, key: "b#0"), item(x: 700, key: "c#0")],
            separators: separators,
            assignments: ["a#0": .alwaysHidden, "b#0": .hidden]
        )
        #expect(plan == .keepPositions)
    }

    @Test func resetsWhenUnassignedItemSitsInAZone() {
        // e.g. an item that spawned at the far left while Valet was closed.
        let plan = launchPlan(
            items: [item(x: 100, key: "a#0")],
            separators: separators,
            assignments: [:]
        )
        #expect(plan == .resetPositions)
    }

    @Test func resetsWhenItemIsMoreHiddenThanAssigned() {
        let plan = launchPlan(
            items: [item(x: 100, key: "a#0")],
            separators: separators,
            assignments: ["a#0": .hidden]
        )
        #expect(plan == .resetPositions)
    }

    @Test func keepsWhenItemIsMoreVisibleThanAssigned() {
        // Assigned always-hidden but physically only Hidden (or Shown): the
        // user can still reach it, so the restored layout is safe.
        let plan = launchPlan(
            items: [item(x: 400, key: "a#0"), item(x: 700, key: "b#0")],
            separators: separators,
            assignments: ["a#0": .alwaysHidden, "b#0": .hidden]
        )
        #expect(plan == .keepPositions)
    }

    @Test func keepsWhenZonesAreEmpty() {
        let plan = launchPlan(
            items: [item(x: 700, key: "a#0")],
            separators: separators,
            assignments: [:]
        )
        #expect(plan == .keepPositions)
    }
}

@Suite struct PackedStripTests {
    private func item(x: CGFloat, width: CGFloat = 24, key: String) -> MenuBarItemInfo {
        MenuBarItemInfo(
            windowID: 1, ownerPID: 1, ownerName: "App", bundleID: "com.app",
            frame: CGRect(x: x, y: 0, width: width, height: 24), key: key
        )
    }

    // Contiguous run anchored at the right: [aHSep 836][hidden 844][sep 892]
    // [shown 900..924]. The separator frames bridge the item list where
    // Valet's own windows are excluded.
    private let separators = SeparatorFrames(
        hidden: CGRect(x: 884, y: 0, width: 8, height: 24),
        alwaysHidden: CGRect(x: 836, y: 0, width: 8, height: 24)
    )

    @Test func dropsDetachedPhantomWindows() {
        // TextInputMenuAgent parks a phantom layer-25 window at the far left
        // of the screen, hundreds of points away from the packed strip.
        let strip = packedStrip(
            items: [
                item(x: 0, width: 44, key: "phantom#0"),
                item(x: 812, key: "hidden#0"),
                item(x: 844, width: 40, key: "hiddenZone#0"),
                item(x: 900, key: "shown#0"),
            ],
            separators: separators
        )
        #expect(strip.map(\.key) == ["hidden#0", "hiddenZone#0", "shown#0"])
    }

    @Test func keepsOverlappingWindows() {
        // Control Center keeps a window per module; several overlap the real
        // items. They connect to the run, so they stay (harmlessly Shown).
        let strip = packedStrip(
            items: [item(x: 900, key: "a#0"), item(x: 910, width: 30, key: "b#0")],
            separators: separators
        )
        #expect(strip.count == 2)
    }

    @Test func bridgesTheChevronHole() {
        // Valet's chevron (~31 pt) is excluded from the item list and leaves
        // a hole in the run; the tolerance must bridge it.
        let strip = packedStrip(
            items: [item(x: 900, key: "a#0"), item(x: 955, key: "b#0")],
            separators: separators
        )
        #expect(strip.count == 2)
    }

    @Test func phantomDoesNotVetoPersistence() {
        // Regression (2026-07-11): the phantom judged as "in the always-hidden
        // zone but assigned Shown" forced resetPositions on every launch, so
        // the hidden arrangement never survived a relaunch.
        let items = [
            item(x: 0, width: 44, key: "phantom#0"),
            item(x: 844, width: 40, key: "docker#0"),
            item(x: 900, key: "shown#0"),
        ]
        let assignments: [String: BarSection] = ["phantom#0": .shown, "docker#0": .hidden]
        #expect(launchPlan(items: items, separators: separators, assignments: assignments) == .resetPositions)
        let plan = launchPlan(
            items: packedStrip(items: items, separators: separators),
            separators: separators,
            assignments: assignments
        )
        #expect(plan == .keepPositions)
    }
}
