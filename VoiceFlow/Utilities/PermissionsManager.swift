import AppKit
import AVFoundation
import ApplicationServices

final class PermissionsManager {

    func hasMicrophoneAccess() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    func hasAccessibilityAccess() -> Bool {
        AXIsProcessTrusted()
    }

    /// Shows the system microphone prompt when the user has not decided yet.
    func requestMicrophoneAccess(completion: @escaping (Bool) -> Void) {
        switch AVCaptureDevice.authorizationStatus(for: .audio) {
        case .authorized:
            completion(true)
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .audio) { granted in
                NSLog("[Permissions] Microphone granted: \(granted)")
                DispatchQueue.main.async { completion(granted) }
            }
        case .denied, .restricted:
            NSLog("[Permissions] Microphone denied — opening System Settings")
            openSystemSettings(pane: "Privacy_Microphone")
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    /// Shows the system Accessibility prompt, or sends the user to the right settings pane.
    func promptForAccessibility() {
        guard !AXIsProcessTrusted() else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue(): true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
        openSystemSettings(pane: "Privacy_Accessibility")
    }

    func openSystemSettings(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
