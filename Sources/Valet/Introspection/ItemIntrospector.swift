import AppKit

@MainActor
final class ItemIntrospector: ObservableObject {
    @Published private(set) var items: [MenuBarItemInfo] = []
    private var timer: Timer?

    func refresh() {
        // Deliberately NOT .optionOnScreenOnly: menu bar item windows leave
        // the on-screen set whenever the menu bar isn't displayed (full-screen
        // apps, auto-hidden menu bar) and when Valet pushes them off-screen —
        // with that option the items list emptied itself on the next refresh.
        guard let raw = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return }
        let ownPID = pid_t(ProcessInfo.processInfo.processIdentifier)
        let infos = menuBarItemInfos(from: raw, excludingPIDs: [ownPID]).map { info in
            var copy = info
            copy = MenuBarItemInfo(
                windowID: info.windowID,
                ownerPID: info.ownerPID,
                ownerName: info.ownerName,
                bundleID: NSRunningApplication(processIdentifier: info.ownerPID)?.bundleIdentifier,
                frame: info.frame,
                key: ""
            )
            return copy
        }
        items = keyedItems(infos)
    }

    func startAutoRefresh(interval: TimeInterval) {
        timer?.invalidate()
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refresh() }
        }
    }

    func frame(ofWindowID windowID: UInt32) -> CGRect? {
        guard let raw = CGWindowListCopyWindowInfo(
            [.excludeDesktopElements], kCGNullWindowID
        ) as? [[String: Any]] else { return nil }
        for dict in raw {
            guard let num = dict["kCGWindowNumber"] as? Int, UInt32(num) == windowID,
                  let bounds = dict["kCGWindowBounds"] as? [String: Any],
                  let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
                  let w = bounds["Width"] as? Double, let h = bounds["Height"] as? Double
            else { continue }
            return CGRect(x: x, y: y, width: w, height: h)
        }
        return nil
    }
}
