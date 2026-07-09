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
