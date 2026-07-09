import AppKit
import Carbon.HIToolbox

func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
    var result: UInt32 = 0
    if flags.contains(.command) { result |= UInt32(cmdKey) }
    if flags.contains(.shift) { result |= UInt32(shiftKey) }
    if flags.contains(.option) { result |= UInt32(optionKey) }
    if flags.contains(.control) { result |= UInt32(controlKey) }
    return result
}

func hotkeyDisplayString(_ hotkey: Hotkey) -> String {
    var parts = ""
    if hotkey.carbonModifiers & UInt32(controlKey) != 0 { parts += "⌃" }
    if hotkey.carbonModifiers & UInt32(optionKey) != 0 { parts += "⌥" }
    if hotkey.carbonModifiers & UInt32(shiftKey) != 0 { parts += "⇧" }
    if hotkey.carbonModifiers & UInt32(cmdKey) != 0 { parts += "⌘" }
    return parts + keyName(for: hotkey.keyCode)
}

private func keyName(for keyCode: UInt32) -> String {
    let names: [UInt32: String] = [
        0: "A", 1: "S", 2: "D", 3: "F", 4: "H", 5: "G", 6: "Z", 7: "X", 8: "C",
        9: "V", 11: "B", 12: "Q", 13: "W", 14: "E", 15: "R", 16: "Y", 17: "T",
        31: "O", 32: "U", 34: "I", 35: "P", 37: "L", 38: "J", 40: "K", 45: "N",
        46: "M", 18: "1", 19: "2", 20: "3", 21: "4", 22: "5", 23: "6", 26: "7",
        28: "8", 25: "9", 29: "0", 49: "Space", 36: "Return", 48: "Tab",
        53: "Esc", 42: "\\", 24: "=", 27: "-",
    ]
    return names[keyCode] ?? "Key\(keyCode)"
}
