import AppKit
import SwiftUI

struct HotkeyRecorderView: View {
    @ObservedObject var store: SettingsStore
    @State private var isRecording = false
    @State private var monitor: Any?

    var body: some View {
        Form {
            HStack {
                Text("Toggle hidden items:")
                Text(store.toggleHotkey.map(hotkeyDisplayString) ?? "None")
                    .fontWeight(.semibold)
                    .frame(minWidth: 80)
                Button(isRecording ? "Press keys…" : "Record") { startRecording() }
                    .disabled(isRecording)
                Button("Clear") { store.toggleHotkey = nil }
                    .disabled(store.toggleHotkey == nil)
            }
            Text("The shortcut must include at least one of ⌘ ⌥ ⌃ ⇧.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(20)
        .onDisappear { stopRecording() }
    }

    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            let mods = carbonModifiers(from: event.modifierFlags)
            if event.keyCode == 53 && mods == 0 {  // Esc cancels
                stopRecording()
                return nil
            }
            guard mods != 0 else { return nil }  // require a modifier
            store.toggleHotkey = Hotkey(keyCode: UInt32(event.keyCode), carbonModifiers: mods)
            stopRecording()
            return nil
        }
    }

    private func stopRecording() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
        isRecording = false
    }
}
