import SwiftUI

private struct ItemSheetTarget: Identifiable {
    var item: Item?
    var defaults: ItemForm
    var id: String { item?.id ?? "new" }
}

struct AreaView: View {
    @Environment(AppModel.self) private var app
    @State private var model: AreaViewModel
    @State private var newProject = ""
    @State private var sheet: ItemSheetTarget?
    @Binding var path: NavigationPath

    init(client: APIClient, area: AreaSlug, path: Binding<NavigationPath>) {
        _model = State(initialValue: AreaViewModel(client: client, area: area))
        _path = path
    }

    var body: some View {
        List {
            if let error = model.error {
                Section { ErrorText(message: error) }
            }
            Section("Projekte") {
                ForEach(model.projects) { project in
                    NavigationLink(value: ProjectRoute(id: project.id)) {
                        HStack {
                            Text(project.name)
                            Spacer()
                            if project.status != .active {
                                Text(project.status.label).font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                HStack {
                    TextField("Neues Projekt", text: $newProject)
                        .submitLabel(.done)
                        .onSubmit(createProject)
                    Button("Anlegen", action: createProject)
                        .buttonStyle(.borderless)
                        .disabled(newProject.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            Section("Offene ToDos") {
                if model.openTodos.isEmpty { Text("Keine.").foregroundStyle(.secondary) }
                ForEach(model.openTodos) { item in
                    ItemRowView(
                        item: item,
                        showArea: false,
                        projectName: model.projectName(for: item),
                        onToggle: { toggle(item) },
                        onEdit: { sheet = ItemSheetTarget(item: item, defaults: .empty(area: model.area)) }
                    )
                    .swipeActions(edge: .leading) {
                        Button { toggle(item) } label: { Label("Erledigt", systemImage: "checkmark") }.tint(.green)
                    }
                }
            }
            Section("Lose Einträge") {
                if model.looseEntries.isEmpty { Text("Keine.").foregroundStyle(.secondary) }
                ForEach(model.looseEntries) { item in
                    ItemRowView(item: item, showArea: false, onEdit: {
                        sheet = ItemSheetTarget(item: item, defaults: .empty(area: model.area))
                    })
                }
            }
        }
        .navigationTitle(model.area.name)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = ItemSheetTarget(item: nil, defaults: .empty(area: model.area))
                } label: {
                    Label("Neuer Eintrag", systemImage: "plus")
                }
            }
        }
        .refreshable { await model.load() }
        .task(id: app.dataVersion) { await model.load() }
        .sheet(item: $sheet) { target in
            ItemSheet(client: model.client, item: target.item, defaults: target.defaults) { app.didChangeData() }
        }
    }

    private func createProject() {
        Task {
            if let project = await model.createProject(name: newProject) {
                newProject = ""
                app.didChangeData()
                path.append(ProjectRoute(id: project.id))
            }
        }
    }

    private func toggle(_ item: Item) {
        Task { if await model.toggle(item) { app.didChangeData() } }
    }
}
