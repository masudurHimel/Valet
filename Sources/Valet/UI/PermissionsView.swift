import SwiftUI

struct PermissionsView: View {
    @State private var screenRecording = PermissionsService.hasScreenRecording()
    @State private var accessibility = PermissionsService.hasAccessibility()
    private let timer = Timer.publish(every: 2, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            permissionRow(
                granted: screenRecording,
                title: "Screen Recording",
                purpose: "Lets Valet show the icons and names of your menu bar items.",
                privacy: "Captures only menu bar item images, kept in memory, never saved or sent anywhere.",
                request: PermissionsService.requestScreenRecording,
                openSettings: PermissionsService.openScreenRecordingSettings
            )
            permissionRow(
                granted: accessibility,
                title: "Accessibility",
                purpose: "Lets Valet move icons between sections for you (simulated Cmd-drag).",
                privacy: "Used only to perform the drag you request. Without it, you can Cmd-drag icons manually.",
                request: PermissionsService.requestAccessibility,
                openSettings: PermissionsService.openAccessibilitySettings
            )
            Text("Valet works without these permissions, with reduced convenience. Nothing ever leaves this Mac.")
                .font(.caption)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(20)
        .onReceive(timer) { _ in
            screenRecording = PermissionsService.hasScreenRecording()
            accessibility = PermissionsService.hasAccessibility()
        }
    }

    private func permissionRow(
        granted: Bool, title: String, purpose: String, privacy: String,
        request: @escaping () -> Void, openSettings: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Image(systemName: granted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(granted ? .green : .secondary)
                Text(title).font(.headline)
                Spacer()
                if !granted {
                    Button("Request", action: request)
                    Button("Open System Settings", action: openSettings)
                }
            }
            Text(purpose).font(.callout)
            Text(privacy).font(.caption).foregroundStyle(.secondary)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 8))
    }
}
