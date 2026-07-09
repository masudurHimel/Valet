import Foundation

final class SettingsStore: ObservableObject {
    private enum Keys {
        static let assignments = "assignments"
        static let autoRehide = "autoRehide"
        static let rehideDelay = "rehideDelay"
        static let toggleHotkey = "toggleHotkey"
    }

    private let defaults: UserDefaults

    @Published var assignments: [String: BarSection] {
        didSet { saveJSON(assignments, key: Keys.assignments) }
    }
    @Published var autoRehide: Bool {
        didSet { defaults.set(autoRehide, forKey: Keys.autoRehide) }
    }
    @Published var rehideDelay: TimeInterval {
        didSet { defaults.set(rehideDelay, forKey: Keys.rehideDelay) }
    }
    @Published var toggleHotkey: Hotkey? {
        didSet { saveJSON(toggleHotkey, key: Keys.toggleHotkey) }
    }

    init(defaults: UserDefaults) {
        self.defaults = defaults
        self.assignments = Self.loadJSON([String: BarSection].self, key: Keys.assignments, defaults: defaults) ?? [:]
        self.autoRehide = defaults.object(forKey: Keys.autoRehide) as? Bool ?? true
        self.rehideDelay = defaults.object(forKey: Keys.rehideDelay) as? TimeInterval ?? 15
        self.toggleHotkey = Self.loadJSON(Hotkey.self, key: Keys.toggleHotkey, defaults: defaults)
    }

    private func saveJSON<T: Encodable>(_ value: T?, key: String) {
        guard let value, let data = try? JSONEncoder().encode(value) else {
            defaults.removeObject(forKey: key)
            return
        }
        defaults.set(data, forKey: key)
    }

    private static func loadJSON<T: Decodable>(_ type: T.Type, key: String, defaults: UserDefaults) -> T? {
        guard let data = defaults.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(type, from: data)
    }
}
