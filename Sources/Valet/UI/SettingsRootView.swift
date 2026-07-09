import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var introspector: ItemIntrospector
    @Binding var selectedTab: SettingsTab

    var body: some View {
        TabView(selection: $selectedTab) {
            Text("Items")
                .tabItem { Label("Items", systemImage: "menubar.rectangle") }
                .tag(SettingsTab.items)
            BehaviorView(store: store)
                .tabItem { Label("Behavior", systemImage: "gearshape") }
                .tag(SettingsTab.behavior)
            Text("Hotkeys")
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
                .tag(SettingsTab.hotkeys)
            Text("Permissions")
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
            Text("About")
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
