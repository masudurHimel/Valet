import Foundation
import Testing
@testable import Valet

private func item(_ windowID: UInt32, bundle: String?, owner: String = "App", x: CGFloat) -> MenuBarItemInfo {
    MenuBarItemInfo(
        windowID: windowID, ownerPID: 100, ownerName: owner,
        bundleID: bundle, frame: CGRect(x: x, y: 0, width: 30, height: 24), key: ""
    )
}

@Suite struct ReconcilerTests {
    @Test func keysSingleItemPerApp() {
        let keyed = keyedItems([item(1, bundle: "com.a", x: 50), item(2, bundle: "com.b", x: 10)])
        #expect(keyed.map(\.key) == ["com.b#0", "com.a#0"])  // sorted left-to-right
    }

    @Test func keysMultipleItemsFromOneAppByPosition() {
        let keyed = keyedItems([item(1, bundle: "com.a", x: 200), item(2, bundle: "com.a", x: 100)])
        #expect(keyed.map(\.key) == ["com.a#0", "com.a#1"])
        #expect(keyed[0].windowID == 2)  // leftmost gets index 0
    }

    @Test func fallsBackToOwnerNameWithoutBundleID() {
        let keyed = keyedItems([item(1, bundle: nil, owner: "SomeTool", x: 10)])
        #expect(keyed[0].key == "SomeTool#0")
    }

    @Test func reconcileAssignsSavedSectionsAndDefaultsToShown() {
        let items = [item(1, bundle: "com.a", x: 10), item(2, bundle: "com.b", x: 50)]
        let result = reconcile(assignments: ["com.a#0": .alwaysHidden], items: items)
        #expect(result.count == 2)
        #expect(result[0].section == .alwaysHidden)
        #expect(result[1].section == .shown)
    }
}
