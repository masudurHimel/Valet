import AppKit
import Testing
@testable import Valet

@Suite struct ModifierConversionTests {
    @Test func convertsEachModifier() {
        #expect(carbonModifiers(from: [.command]) == 256)       // cmdKey
        #expect(carbonModifiers(from: [.shift]) == 512)         // shiftKey
        #expect(carbonModifiers(from: [.option]) == 2048)       // optionKey
        #expect(carbonModifiers(from: [.control]) == 4096)      // controlKey
        #expect(carbonModifiers(from: [.command, .option]) == 2304)
    }

    @Test func displayStringShowsModifiersAndKey() {
        // keyCode 11 is "B" on ANSI layouts
        let s = hotkeyDisplayString(Hotkey(keyCode: 11, carbonModifiers: 256 | 2048))
        #expect(s.contains("⌘"))
        #expect(s.contains("⌥"))
        #expect(!s.isEmpty)
    }
}
