import Foundation

enum RevealState: String, Equatable {
    case collapsed
    case revealed
    case revealedAll
}

struct SpacerLengths: Equatable {
    var hidden: CGFloat
    var alwaysHidden: CGFloat
}

struct VisibilityEngine: Equatable {
    static let expandedLength: CGFloat = 10_000
    static let separatorLength: CGFloat = 8

    private(set) var state: RevealState = .collapsed

    mutating func toggle() {
        state = (state == .collapsed) ? .revealed : .collapsed
    }

    mutating func toggleAll() {
        state = (state == .revealedAll) ? .collapsed : .revealedAll
    }

    mutating func collapse() {
        state = .collapsed
    }

    var spacerLengths: SpacerLengths {
        switch state {
        case .collapsed:
            return SpacerLengths(hidden: Self.expandedLength, alwaysHidden: Self.expandedLength)
        case .revealed:
            return SpacerLengths(hidden: Self.separatorLength, alwaysHidden: Self.expandedLength)
        case .revealedAll:
            return SpacerLengths(hidden: Self.separatorLength, alwaysHidden: Self.separatorLength)
        }
    }

    func rehideDeadline(now: Date, delay: TimeInterval, autoRehide: Bool) -> Date? {
        guard autoRehide, state != .collapsed else { return nil }
        return now.addingTimeInterval(delay)
    }
}

/// The "NSStatusItem Preferred Position" value to save for a separator whose
/// button window has this frame, or nil to keep the last saved value. The
/// fence is the separator's RIGHT edge (maxX), which stays meaningful at any
/// length, so derive the 8 pt-wide position from it. Skips:
/// - the pre-layout placeholder: at creation the window parks at the screen
///   origin (observed [0..24]) before the status bar lays it out — capturing
///   then would clobber both keys with garbage every launch. Inflated spacers
///   are still captured: they're pushed left but thousands of points wide.
/// - positions outside the screen (separator pushed off by a neighbor).
func separatorCapturePosition(windowFrame: CGRect, screenFrame: CGRect) -> CGFloat? {
    guard windowFrame.minX > 0 || windowFrame.width > 100 else { return nil }
    let position = screenFrame.maxX - windowFrame.maxX + VisibilityEngine.separatorLength
    guard position > 0, position < screenFrame.width else { return nil }
    return position
}

/// Whether a "NSStatusItem Preferred Position" value restored at launch is
/// usable. macOS records this key itself whenever the user drags a status item,
/// and a stray drag can persist a value that parks the separator off-screen
/// (observed: 5524 on a 1512-pt screen) — where it hides nothing, so the launch
/// swallow-check reads it as healthy and keeps it, stranding the layout every
/// launch. Reject anything outside the on-screen range, mirroring the bounds
/// `separatorCapturePosition` already enforces on write, so what we refuse to
/// restore is exactly what we would never have written.
func isValidRestoredPosition(_ value: CGFloat, screenWidth: CGFloat) -> Bool {
    value > 0 && value < screenWidth
}
