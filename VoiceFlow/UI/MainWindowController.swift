import AppKit
import SwiftUI

/// Owns the main window.
///
/// Sizing is driven entirely from AppKit: the hosting controller's `sizingOptions`
/// are cleared so SwiftUI never pushes an intrinsic size back into the window, and
/// the window's own `minSize` replaces the `.frame(minWidth:minHeight:)` the SwiftUI
/// root used to carry. Those two pulling against each other is what produced the
/// runaway constraint invalidation that crashed the previous build.
@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {

    private var window: NSWindow?
    private let state: AppState

    init(state: AppState) {
        self.state = state
        super.init()
    }

    func show() {
        // An .accessory app cannot reliably pull a window to the front. Switching to
        // .regular for as long as the window is open gives it real focus and a Dock
        // entry; `windowWillClose` puts us back into the menu bar.
        NSApp.setActivationPolicy(.regular)

        if let window = window {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let hostingController = NSHostingController(rootView: RootView(state: state))
        hostingController.sizingOptions = []

        let window = NSWindow(contentViewController: hostingController)
        window.title = "VoiceFlow"
        window.styleMask = [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView]
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.setContentSize(NSSize(width: 760, height: 620))
        window.minSize = NSSize(width: 680, height: 520)
        window.center()

        self.window = window

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func windowWillClose(_ notification: Notification) {
        // Keep the instance around; reopening should be instant and must not
        // rebuild a hosting controller that AppKit still references.
        NSApp.setActivationPolicy(.accessory)
    }

    func tearDown() {
        window?.delegate = nil
        window?.close()
        window = nil
    }
}
