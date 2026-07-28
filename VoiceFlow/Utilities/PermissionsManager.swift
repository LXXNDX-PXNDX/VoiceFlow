import AppKit
import AVFoundation
import ApplicationServices

final class PermissionsManager {

    private let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.voiceflow.app"

    func hasMicrophoneAccess() -> Bool {
        AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
    }

    /// Uses only Apple's official TCC-backed trust check.
    ///
    /// Do not infer permission from individual AX API return codes: calls such as
    /// `AXUIElementCopyAttributeValue` can return `noValue`, `attributeUnsupported` or
    /// `cannotComplete` even when Accessibility access is disabled. Treating those results
    /// as success caused VoiceFlow 1.1.1 to display a false green permission state.
    func hasAccessibilityAccess() -> Bool {
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

    /// Requests Accessibility access and always opens the exact System Settings page.
    /// The status remains false until macOS itself confirms the current VoiceFlow binary.
    func promptForAccessibility() {
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
        openPrivacyPane("Privacy_Microphone")
    }

    func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    private func openPrivacyPane(_ pane: String) {
        // The first URL works across current macOS versions. The second is a fallback for
        // newer System Settings routing. Opening the app itself is the final safe fallback.
        let routes = [
            "x-apple.systempreferences:com.apple.preference.security?\(pane)",
            "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?\(pane)"
        ]

        for route in routes {
            guard let url = URL(string: route) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }

        let settingsApp = URL(fileURLWithPath: "/System/Applications/System Settings.app")
        NSWorkspace.shared.open(settingsApp)
    }
}
