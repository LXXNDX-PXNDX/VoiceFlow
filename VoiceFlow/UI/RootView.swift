import SwiftUI

enum SidebarTab: String, CaseIterable, Identifiable {
    case home, history, settings

    var id: String { rawValue }

    var title: String {
        switch self {
        case .home: return "Start"
        case .history: return "Verlauf"
        case .settings: return "Einstellungen"
        }
    }

    var icon: String {
        switch self {
        case .home: return "waveform"
        case .history: return "clock.arrow.circlepath"
        case .settings: return "gearshape"
        }
    }
}

struct RootView: View {
    @ObservedObject var state: AppState
    @State private var tab: SidebarTab = .home

    var body: some View {
        HStack(spacing: 0) {
            sidebar
            Divider()
            content
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    private var sidebar: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 9) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Theme.accentGradient)
                        .frame(width: 26, height: 26)
                    Image(systemName: "waveform")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.white)
                }
                Text("VoiceFlow")
                    .font(.system(size: 14, weight: .bold))
            }
            .padding(.horizontal, 12)
            .padding(.top, 34)
            .padding(.bottom, 18)

            ForEach(SidebarTab.allCases) { item in
                SidebarButton(item: item, isSelected: tab == item) { tab = item }
            }

            Spacer(minLength: 12)
            statusFooter
        }
        .frame(width: 186)
        .frame(maxHeight: .infinity, alignment: .top)
        .background(Color(nsColor: .underPageBackgroundColor))
    }

    private var statusFooter: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 7, height: 7)
                Text(statusText)
                    .font(.system(size: 10.5, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(state.settings.hotkeyMode.label)
                .font(.system(size: 10))
                .foregroundStyle(.tertiary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.bottom, 14)
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
        if !state.accessibilityGranted { return "Bedienungshilfen fehlen" }
        switch state.modelState {
        case .ready(let model): return "Bereit · \(model.rawValue)"
        case .downloading(let progress): return "Lädt \(Int(progress * 100)) %"
        case .loading: return "Modell startet …"
        case .failed: return "Modellfehler"
        case .idle: return "Startet …"
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
                    .font(.system(size: 12, weight: .medium))
                    .frame(width: 16)
                Text(item.title)
                    .font(.system(size: 12.5, weight: isSelected ? .semibold : .regular))
                Spacer(minLength: 0)
            }
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isSelected ? AnyShapeStyle(Theme.accentGradient)
                                     : AnyShapeStyle(Color.primary.opacity(hovering ? 0.07 : 0)))
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 8)
        .onHover { hovering = $0 }
    }
}
