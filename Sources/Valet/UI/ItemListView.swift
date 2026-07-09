import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct ItemListView: View {
    @ObservedObject var store: SettingsStore
    @ObservedObject var introspector: ItemIntrospector
    @ObservedObject var assigner: SectionAssigner
    @State private var images: [String: CGImage] = [:]
    private let capturer = ItemImageCapturer()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !PermissionsService.hasScreenRecording() {
                Label(
                    "Showing app icons. Grant Screen Recording in the Permissions tab to see each item's exact menu bar glyph — images stay on this Mac.",
                    systemImage: "eye.slash"
                )
                .font(.caption)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.yellow.opacity(0.15), in: RoundedRectangle(cornerRadius: 6))
            }
            if let error = assigner.lastError {
                Text(error)
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            HStack(alignment: .top, spacing: 12) {
                ForEach([BarSection.shown, .hidden, .alwaysHidden], id: \.self) { section in
                    sectionColumn(section)
                }
            }
            Text("Drag items between sections, or right-click an item to move it.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(16)
        .task { await refreshImages() }
        .onReceive(introspector.$items) { _ in
            Task { await refreshImages() }
        }
    }

    private func sectionColumn(_ section: BarSection) -> some View {
        let rows = reconcile(assignments: store.assignments, items: introspector.items)
            .filter { $0.section == section }
        return VStack(alignment: .leading, spacing: 4) {
            Text(section.displayName).font(.headline)
            List(rows, id: \.item.key) { row in
                itemRow(row.item)
            }
            .frame(minHeight: 220)
        }
        .frame(maxWidth: .infinity)
        .onDrop(of: [UTType.plainText], isTargeted: nil) { providers in
            guard let provider = providers.first else { return false }
            _ = provider.loadObject(ofClass: NSString.self) { object, _ in
                guard let key = object as? String else { return }
                Task { @MainActor in
                    await assigner.move(key: key, to: section)
                }
            }
            return true
        }
    }

    private func itemRow(_ item: MenuBarItemInfo) -> some View {
        HStack(spacing: 6) {
            if let cg = images[item.key] {
                Image(cg, scale: 2, label: Text(item.ownerName))
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
            } else if let appIcon = NSRunningApplication(processIdentifier: item.ownerPID)?.icon {
                // No Screen Recording permission (or capture unavailable):
                // fall back to the owning app's icon — needs no permission.
                Image(nsImage: appIcon)
                    .resizable()
                    .scaledToFit()
                    .frame(height: 18)
            } else {
                Image(systemName: "app.dashed").frame(height: 18)
            }
            Text(item.ownerName).lineLimit(1)
        }
        .onDrag { NSItemProvider(object: item.key as NSString) }
        .contextMenu {
            ForEach(BarSection.allCases, id: \.self) { target in
                Button("Move to \(target.displayName)") {
                    Task { await assigner.move(key: item.key, to: target) }
                }
            }
        }
    }

    @MainActor
    private func refreshImages() async {
        for item in introspector.items {
            if let image = await capturer.capture(windowID: item.windowID) {
                images[item.key] = image
            }
        }
    }
}
