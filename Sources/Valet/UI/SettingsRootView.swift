import SwiftUI

struct SettingsRootView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var introspector: ItemIntrospector
    @ObservedObject var assigner: SectionAssigner
    @Binding var selectedTab: SettingsTab

    var body: some View {
        TabView(selection: $selectedTab) {
            ItemListView(store: store, introspector: introspector, assigner: assigner)
                .tabItem { Label("Items", systemImage: "menubar.rectangle") }
                .tag(SettingsTab.items)
            BehaviorView(store: store)
                .tabItem { Label("Behavior", systemImage: "gearshape") }
                .tag(SettingsTab.behavior)
            HotkeyRecorderView(store: store)
                .tabItem { Label("Hotkeys", systemImage: "keyboard") }
                .tag(SettingsTab.hotkeys)
            PermissionsView()
                .tabItem { Label("Permissions", systemImage: "lock.shield") }
                .tag(SettingsTab.permissions)
            AboutView()
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(minWidth: 560, minHeight: 420)
    }
}
