import Foundation
import Testing
@testable import Valet

@Suite struct DragPlannerTests {
    // Layout: alwaysHiddenSep at x 300-308, hiddenSep at x 500-508.
    let seps = SeparatorFrames(
        hidden: CGRect(x: 500, y: 0, width: 8, height: 24),
        alwaysHidden: CGRect(x: 300, y: 0, width: 8, height: 24)
    )

    private func item(x: CGFloat, width: CGFloat = 30) -> MenuBarItemInfo {
        MenuBarItemInfo(
            windowID: 1, ownerPID: 100, ownerName: "App", bundleID: "com.a",
            frame: CGRect(x: x, y: 0, width: width, height: 24), key: "com.a#0"
        )
    }

    @Test func movesShownItemIntoHiddenSection() {
        let plan = dragPlan(item: item(x: 600), target: .hidden, separators: seps)
        #expect(plan != nil)
        #expect(plan!.from == CGPoint(x: 615, y: 12))
        #expect(plan!.to.x < 500)          // left of hidden separator
        #expect(plan!.to.x > 308)          // right of always-hidden separator
        #expect(plan!.to.y == 12)
    }

    @Test func movesHiddenItemToShown() {
        let plan = dragPlan(item: item(x: 400), target: .shown, separators: seps)
        #expect(plan != nil)
        #expect(plan!.to.x > 508)          // right of hidden separator
    }

    @Test func movesItemToAlwaysHidden() {
        let plan = dragPlan(item: item(x: 600), target: .alwaysHidden, separators: seps)
        #expect(plan != nil)
        #expect(plan!.to.x < 300)          // left of always-hidden separator
    }

    @Test func returnsNilWhenAlreadyInTargetSection() {
        #expect(dragPlan(item: item(x: 600), target: .shown, separators: seps) == nil)
        #expect(dragPlan(item: item(x: 400), target: .hidden, separators: seps) == nil)
        #expect(dragPlan(item: item(x: 100), target: .alwaysHidden, separators: seps) == nil)
    }
}
