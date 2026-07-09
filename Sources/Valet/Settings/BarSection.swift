enum BarSection: String, Codable, CaseIterable, Equatable {
    case shown
    case hidden
    case alwaysHidden

    var displayName: String {
        switch self {
        case .shown: return "Shown"
        case .hidden: return "Hidden"
        case .alwaysHidden: return "Always Hidden"
        }
    }
}
