import AppKit
import SwiftUI

struct HistoryView: View {
    @ObservedObject var state: AppState
    @ObservedObject private var history = HistoryStore.shared
    @State private var query = ""
    @State private var copiedID: UUID?

    private var filtered: [Transcript] {
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return history.items }
        return history.items.filter { $0.text.localizedCaseInsensitiveContains(query) }
    }

    var body: some View {
        VStack(spacing: 0) {
            toolbar
            Divider()
            if filtered.isEmpty {
                emptyState
            } else {
                list
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var toolbar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            TextField("Transkripte durchsuchen", text: $query)
                .textFieldStyle(.plain)
                .font(.system(size: 12))

            Spacer(minLength: 8)

            Text("\(history.items.count)")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)

            Menu {
                Button("Verlauf löschen", role: .destructive) { history.clear() }
            } label: {
                Image(systemName: "ellipsis.circle")
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .frame(width: 22)
        }
        .padding(.horizontal, 18)
        .padding(.top, 34)
        .padding(.bottom, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.bubble")
                .font(.system(size: 30, weight: .light))
                .foregroundStyle(.tertiary)
            Text(history.items.isEmpty ? "Noch keine Transkripte" : "Nichts gefunden")
                .font(.system(size: 13, weight: .medium))
            if history.items.isEmpty {
                Text("Halte \(state.settings.hotkeyMode.label.lowercased()) und sprich los.")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var list: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                ForEach(filtered) { item in
                    row(item)
                }
            }
            .padding(18)
        }
    }

    private func row(_ item: Transcript) -> some View {
        Card(padding: 13) {
            VStack(alignment: .leading, spacing: 8) {
                Text(item.text)
                    .font(.system(size: 12.5))
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)

                HStack(spacing: 8) {
                    Text(item.date.formatted(date: .abbreviated, time: .shortened))
                    Text("·")
                    Text("\(item.wordCount) Wörter")
                    Text("·")
                    Text(String(format: "%.1f s", item.durationSeconds))
                    if let app = item.appName {
                        Text("·")
                        Text(app)
                    }

                    Spacer(minLength: 8)

                    Button {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(item.text, forType: .string)
                        copiedID = item.id
                    } label: {
                        Label(copiedID == item.id ? "Kopiert" : "Kopieren",
                              systemImage: copiedID == item.id ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 10.5))
                    }
                    .buttonStyle(.borderless)

                    Button {
                        history.delete(item)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 10.5))
                    }
                    .buttonStyle(.borderless)
                }
                .font(.system(size: 10.5))
                .foregroundStyle(.secondary)
            }
        }
    }
}
