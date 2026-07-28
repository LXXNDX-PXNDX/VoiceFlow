import AppKit
import SwiftUI
import Combine

/// The floating status pill near the bottom of the screen.
///
/// The panel has a fixed size and its hosting view has size propagation switched off,
/// so SwiftUI can never push a new size back into the window. That feedback loop is
/// what made the previous build throw inside AppKit's display cycle.
@MainActor
final class RecordingPillController {

    private let panelSize = NSSize(width: 420, height: 110)
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private let state: AppState

    init(state: AppState) {
        self.state = state

        state.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in self?.apply(phase: phase) }
            .store(in: &cancellables)
    }

    private func apply(phase: AppState.Phase) {
        guard state.settings.showPill else {
            hide()
            return
        }
        if phase == .idle {
            hide()
        } else {
            show()
        }
    }

    private func show() {
        if let panel = panel {
            reposition(panel)
            panel.orderFrontRegardless()
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: panelSize),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isReleasedWhenClosed = false
        panel.level = .statusBar
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        // The pill is purely informational; it must never take focus away from the
        // app the transcript is going to be pasted into.
        panel.ignoresMouseEvents = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]

        let hostingView = NSHostingView(rootView: RecordingPillView(state: state))
        hostingView.sizingOptions = []
        hostingView.frame = NSRect(origin: .zero, size: panelSize)
        hostingView.autoresizingMask = [.width, .height]
        panel.contentView = hostingView

        reposition(panel)
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func reposition(_ panel: NSPanel) {
        let screen = NSScreen.screens.first { $0.frame.contains(NSEvent.mouseLocation) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let origin = NSPoint(x: frame.midX - panelSize.width / 2,
                             y: frame.minY + 48)
        panel.setFrame(NSRect(origin: origin, size: panelSize), display: false)
    }

    private func hide() {
        panel?.orderOut(nil)
    }

    func tearDown() {
        cancellables.removeAll()
        panel?.orderOut(nil)
        panel = nil
    }
}

struct RecordingPillView: View {
    @ObservedObject var state: AppState

    var body: some View {
        VStack {
            Spacer(minLength: 0)
            content
                .padding(.horizontal, 18)
                .padding(.vertical, 12)
                .background(pillBackground)
                .shadow(color: .black.opacity(0.35), radius: 18, y: 6)
                .animation(.spring(response: 0.32, dampingFraction: 0.82), value: state.phase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .recording:
            HStack(spacing: 14) {
                PulsingDot(color: Theme.danger)
                Waveform(levels: state.levels)
                    .frame(width: 190, height: 26)
                Text(timeString)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.85))
                    .frame(width: 42, alignment: .trailing)
            }

        case .transcribing:
            HStack(spacing: 12) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                Text("Transkribiere …")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
                IdleWave(barCount: 14)
                    .frame(width: 80, height: 16)
            }

        case .inserted(let words):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(Theme.green)
                Text("\(words) \(words == 1 ? "Wort" : "Wörter") eingefügt")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(.white)
            }

        case .error(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Theme.amber)
                Text(message)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: 300, alignment: .leading)
            }

        case .idle:
            EmptyView()
        }
    }

    private var pillBackground: some View {
        Capsule(style: .continuous)
            .fill(Color(hex: 0x161622, opacity: 0.94))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 1)
            )
    }

    private var timeString: String {
        let total = Int(state.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PulsingDot: View {
    let color: Color
    @State private var big = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 9, height: 9)
            .scaleEffect(big ? 1.25 : 0.85)
            .opacity(big ? 1 : 0.7)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.65).repeatForever(autoreverses: true)) {
                    big = true
                }
            }
    }
}
