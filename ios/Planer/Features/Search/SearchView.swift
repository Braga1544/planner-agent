import SwiftUI

struct SearchView: View {
    @Environment(AppModel.self) private var app
    @State private var model: SearchViewModel
    @State private var sheet: Item?

    init(client: APIClient) {
        _model = State(initialValue: SearchViewModel(client: client))
    }

    var body: some View {
        List {
            if let error = model.error { ErrorText(message: error) }
            if let results = model.results {
                if results.items.isEmpty && results.projects.isEmpty && results.events.isEmpty {
                    Text("Nichts gefunden.").foregroundStyle(.secondary)
                }
                if !results.items.isEmpty {
                    Section("Einträge") {
                        ForEach(results.items) { item in
                            ItemRowView(item: item, onToggle: {
                                Task {
                                    if (try? await model.client.toggleDone(item)) != nil {
                                        app.didChangeData()
                                        await model.search()
                                    }
                                }
                            }, onEdit: { sheet = item })
                        }
                    }
                }
                if !results.projects.isEmpty {
                    Section("Projekte") {
                        ForEach(results.projects) { project in
                            NavigationLink(value: ProjectRoute(id: project.id)) {
                                VStack(alignment: .leading) {
                                    Text(project.name)
                                    Text(project.area.name).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
                if !results.events.isEmpty {
                    Section("Termine") {
                        ForEach(results.events) { event in
                            VStack(alignment: .leading) {
                                Text(event.title)
                                Text(event.allDay ? BerlinTime.formatDay(BerlinTime.isoToZoned(event.startAt)?.day ?? "") : BerlinTime.formatDateTime(event.startAt))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Suche")
        .searchable(text: $model.query, placement: .navigationBarDrawer(displayMode: .always), prompt: "ToDos, Notizen, Projekte, Termine")
        .task(id: model.query) {
            try? await Task.sleep(nanoseconds: 300_000_000) // debounce typing
            guard !Task.isCancelled else { return }
            await model.search()
        }
        .sheet(item: $sheet) { item in
            ItemSheet(client: model.client, item: item, defaults: .empty()) {
                app.didChangeData()
                Task { await model.search() }
            }
        }
    }
}
