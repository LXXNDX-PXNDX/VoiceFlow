import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case home, history, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Diktieren"
        case .history: return "Verlauf"
        case .settings: return "Einstellungen"
        }
    }

    var icon: String {
        switch self {
        case .home: return "waveform"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "slider.horizontal.3"
        }
    }
}

struct RootView: View {
    @ObservedObject var state: AppState
    @State private var tab: SidebarTab = .home

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider().opacity(0.65)
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            brand

            ForEach(SidebarTab.allCases) { item in
                SidebarButton(item: item, isSelected: tab == item) {
                    withAnimation(.easeOut(duration: 0.15)) { tab = item }
                }
            }

            Spacer(minLength: 12)
            statusFooter
        }
        .frame(width: 178)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(.ultraThinMaterial)
    }

    private var brand: some View {
        HStack(spacing: 9) {
            ZStack {
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Theme.accent)
                    .frame(width: 30, height: 30)
                Image(systemName: "waveform")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.white)
            }
            VStack(alignment: .leading, spacing: 0) {
                Text("VoiceFlow")
                    .font(.system(size: 14, weight: .semibold))
                Text("Local dictation")
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 14)
        .padding(.top, 34)
        .padding(.bottom, 20)
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 7) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.system(size: 10.5, weight: .semibold))
                    .lineLimit(1)
            }

            HStack(spacing: 5) {
                Image(systemName: "keyboard")
                    .font(.system(size: 9.5))
                Text(state.settings.hotkeyMode.label)
                    .font(.system(size: 9.5))
                    .lineLimit(2)
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Color.primary.opacity(0.035), in: RoundedRectangle(cornerRadius: 12, style: .continuous))
        .padding(.horizontal, 10)
        .padding(.bottom, 12)
    }

    private var statusColor: Color {
        if !state.micGranted || !state.accessibilityGranted { return Theme.amber }
        switch state.modelState {
        case .ready: return Theme.green
        case .failed: return Theme.danger
        default: return Theme.amber
        }
    }

    private var statusText: String {
        if !state.micGranted { return "Mikrofon fehlt" }
        if !state.accessibilityGranted { return "Zugriff fehlt" }
        switch state.modelState {
        case .ready(let model): return "Bereit · \(model.shortLabel)"
        case .downloading(let progress): return "Download \(Int(progress * 100)) %"
        case .loading: return "Modell startet"
        case .failed: return "Modellfehler"
        case .idle: return "Initialisierung"
        }
    }

    @ViewBuilder
    private var content: some View {
        switch tab {
        case .home: HomeView(state: state, tab: $tab)
        case .history: HistoryView(state: state)
        case .settings: SettingsView(state: state)
        }
    }
}

private struct SidebarButton: View {
    let item: SidebarTab
    let isSelected: Bool
    let action: () -> Void
    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 9) {
                Image(systemName: item.icon)
                    .font(.system(size: 12, weight: .semibold))
                    .frame(width: 16)
                Text(item.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Theme.accent : Color.primary.opacity(hovering ? 0.90 : 0.72))
            .padding(.horizontal, 11)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(isSelected ? Theme.accent.opacity(0.11)
                                     : Color.primary.opacity(hovering ? 0.045 : 0))
            )
            .overlay(alignment: .leading) {
                if isSelected {
                    Capsule()
                        .fill(Theme.accent)
                        .frame(width: 3, height: 19)
                        .offset(x: -2)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering = $0 }
    }
}
