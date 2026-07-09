import ServiceManagement
import SwiftUI

struct BehaviorView: View {
    @ObservedObject var store: SettingsStore
    @State private var launchAtLogin = SMAppService.mainApp.status == .enabled
    @State private var loginItemError: String?
    @State private var suppressLoginItemChange = false

    var body: some View {
        Form {
            Toggle("Automatically re-hide items", isOn: $store.autoRehide)
            Stepper(
                "Re-hide after \(Int(store.rehideDelay)) seconds",
                value: $store.rehideDelay, in: 2...120, step: 1
            )
            .disabled(!store.autoRehide)

            Divider()

            Toggle("Launch Valet at login", isOn: $launchAtLogin)
                .onChange(of: launchAtLogin) { _, enable in
                    if suppressLoginItemChange {
                        suppressLoginItemChange = false
                        return
                    }
                    do {
                        if enable {
                            try SMAppService.mainApp.register()
                        } else {
                            try SMAppService.mainApp.unregister()
                        }
                        loginItemError = nil
                    } catch {
                        loginItemError = "Couldn't update login item: \(error.localizedDescription). "
                            + "Run Valet from /Applications (built via Scripts/make-app.sh) and try again."
                        let actual = SMAppService.mainApp.status == .enabled
                        if actual != launchAtLogin {
                            suppressLoginItemChange = true
                            launchAtLogin = actual
                        }
                    }
                }
            if let loginItemError {
                Text(loginItemError).font(.caption).foregroundStyle(.red)
            }
        }
        .padding(20)
    }
}
