import AppKit
import SwiftUI
import Combine

/// The compact floating status pill near the bottom of the active screen.
@MainActor
final class RecordingPillController {

    private let panelSize = NSSize(width: 370, height: 92)
    private var panel: NSPanel?
    private var cancellables = Set<AnyCancellable>()
    private let state: AppState

    init(state: AppState) {
        self.state = state

        state.$phase
            .receive(on: RunLoop.main)
            .sink { [weak self] phase in self?.apply(phase: phase) }
            .store(in: &cancellables)

        state.settings.$showPill
            .receive(on: RunLoop.main)
            .sink { [weak self] enabled in
                guard let self else { return }
                if enabled {
                    self.apply(phase: self.state.phase)
                } else {
                    self.hide()
                }
            }
            .store(in: &cancellables)
    }

    private func apply(phase: AppState.Phase) {
        guard state.settings.showPill else {
            hide()
            return
        }
        phase == .idle ? hide() : show()
    }

    private func show() {
        if let panel {
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
                             y: frame.minY + 34)
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
                .padding(.horizontal, 15)
                .padding(.vertical, 11)
                .background(pillBackground)
                .shadow(color: .black.opacity(0.28), radius: 20, y: 8)
                .animation(.spring(response: 0.3, dampingFraction: 0.84), value: state.phase)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .allowsHitTesting(false)
    }

    @ViewBuilder
    private var content: some View {
        switch state.phase {
        case .recording:
            HStack(spacing: 12) {
                PulsingDot(color: Theme.danger)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Ich höre zu")
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Waveform(levels: state.levels, barWidth: 2.5, spacing: 2.5)
                        .frame(width: 205, height: 18)
                }
                Spacer(minLength: 4)
                Text(timeString)
                    .font(.system(size: 11, weight: .semibold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.72))
            }

        case .transcribing:
            HStack(spacing: 11) {
                ProgressView()
                    .controlSize(.small)
                    .tint(.white)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Text wird erzeugt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    Text("Lokal auf deinem Mac")
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.56))
                }
                Spacer()
                Image(systemName: "bolt.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Color(hex: 0x9DACFF))
            }

        case .inserted(let words):
            HStack(spacing: 10) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 17))
                    .foregroundStyle(Color(hex: 0x67D99D))
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(words) \(words == 1 ? "Wort" : "Wörter") eingefügt")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white)
                    if let speed = state.speedSummary {
                        Text(speed)
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.58))
                    }
                }
                Spacer()
            }

        case .error(let message):
            HStack(spacing: 10) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color(hex: 0xFFC66D))
                Text(message)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .frame(maxWidth: 290, alignment: .leading)
            }

        case .idle:
            EmptyView()
        }
    }

    private var pillBackground: some View {
        Capsule(style: .continuous)
            .fill(Color(hex: 0x17181C, opacity: 0.95))
            .overlay(
                Capsule(style: .continuous)
                    .strokeBorder(Color.white.opacity(0.11), lineWidth: 1)
            )
    }

    private var timeString: String {
        let total = Int(state.elapsed)
        return String(format: "%d:%02d", total / 60, total % 60)
    }
}

private struct PulsingDot: View {
    let color: Color
    @State private var expanded = false

    var body: some View {
        ZStack {
            Circle()
                .fill(color.opacity(0.18))
                .frame(width: 22, height: 22)
                .scaleEffect(expanded ? 1.12 : 0.82)
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 0.7).repeatForever(autoreverses: true)) {
                expanded = true
            }
        }
    }
}
