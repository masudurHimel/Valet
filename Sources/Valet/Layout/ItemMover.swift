import CoreGraphics
import Foundation

final class ItemMover {
    /// Synthesizes a Cmd-drag from plan.from to plan.to in global display
    /// coordinates. Requires Accessibility permission.
    func perform(_ plan: DragPlan) async {
        guard let source = CGEventSource(stateID: .hidSystemState) else { return }

        func post(_ type: CGEventType, at point: CGPoint) {
            let event = CGEvent(
                mouseEventSource: source, mouseType: type,
                mouseCursorPosition: point, mouseButton: .left
            )
            event?.flags = .maskCommand
            event?.post(tap: .cghidEventTap)
        }

        post(.leftMouseDown, at: plan.from)
        try? await Task.sleep(for: .milliseconds(60))
        let steps = 12
        for i in 1...steps {
            let t = CGFloat(i) / CGFloat(steps)
            let x = plan.from.x + (plan.to.x - plan.from.x) * t
            post(.leftMouseDragged, at: CGPoint(x: x, y: plan.to.y))
            try? await Task.sleep(for: .milliseconds(20))
        }
        post(.leftMouseUp, at: plan.to)
        try? await Task.sleep(for: .milliseconds(60))
    }
}
