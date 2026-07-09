import ScreenCaptureKit

final class ItemImageCapturer {
    /// Captures a single menu bar item's window image. In-memory only —
    /// never persist the result. Returns nil if permission is missing or
    /// the window has vanished.
    func capture(windowID: UInt32) async -> CGImage? {
        guard PermissionsService.hasScreenRecording() else { return nil }
        guard let content = try? await SCShareableContent.excludingDesktopWindows(
                false, onScreenWindowsOnly: true
              ),
              let window = content.windows.first(where: { $0.windowID == windowID })
        else { return nil }

        let filter = SCContentFilter(desktopIndependentWindow: window)
        let config = SCStreamConfiguration()
        config.width = max(1, Int(window.frame.width) * 2)
        config.height = max(1, Int(window.frame.height) * 2)
        config.showsCursor = false
        return try? await SCScreenshotManager.captureImage(
            contentFilter: filter, configuration: config
        )
    }
}
