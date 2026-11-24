import SwiftUI

struct ItemSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: ItemSheetModel
    @State private var confirmArchive = false
    let onChange: () -> Void

    init(client: APIClient, item: Item?, defaults: ItemForm, onChange: @escaping () -> Void) {
        _model = State(initialValue: ItemSheetModel(client: client, item: item, defaults: defaults))
        self.onChange = onChange
    }

    private var hasDue: Binding<Bool> {
        Binding(
            get: { model.form.dueDate != nil },
            set: { model.form.dueDate = $0 ? BerlinTime.today() : nil }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Typ", selection: $model.form.type) {
                        ForEach(ItemType.allCases) { Text($0.label).tag($0) }
                    }
                    .pickerStyle(.segmented)
                    TextField("Titel", text: $model.form.title)
                }
                Section("Details") {
                    TextField("Details (Markdown)", text: $model.form.body, axis: .vertical)
                        .lineLimit(3...10)
                }
                Section {
                    Picker("Bereich", selection: $model.form.area) {
                        ForEach(AreaSlug.allCases) { Text($0.name).tag($0) }
                    }
                    Picker("Projekt", selection: $model.form.projectId) {
                        Text("Keins").tag(String?.none)
                        ForEach(model.selectableProjects) { Text($0.name).tag(Optional($0.id)) }
                    }
                }
                if model.form.type == .todo {
                    Section {
                        Picker("Priorität", selection: $model.form.priority) {
                            ForEach(Priority.allCases) { Text($0.label).tag($0) }
                        }
                        Toggle("Fällig am", isOn: hasDue)
                        if hasDue.wrappedValue {
                            DatePicker("Datum", selection: $model.form.dueDate.asOptionalDay(), displayedComponents: .date)
                        }
                    }
                }
                if model.itemId != nil {
                    Section {
                        Picker("Status", selection: $model.form.status) {
                            ForEach([ItemStatus.open, .done]) { Text($0.label).tag($0) }
                        }
                    }
                }
                if let error = model.error {
                    Section { ErrorText(message: error) }
                }
                if model.itemId != nil {
                    Section {
                        Button("Archivieren", role: .destructive) { confirmArchive = true }
                    }
                }
            }
            .navigationTitle(model.itemId == nil ? "Neuer Eintrag" : "Eintrag")
            .navigationBarTitleDisplayMode(.inline)
            .task { await model.loadProjects() }
            .onChange(of: model.form.area) {
                model.form.projectId = nil
                Task { await model.loadProjects() }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Abbrechen") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Sichern") {
                        Task {
                            if await model.save() {
                                onChange()
                                dismiss()
                            }
                        }
                    }
                    .disabled(model.isSaving)
                }
            }
            .confirmationDialog("Eintrag archivieren?", isPresented: $confirmArchive, titleVisibility: .visible) {
                Button("Archivieren", role: .destructive) {
                    Task {
                        if await model.archive() {
                            onChange()
                            dismiss()
                        }
                    }
                }
            }
        }
    }
}
