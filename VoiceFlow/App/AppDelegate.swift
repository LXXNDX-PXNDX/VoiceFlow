import AppKit
import SwiftUI
import Combine

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {

    private let state = AppState.shared
    private var statusItem: NSStatusItem!
    private var mainWindow: MainWindowController!
    private var pill: RecordingPillController!
    private var cancellables = Set<AnyCancellable>()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        mainWindow = MainWindowController(state: state)
        pill = RecordingPillController(state: state)

        setupStatusItem()
        state.bootstrap()

        state.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in self?.updateStatusIcon(for: phase) }
            .store(in: &cancellables)

        state.settings.hasCompletedOnboarding = true

        // Opening the app should always show something. The only launch that stays
        // silent in the menu bar is the automatic one at login.
        if !launchedAsLoginItem {
            mainWindow.show()
        }

        NSLog("[App] VoiceFlow ready — \(state.settings.hotkeyMode.label)")
    }

    /// True when launchd started us as a login item rather than the user opening the app.
    private var launchedAsLoginItem: Bool {
        guard let event = NSAppleEventManager.shared().currentAppleEvent,
              event.eventID == kAEOpenApplication else { return false }
        return event.paramDescriptor(forKeyword: keyAEPropData)?.enumCodeValue == keyAELaunchedAsLogInItem
    }

    /// Clicking the app in Finder, Launchpad or the Dock while it already runs.
    /// Without this the app looks dead: it has no Dock icon to bounce and no window.
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        mainWindow.show()
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        state.shutdown()
        pill.tearDown()
    }

    // MARK: - Status item

    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.image = symbol("waveform")
        statusItem.button?.image?.isTemplate = true

        let menu = NSMenu()
        menu.delegate = self

        let openItem = NSMenuItem(title: "VoiceFlow öffnen",
                                  action: #selector(openMainWindow),
                                  keyEquivalent: "o")
        openItem.target = self
        menu.addItem(openItem)

        let toggleItem = NSMenuItem(title: "Aufnahme starten",
                                    action: #selector(toggleRecording),
                                    keyEquivalent: "r")
        toggleItem.target = self
        toggleItem.tag = Tag.toggle
        menu.addItem(toggleItem)

        menu.addItem(.separator())

        let hintItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        hintItem.tag = Tag.hint
        hintItem.isEnabled = false
        menu.addItem(hintItem)

        let statsItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statsItem.tag = Tag.stats
        statsItem.isEnabled = false
        menu.addItem(statsItem)

        let statusRow = NSMenuItem(title: "", action: nil, keyEquivalent: "")
        statusRow.tag = Tag.status
        statusRow.isEnabled = false
        menu.addItem(statusRow)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "VoiceFlow beenden",
                                  action: #selector(quit),
                                  keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        refreshMenu(menu)
    }

    private enum Tag {
        static let toggle = 10
        static let hint = 20
        static let stats = 30
        static let status = 40
    }

    private func symbol(_ name: String) -> NSImage? {
        NSImage(systemSymbolName: name, accessibilityDescription: "VoiceFlow")
    }

    private func updateStatusIcon(for phase: AppState.Phase) {
        let name: String
        switch phase {
        case .recording:    name = "waveform.circle.fill"
        case .transcribing: name = "ellipsis.circle"
        case .inserted:     name = "checkmark.circle"
        case .error:        name = "exclamationmark.circle"
        case .idle:         name = "waveform"
        }
        let image = symbol(name) ?? symbol("waveform")
        image?.isTemplate = true
        statusItem?.button?.image = image
    }

    private func refreshMenu(_ menu: NSMenu) {
        state.refreshPermissions()

        menu.item(withTag: Tag.toggle)?.title = state.isRecording ? "Aufnahme stoppen" : "Aufnahme starten"
        menu.item(withTag: Tag.hint)?.title = state.settings.hotkeyMode.label
        menu.item(withTag: Tag.stats)?.title =
            "Heute: \(state.stats.todayWords) Wörter · \(state.stats.todaySessions) Aufnahmen"
        menu.item(withTag: Tag.status)?.title = statusLine
    }

    private var statusLine: String {
        if !state.micGranted { return "⚠︎ Mikrofonzugriff fehlt" }
        if !state.accessibilityGranted { return "⚠︎ Bedienungshilfen fehlen" }
        switch state.modelState {
        case .ready(let model): return "✓ Bereit (\(model.rawValue))"
        case .downloading(let progress): return "↓ Modell lädt … \(Int(progress * 100)) %"
        case .loading: return "… Modell startet"
        case .failed: return "⚠︎ Modell konnte nicht geladen werden"
        case .idle: return "… startet"
        }
    }

    // MARK: - Actions

    @objc private func openMainWindow() {
        mainWindow.show()
    }

    @objc private func toggleRecording() {
        state.toggleRecording()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }
}

extension AppDelegate: NSMenuDelegate {
    func menuWillOpen(_ menu: NSMenu) {
        refreshMenu(menu)
    }
}
