import Foundation
import Testing
@testable import Valet

@Suite struct VisibilityEngineTests {
    @Test func startsCollapsedWithBothSpacersExpanded() {
        let engine = VisibilityEngine()
        #expect(engine.state == .collapsed)
        #expect(engine.spacerLengths == SpacerLengths(hidden: 10_000, alwaysHidden: 10_000))
    }

    @Test func toggleRevealsHiddenButNotAlwaysHidden() {
        var engine = VisibilityEngine()
        engine.toggle()
        #expect(engine.state == .revealed)
        #expect(engine.spacerLengths == SpacerLengths(hidden: 8, alwaysHidden: 10_000))
        engine.toggle()
        #expect(engine.state == .collapsed)
    }

    @Test func toggleAllRevealsEverything() {
        var engine = VisibilityEngine()
        engine.toggleAll()
        #expect(engine.state == .revealedAll)
        #expect(engine.spacerLengths == SpacerLengths(hidden: 8, alwaysHidden: 8))
        engine.toggleAll()
        #expect(engine.state == .collapsed)
    }

    @Test func toggleFromRevealedAllCollapses() {
        var engine = VisibilityEngine()
        engine.toggleAll()
        engine.toggle()
        #expect(engine.state == .collapsed)
    }

    @Test func rehideDeadlineOnlyWhenRevealedAndEnabled() {
        var engine = VisibilityEngine()
        let now = Date(timeIntervalSince1970: 1000)
        #expect(engine.rehideDeadline(now: now, delay: 15, autoRehide: true) == nil)
        engine.toggle()
        #expect(engine.rehideDeadline(now: now, delay: 15, autoRehide: true)
            == Date(timeIntervalSince1970: 1015))
        #expect(engine.rehideDeadline(now: now, delay: 15, autoRehide: false) == nil)
    }
}

@Suite struct SeparatorCapturePositionTests {
    private let screen = CGRect(x: 0, y: 0, width: 1512, height: 982)

    @Test func capturesNormalSeparatorFromRightEdge() {
        // Values from the 2026-07-11 debugging session's unified log.
        let pos = separatorCapturePosition(
            windowFrame: CGRect(x: 1077, y: 945, width: 24, height: 37), screenFrame: screen
        )
        #expect(pos == 419)
    }

    @Test func capturesInflatedSpacerFence() {
        // Revealed-state always-hidden spacer: pushed far left but its right
        // edge is the fence and must keep being captured (load-bearing for
        // Cmd-drags done in the plain revealed state).
        let pos = separatorCapturePosition(
            windowFrame: CGRect(x: -4010, y: 945, width: 5016, height: 37), screenFrame: screen
        )
        #expect(pos == 514)
    }

    @Test func skipsPreLayoutPlaceholderFrame() {
        // At creation the window parks at the screen origin before layout;
        // capturing it wrote garbage into both keys at every launch.
        let pos = separatorCapturePosition(
            windowFrame: CGRect(x: 0, y: 0, width: 24, height: 37), screenFrame: screen
        )
        #expect(pos == nil)
    }

    @Test func skipsWhenDerivedPositionIsOffScreen() {
        // Collapsed spacer pushed almost fully off-screen left.
        let pos = separatorCapturePosition(
            windowFrame: CGRect(x: -9001, y: 945, width: 5016, height: 37), screenFrame: screen
        )
        #expect(pos == nil)
    }
}
