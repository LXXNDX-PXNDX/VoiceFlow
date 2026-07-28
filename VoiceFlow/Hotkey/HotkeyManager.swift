import Cocoa

/// Watches the global key stream for the configured trigger.
///
/// Modifier keys are identified by key code rather than by `NSEvent.modifierFlags`,
/// because the `.function` flag is also set for arrow keys, F-keys and the numeric
/// pad — matching on the flag alone fires the recorder on ordinary typing.
final class HotkeyManager {

    var onStartRecording: (() -> Void)?
    var onStopRecording: (() -> Void)?
    /// Called when a hold is abandoned because the key was used as a modifier.
    var onCancelRecording: (() -> Void)?

    var mode: HotkeyMode = .fnHold {
        didSet {
            guard mode != oldValue else { return }
            reset()
        }
    }

    private enum KeyCode {
        static let fn: UInt16 = 63
        static let rightCommand: UInt16 = 54
        static let rightOption: UInt16 = 61
    }

    private var globalMonitor: Any?
    private var localMonitor: Any?

    private var triggerIsDown = false
    private var holdActive = false
    private var holdCancelled = false
    private var toggleActive = false
    private var lastTapTime: TimeInterval = 0
    private var holdTimer: Timer?

    private let doubleTapInterval: TimeInterval = 0.35
    private let holdThreshold: TimeInterval = 0.22

    func start() {
        stop()

        let mask: NSEvent.EventTypeMask = [.flagsChanged, .keyDown]
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: mask) { [weak self] event in
            self?.handle(event)
            return event
        }
        NSLog("[Hotkey] Monitoring started (mode: \(mode.rawValue))")
    }

    func stop() {
        if let monitor = globalMonitor { NSEvent.removeMonitor(monitor); globalMonitor = nil }
        if let monitor = localMonitor { NSEvent.removeMonitor(monitor); localMonitor = nil }
        holdTimer?.invalidate()
        holdTimer = nil
    }

    /// Forgets any in-flight hold/toggle state, e.g. after the mode changed.
    func reset() {
        holdTimer?.invalidate()
        holdTimer = nil
        triggerIsDown = false
        holdActive = false
        holdCancelled = false
        toggleActive = false
        lastTapTime = 0
    }

    /// Keeps the toggle in sync when recording was started or stopped elsewhere (menu, UI button).
    func syncToggleState(isRecording: Bool) {
        toggleActive = isRecording
    }

    private var triggerKeyCode: UInt16 {
        switch mode {
        case .fnHold, .fnDoubleTap: return KeyCode.fn
        case .rightCommandHold:     return KeyCode.rightCommand
        case .rightOptionHold:      return KeyCode.rightOption
        }
    }

    private var triggerFlag: NSEvent.ModifierFlags {
        switch mode {
        case .fnHold, .fnDoubleTap: return .function
        case .rightCommandHold:     return .command
        case .rightOptionHold:      return .option
        }
    }

    private func handle(_ event: NSEvent) {
        switch event.type {
        case .flagsChanged:
            handleFlagsChanged(event)
        case .keyDown:
            // A regular key pressed while the trigger is held means the user is typing
            // a shortcut (Fn+←, ⌘+C …), not dictating.
            if triggerIsDown { abandonHold() }
        default:
            break
        }
    }

    private func handleFlagsChanged(_ event: NSEvent) {
        guard event.keyCode == triggerKeyCode else { return }

        let isDown = event.modifierFlags.contains(triggerFlag)
        guard isDown != triggerIsDown else { return }
        triggerIsDown = isDown

        if isDown {
            keyWentDown()
        } else {
            keyWentUp()
        }
    }

    private func keyWentDown() {
        holdCancelled = false
        holdTimer?.invalidate()

        guard mode.isHold else { return }

        holdTimer = Timer.scheduledTimer(withTimeInterval: holdThreshold, repeats: false) { [weak self] _ in
            guard let self = self, self.triggerIsDown, !self.holdCancelled else { return }
            self.holdActive = true
            NSLog("[Hotkey] Hold detected → start")
            self.onStartRecording?()
        }
        if let timer = holdTimer {
            RunLoop.main.add(timer, forMode: .common)
        }
    }

    private func keyWentUp() {
        holdTimer?.invalidate()
        holdTimer = nil

        if holdActive {
            holdActive = false
            NSLog("[Hotkey] Hold released → stop")
            onStopRecording?()
            return
        }

        guard !holdCancelled else {
            holdCancelled = false
            return
        }

        // A short press. In toggle mode two of them within the window flip recording.
        guard mode == .fnDoubleTap else { return }

        let now = Date().timeIntervalSinceReferenceDate
        let gap = now - lastTapTime
        if gap < doubleTapInterval, gap > 0.02 {
            lastTapTime = 0
            toggleActive.toggle()
            NSLog("[Hotkey] Double tap → recording = \(toggleActive)")
            if toggleActive {
                onStartRecording?()
            } else {
                onStopRecording?()
            }
        } else {
            lastTapTime = now
        }
    }

    private func abandonHold() {
        holdCancelled = true
        holdTimer?.invalidate()
        holdTimer = nil

        if holdActive {
            holdActive = false
            NSLog("[Hotkey] Trigger used as modifier → cancel")
            onCancelRecording?()
        }
    }

    deinit {
        stop()
    }
}
