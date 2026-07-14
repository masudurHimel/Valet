import Foundation
import Testing
@testable import Valet

@Suite struct SeparatorOrderGuardTests {
    // Healthy revealed layout: [alwaysHidden @300][hidden @500][chevron @700].
    private func chevron(x: CGFloat = 700) -> CGRect {
        CGRect(x: x, y: 0, width: 30, height: 24)
    }
    private func seps(hiddenX: CGFloat, alwaysX: CGFloat) -> SeparatorFrames {
        SeparatorFrames(
            hidden: CGRect(x: hiddenX, y: 0, width: 8, height: 24),
            alwaysHidden: CGRect(x: alwaysX, y: 0, width: 8, height: 24)
        )
    }

    @Test func healthyOrderReturnsNil() {
        #expect(separatorOrderFix(chevron: chevron(), separators: seps(hiddenX: 500, alwaysX: 300)) == nil)
    }

    @Test func hiddenSeparatorRightOfChevron() {
        // hidden dragged to 760 (minX 760 >= chevron.maxX 730); alwaysHidden still left.
        let fix = separatorOrderFix(chevron: chevron(), separators: seps(hiddenX: 760, alwaysX: 300))
        #expect(fix == SeparatorFix(misordered: [.hidden]))
    }

    @Test func alwaysHiddenSeparatorRightOfChevron() {
        let fix = separatorOrderFix(chevron: chevron(), separators: seps(hiddenX: 500, alwaysX: 760))
        #expect(fix == SeparatorFix(misordered: [.alwaysHidden]))
    }

    @Test func bothSeparatorsRightOfChevronOrderedHiddenFirst() {
        let fix = separatorOrderFix(chevron: chevron(), separators: seps(hiddenX: 800, alwaysX: 760))
        #expect(fix == SeparatorFix(misordered: [.hidden, .alwaysHidden]))
    }

    @Test func separatorTouchingChevronRightEdgeIsIllegal() {
        // minX (730) == chevron.maxX (730): the separator sits right of the chevron.
        let fix = separatorOrderFix(chevron: chevron(), separators: seps(hiddenX: 730, alwaysX: 300))
        #expect(fix == SeparatorFix(misordered: [.hidden]))
    }

    @Test func separatorImmediatelyLeftOfChevronIsHealthy() {
        // hidden spans 692..700; its minX (692) < chevron.maxX (730), so it's healthy.
        let fix = separatorOrderFix(chevron: chevron(), separators: seps(hiddenX: 692, alwaysX: 300))
        #expect(fix == nil)
    }
}
