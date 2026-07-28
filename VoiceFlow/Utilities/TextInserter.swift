import AppKit
import Carbon

/// Puts the transcript where the user was typing.
final class TextInserter {

    /// The app that had focus when recording started. Restoring it before pasting
    /// keeps the text going to the right place even if VoiceFlow's own window was clicked.
    private var targetApp: NSRunningApplication?

    func rememberFrontmostApp() {
        let frontmost = NSWorkspace.shared.frontmostApplication
        if frontmost?.bundleIdentifier != Bundle.main.bundleIdentifier {
            targetApp = frontmost
        }
    }

    func copyToClipboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    /// Pastes `text` into the frontmost app. Returns false when Accessibility access is missing,
    /// in which case the text is still on the clipboard.
    @discardableResult
    func insertText(_ text: String) -> Bool {
        let pasteboard = NSPasteboard.general
        let previousContents = pasteboard.string(forType: .string)

        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)

        guard AXIsProcessTrusted() else {
            NSLog("[Insert] No accessibility access — transcript left on clipboard")
            return false
        }

        restoreTargetApp { [weak self] in
            self?.postPasteShortcut()

            // Give the receiving app time to read the pasteboard before putting the
            // user's own clipboard content back.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                pasteboard.clearContents()
                if let previousContents = previousContents {
                    pasteboard.setString(previousContents, forType: .string)
                }
            }
        }

        return true
    }

    private func restoreTargetApp(_ completion: @escaping () -> Void) {
        guard let target = targetApp,
              !target.isTerminated,
              NSWorkspace.shared.frontmostApplication?.bundleIdentifier != target.bundleIdentifier else {
            completion()
            return
        }

        target.activate()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15, execute: completion)
    }

    private func postPasteShortcut() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else {
            NSLog("[Insert] Could not create event source")
            return
        }

        // Suppress our own synthetic events from being seen as local keyboard input.
        source.setLocalEventsFilterDuringSuppressionState(
            [.permitLocalMouseEvents, .permitSystemDefinedEvents],
            state: .eventSuppressionStateSuppressionInterval
        )

        let keyV = CGKeyCode(kVK_ANSI_V)
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: true)
        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: keyV, keyDown: false)

        // Set the flags explicitly so a modifier the user is still holding (Fn, ⌥ …)
        // does not turn ⌘V into a different shortcut.
        keyDown?.flags = .maskCommand
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
