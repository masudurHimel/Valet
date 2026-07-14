import Foundation

func windowBounds(from dict: [String: Any]) -> CGRect? {
    guard let bounds = dict["kCGWindowBounds"] as? [String: Any],
          let x = bounds["X"] as? Double, let y = bounds["Y"] as? Double,
          let w = bounds["Width"] as? Double, let h = bounds["Height"] as? Double
    else { return nil }
    return CGRect(x: x, y: y, width: w, height: h)
}

func menuBarItemInfos(from raw: [[String: Any]], excludingPIDs: Set<pid_t>) -> [MenuBarItemInfo] {
    raw.compactMap { dict in
        guard
            let layer = dict["kCGWindowLayer"] as? Int, layer == 25,
            let pid = dict["kCGWindowOwnerPID"] as? Int, !excludingPIDs.contains(pid_t(pid)),
            let windowID = dict["kCGWindowNumber"] as? Int,
            let frame = windowBounds(from: dict),
            frame.origin.y == 0, frame.height <= 40, frame.width <= 500
        else { return nil }
        return MenuBarItemInfo(
            windowID: UInt32(windowID),
            ownerPID: pid_t(pid),
            ownerName: dict["kCGWindowOwnerName"] as? String ?? "Unknown",
            bundleID: nil,
            frame: frame,
            key: ""
        )
    }
}
