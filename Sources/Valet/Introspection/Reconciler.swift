import Foundation

func keyedItems(_ items: [MenuBarItemInfo]) -> [MenuBarItemInfo] {
    let sorted = items.sorted { $0.frame.minX < $1.frame.minX }
    var perOwnerCount: [String: Int] = [:]
    return sorted.map { item in
        var keyed = item
        let index = perOwnerCount[item.ownerIdentity, default: 0]
        keyed.key = "\(item.ownerIdentity)#\(index)"
        perOwnerCount[item.ownerIdentity] = index + 1
        return keyed
    }
}

func reconcile(
    assignments: [String: BarSection],
    items: [MenuBarItemInfo]
) -> [(item: MenuBarItemInfo, section: BarSection)] {
    keyedItems(items).map { ($0, assignments[$0.key] ?? .shown) }
}
