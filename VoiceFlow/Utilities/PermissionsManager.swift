import AppKit
import AVFoundation
import ApplicationServices

final class PermissionsManager {

    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.voiceflow.app"

    func hasMicrophoneAccess() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// AXIsProcessTrusted is the official check, but on recent macOS versions it can
    /// briefly return a stale value after the user comes back from System Settings.
    /// A harmless system-wide AX query provides a second, functional verification.
    func hasAccessibilityAccess() -> Bool {
        if AXIsProcessTrusted() || trustedWithoutPrompt() {
            return true
        }

        let systemWide = AXUIElementCreateSystemWide()
        var focusedElement: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(
            systemWide,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        switch result {
        case .success, .noValue, .attributeUnsupported, .cannotComplete:
            return true
        case .apiDisabled:
            return false
        default:
            return false
        }
    }

    private func trustedWithoutPrompt() -> Bool {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): false] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
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
            openMicrophoneSettings()
            completion(false)
        @unknown default:
            completion(false)
        }
    }

    /// Shows the Accessibility prompt and opens the matching privacy pane.
    func promptForAccessibility() {
        if hasAccessibilityAccess() { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue(): true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        openAccessibilitySettings()
    }

    /// Community releases are ad-hoc signed. Replacing the app can leave a visible but
    /// stale TCC entry tied to the previous binary hash. This user-triggered repair removes
    /// only VoiceFlow's Accessibility record so macOS can register the current app again.
    @discardableResult
    func repairAccessibilityAccess() -> Bool {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        process.arguments = ["reset", "Accessibility", bundleIdentifier]

        do {
            try process.run()
            process.waitUntilExit()
            let succeeded = process.terminationStatus == 0
            NSLog("[Permissions] Accessibility reset finished: \(succeeded)")
            if succeeded {
                promptForAccessibility()
            }
            return succeeded
        } catch {
            NSLog("[Permissions] Accessibility reset failed: \(error.localizedDescription)")
            openAccessibilitySettings()
            return false
        }
    }

    func openMicrophoneSettings() {
        openSystemSettings(pane: "Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openSystemSettings(pane: "Privacy_Accessibility")
    }

    private func openSystemSettings(pane: String) {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(pane)") else { return }
        NSWorkspace.shared.open(url)
    }
}
