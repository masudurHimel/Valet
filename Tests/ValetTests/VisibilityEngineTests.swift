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
