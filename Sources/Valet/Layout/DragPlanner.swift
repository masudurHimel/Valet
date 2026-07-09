import Foundation

struct SeparatorFrames: Equatable {
    var hidden: CGRect
    var alwaysHidden: CGRect
}

struct DragPlan: Equatable {
    var from: CGPoint
    var to: CGPoint
}

func dragPlan(item: MenuBarItemInfo, target: BarSection, separators: SeparatorFrames) -> DragPlan? {
    let gap: CGFloat = 12
    let halfWidth = item.frame.width / 2
    let y = item.frame.midY
    let from = CGPoint(x: item.frame.midX, y: y)

    let alreadyThere: Bool
    let targetX: CGFloat
    switch target {
    case .shown:
        alreadyThere = item.frame.minX >= separators.hidden.maxX
        targetX = separators.hidden.maxX + gap + halfWidth
    case .hidden:
        alreadyThere = item.frame.maxX <= separators.hidden.minX
            && item.frame.minX >= separators.alwaysHidden.maxX
        targetX = separators.hidden.minX - gap - halfWidth
    case .alwaysHidden:
        alreadyThere = item.frame.maxX <= separators.alwaysHidden.minX
        targetX = separators.alwaysHidden.minX - gap - halfWidth
    }
    if alreadyThere { return nil }
    return DragPlan(from: from, to: CGPoint(x: targetX, y: y))
}
