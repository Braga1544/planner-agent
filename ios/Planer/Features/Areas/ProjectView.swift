import SwiftUI

struct ProjectView: View {
    @Environment(AppModel.self) private var app
    @State private var model: ProjectViewModel
    @State private var editingDescription = false
    @State private var draft = ""
    @State private var sheet: Item?
    @State private var creating = false

    init(client: APIClient, projectId: String) {
        _model = State(initialValue: ProjectViewModel(client: client, projectId: projectId))
    }

    var body: some View {
        List {
            if let error = model.error {
                Section { ErrorText(message: error) }
            }
            if let project = model.project {
                Section {
                    Picker("Status", selection: Binding(
                        get: { project.status },
                        set: { status in Task { if await model.setStatus(status) { app.didChangeData() } } }
                    )) {
                        ForEach(ProjectStatus.allCases) { Text($0.label).tag($0) }
                    }
                    LabeledContent("Bereich", value: project.area.name)
                }
                Section {
                    if let description = project.description {
                        MarkdownText(text: description)
                    } else {
                        Text("Noch keine Projektinfos.").foregroundStyle(.secondary)
                    }
                } header: {
                    HStack {
                        Text("Projektinfos")
                        Spacer()
                        Button("Bearbeiten") {
                            draft = project.description ?? ""
                            editingDescription = true
                        }
                        .font(.caption)
                    }
                }
                ForEach(ItemType.allCases) { type in
                    Section(type.groupLabel) {
                        let items = model.groups[type] ?? []
                        if items.isEmpty { Text("Keine.").foregroundStyle(.secondary) }
                        ForEach(items) { item in
                            ItemRowView(item: item, showArea: false, onToggle: {
                                Task { if await model.toggle(item) { app.didChangeData() } }
                            }, onEdit: { sheet = item })
                        }
                    }
                }
            } else if model.error == nil {
                ProgressView().frame(maxWidth: .infinity)
            }
        }
        .navigationTitle(model.project?.name ?? "Projekt")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button { creating = true } label: { Label("Neuer Eintrag", systemImage: "plus") }
                    .disabled(model.project == nil)
            }
        }
        .refreshable { await model.load() }
        .task(id: app.dataVersion) { await model.load() }
        .sheet(item: $sheet) { item in
            ItemSheet(client: model.client, item: item, defaults: .empty()) { app.didChangeData() }
        }
        .sheet(isPresented: $creating) {
            if let project = model.project {
                ItemSheet(client: model.client, item: nil, defaults: .empty(area: project.area, projectId: project.id)) { app.didChangeData() }
            }
        }
        .sheet(isPresented: $editingDescription) {
            NavigationStack {
                TextEditor(text: $draft)
                    .font(.body.monospaced())
                    .padding(.horizontal)
                    .navigationTitle("Projektinfos")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { editingDescription = false }
                        }
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Sichern") {
                                Task {
                                    if await model.saveDescription(draft) {
                                        editingDescription = false
                                        app.didChangeData()
                                    }
                                }
                            }
                        }
                    }
            }
        }
    }
}
