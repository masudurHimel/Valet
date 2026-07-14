import Foundation

struct MenuBarItemInfo: Equatable {
    let windowID: UInt32
    let ownerPID: pid_t
    let ownerName: String
    let bundleID: String?
    let frame: CGRect
    var key: String

    var ownerIdentity: String { bundleID ?? ownerName }
}
