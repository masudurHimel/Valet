import ApplicationServices
import CoreGraphics

/// Passive checks only — Valet never requests a permission, so nothing here
/// may trigger a TCC prompt.
enum PermissionsService {
    static func hasScreenRecording() -> Bool {
        CGPreflightScreenCaptureAccess()
    }

    static func hasAccessibility() -> Bool {
        AXIsProcessTrusted()
    }
}
