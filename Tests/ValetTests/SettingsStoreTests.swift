import Foundation
import Testing
@testable import Valet

private func freshDefaults() -> UserDefaults {
    let suite = "ValetTests-\(UUID().uuidString)"
    let d = UserDefaults(suiteName: suite)!
    d.removePersistentDomain(forName: suite)
    return d
}

@Suite struct SettingsStoreTests {
    @Test func defaultsOnFirstLaunch() {
        let store = SettingsStore(defaults: freshDefaults())
        #expect(store.assignments.isEmpty)
        #expect(store.autoRehide == true)
        #expect(store.rehideDelay == 15)
        #expect(store.toggleHotkey == nil)
    }

    @Test func persistsAndRestores() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        store.assignments = ["com.example.app#0": .hidden]
        store.autoRehide = false
        store.rehideDelay = 30
        store.toggleHotkey = Hotkey(keyCode: 11, carbonModifiers: 256)

        let restored = SettingsStore(defaults: defaults)
        #expect(restored.assignments == ["com.example.app#0": .hidden])
        #expect(restored.autoRehide == false)
        #expect(restored.rehideDelay == 30)
        #expect(restored.toggleHotkey == Hotkey(keyCode: 11, carbonModifiers: 256))
    }

    @Test func persistsKnownKeys() {
        let defaults = freshDefaults()
        let store = SettingsStore(defaults: defaults)
        #expect(store.knownKeys.isEmpty)
        store.knownKeys = ["com.a#0", "com.b#0"]

        let restored = SettingsStore(defaults: defaults)
        #expect(restored.knownKeys == ["com.a#0", "com.b#0"])
    }

    @Test func sectionDisplayNames() {
        #expect(BarSection.shown.displayName == "Shown")
        #expect(BarSection.hidden.displayName == "Hidden")
        #expect(BarSection.alwaysHidden.displayName == "Always Hidden")
    }
}
