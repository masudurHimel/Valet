import AppKit
import SwiftUI

struct AboutView: View {
    @State private var checking = false
    @State private var result: String?
    private let checker = UpdateChecker()

    var body: some View {
        VStack(spacing: 10) {
            // NSApp.applicationIconImage resolves CFBundleIconFile when run
            // from the bundle, and a generic icon under `swift run`.
            Image(nsImage: NSApp.applicationIconImage)
                .resizable()
                .scaledToFit()
                .frame(width: 64, height: 64)
            Text("Valet").font(.title.bold())
            Text("Version \(UpdateChecker.currentVersion)")
                .foregroundStyle(.secondary)
            Text("Open-source menu bar manager. MIT licensed.\nEverything stays on this Mac — the only network request Valet can make is the button below.")
                .multilineTextAlignment(.center)
                .font(.callout)
            Link("Source code on GitHub",
                 destination: URL(string: "https://github.com/\(UpdateChecker.repoSlug)")!)
            Button(checking ? "Checking…" : "Check for Updates") {
                checking = true
                result = nil
                Task {
                    switch await checker.check() {
                    case .upToDate: result = "You're up to date."
                    case .updateAvailable(let tag): result = "Version \(tag) is available on GitHub."
                    case .failed: result = "Couldn't check. Are you online? (Valet never checks by itself.)"
                    }
                    checking = false
                }
            }
            .disabled(checking)
            if let result { Text(result).font(.caption) }
            Spacer()
        }
        .padding(24)
    }
}
