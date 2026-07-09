import Foundation

struct MenuBarItemInfo: Equatable, Identifiable {
    let windowID: UInt32
    let ownerPID: pid_t
    let ownerName: String
    let bundleID: String?
    let frame: CGRect
    var key: String

    var id: String { key.isEmpty ? String(windowID) : key }
    var ownerIdentity: String { bundleID ?? ownerName }
}
