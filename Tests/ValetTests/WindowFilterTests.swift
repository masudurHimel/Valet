import Foundation
import Testing
@testable import Valet

private func rawWindow(
    layer: Int = 25, pid: Int = 500, windowID: Int = 1,
    x: Double = 100, y: Double = 0, w: Double = 30, h: Double = 24,
    owner: String = "SomeApp"
) -> [String: Any] {
    [
        "kCGWindowLayer": layer,
        "kCGWindowOwnerPID": pid,
        "kCGWindowNumber": windowID,
        "kCGWindowOwnerName": owner,
        "kCGWindowBounds": ["X": x, "Y": y, "Width": w, "Height": h],
    ]
}

@Suite struct WindowFilterTests {
    @Test func keepsStatusItemWindows() {
        let infos = menuBarItemInfos(from: [rawWindow()], excludingPIDs: [])
        #expect(infos.count == 1)
        #expect(infos[0].windowID == 1)
        #expect(infos[0].ownerName == "SomeApp")
        #expect(infos[0].frame == CGRect(x: 100, y: 0, width: 30, height: 24))
    }

    @Test func rejectsWrongLayer() {
        let infos = menuBarItemInfos(from: [rawWindow(layer: 0)], excludingPIDs: [])
        #expect(infos.isEmpty)
    }

    @Test func rejectsOwnPID() {
        let infos = menuBarItemInfos(from: [rawWindow(pid: 42)], excludingPIDs: [42])
        #expect(infos.isEmpty)
    }

    @Test func rejectsNonMenuBarGeometry() {
        #expect(menuBarItemInfos(from: [rawWindow(y: 200)], excludingPIDs: []).isEmpty)
        #expect(menuBarItemInfos(from: [rawWindow(w: 2000)], excludingPIDs: []).isEmpty)
        #expect(menuBarItemInfos(from: [rawWindow(h: 100)], excludingPIDs: []).isEmpty)
    }
}
