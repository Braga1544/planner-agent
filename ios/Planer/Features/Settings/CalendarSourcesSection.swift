import SwiftUI

// modifiers live on the settings view, on the section they'd apply per row
struct CalendarSourcesSection: View {
    @Environment(AppModel.self) private var app
    let model: CalendarSourcesViewModel
    @Binding var pendingDelete: CalendarSource?
    @State private var name = ""
    @State private var url = ""
    @State private var area: AreaSlug? = nil

    var body: some View {
        Section {
            if let error = model.error { ErrorText(message: error) }
            ForEach(model.sources) { source in
                sourceRow(source)
                    .swipeActions {
                        Button("Löschen", role: .destructive) { pendingDelete = source }
                    }
            }
        } header: {
            Text("Kalenderquellen")
        } footer: {
            Text("Externe Kalender (z. B. veröffentlichter Outlook-/Teams-Kalender) als ICS-Link. Sie werden alle 15 Minuten abgeglichen und sind nur lesbar.")
        }

        Section("Kalenderquelle hinzufügen") {
            TextField("Name", text: $name)
            TextField("https://… oder webcal://…", text: $url)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Picker("Bereich", selection: $area) {
                Text("Keiner").tag(AreaSlug?.none)
                ForEach(AreaSlug.allCases) { Text($0.name).tag(Optional($0)) }
            }
            Button("Hinzufügen") {
                Task {
                    if await model.add(name: name, url: url, area: area) {
                        name = ""
                        url = ""
                        area = nil
                        app.didChangeData()
                    }
                }
            }
            .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty || url.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private func sourceRow(_ source: CalendarSource) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(source.name).fontWeight(.medium)
                if let area = source.area {
                    Text(area.name).font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Toggle("aktiv", isOn: Binding(
                    get: { source.enabled },
                    set: { _ in Task { if await model.toggle(source) { app.didChangeData() } } }
                ))
                .labelsHidden()
            }
            Text(source.url)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .truncationMode(.middle)
            Text("Zuletzt synchronisiert: \(source.lastSyncedAt.map(BerlinTime.formatDateTime) ?? "noch nie")")
                .font(.caption)
                .foregroundStyle(.secondary)
            if let lastError = source.lastError {
                Text(lastError).font(.caption).foregroundStyle(.red)
            }
            if let note = model.lastSync, note.sourceId == source.id {
                Text(note.text).font(.caption).foregroundStyle(note.failed ? Color.red : Color.secondary)
            }
            Button {
                Task { if await model.sync(source) { app.didChangeData() } }
            } label: {
                Label("Jetzt synchronisieren", systemImage: "arrow.triangle.2.circlepath")
            }
            .buttonStyle(.borderless)
            .disabled(model.syncingId != nil)
        }
    }
}
