import SwiftUI

struct TodayView: View {
    @Environment(AppModel.self) private var app
    @State private var model: TodayViewModel

    init(client: APIClient) {
        _model = State(initialValue: TodayViewModel(client: client))
    }

    private var titleParts: (String, String) {
        let long = BerlinTime.formatLongDay(model.today)
        guard let comma = long.range(of: ", ") else { return (long, "") }
        return (String(long[..<comma.lowerBound]), String(long[comma.upperBound...]))
    }

    var body: some View {
        List {
            Section {
                Text(titleParts.1).foregroundStyle(.secondary)
                QuickAddView(defaultDue: model.today) { title, area, due in
                    let added = await model.quickAdd(title: title, area: area, due: due)
                    if added { app.didChangeData() }
                    return added
                }
                if let actionError = model.actionError { ErrorText(message: actionError) }
            }
            if let error = model.error {
                Section { ErrorText(message: error) }
            }
            if let agenda = model.agenda {
                Section("Termine") {
                    if agenda.events.isEmpty { empty("Keine Termine.") }
                    ForEach(agenda.events) { OccurrenceRowView(occurrence: $0) }
                }
                if !agenda.overdueTodos.isEmpty {
                    Section {
                        ForEach(agenda.overdueTodos) { todoRow($0) }
                    } header: {
                        Text("Überfällig").foregroundStyle(.red)
                    }
                }
                Section("Heute fällig") {
                    if agenda.dueTodos.isEmpty { empty("Nichts fällig.") }
                    ForEach(agenda.dueTodos) { todoRow($0) }
                }
                ForEach(model.upcoming) { day in
                    Section(day.day == model.tomorrow ? "Morgen" : BerlinTime.formatDay(day.day)) {
                        if day.events.isEmpty && day.todos.isEmpty { empty("Nichts geplant.") }
                        ForEach(day.events) { OccurrenceRowView(occurrence: $0) }
                        ForEach(day.todos) { todoRow($0) }
                    }
                }
                Section {
                    Button("Weitere 7 Tage") { Task { await model.loadMore() } }
                        .disabled(model.isLoadingMore || model.days >= TodayViewModel.maxDays)
                }
            } else if model.error == nil {
                Section { ProgressView().frame(maxWidth: .infinity) }
            }
        }
        .navigationTitle(titleParts.0)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                NavigationLink {
                    SearchView(client: model.client)
                } label: {
                    Label("Suche", systemImage: "magnifyingglass")
                }
            }
        }
        .projectDestinations(client: model.client)
        .refreshable { await model.load() }
        .task(id: app.dataVersion) { await model.load() }
    }

    private func empty(_ text: String) -> some View {
        Text(text).foregroundStyle(.secondary)
    }

    private func todoRow(_ item: Item) -> some View {
        ItemRowView(item: item, onToggle: { toggle(item) })
            .swipeActions(edge: .leading) {
                Button { toggle(item) } label: {
                    Label(item.status == .done ? "Öffnen" : "Erledigt", systemImage: "checkmark")
                }
                .tint(.green)
            }
    }

    private func toggle(_ item: Item) {
        Task {
            if await model.toggle(item) { app.didChangeData() }
        }
    }
}

struct QuickAddView: View {
    let defaultDue: String
    let onAdd: (String, AreaSlug, String?) async -> Bool

    @State private var title = ""
    @State private var area: AreaSlug = .personal
    @State private var due: String?
    @State private var busy = false

    init(defaultDue: String, onAdd: @escaping (String, AreaSlug, String?) async -> Bool) {
        self.defaultDue = defaultDue
        self.onAdd = onAdd
        _due = State(initialValue: defaultDue)
    }

    var body: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                TextField("Neues ToDo…", text: $title)
                    .submitLabel(.done)
                    .onSubmit(add)
                MicButton(text: $title)
                Button(action: add) {
                    Image(systemName: "plus.circle.fill").font(.title2)
                }
                .buttonStyle(.borderless)
                .disabled(busy || title.trimmingCharacters(in: .whitespaces).isEmpty)
                .accessibilityLabel("Hinzufügen")
            }
            HStack {
                Picker("Bereich", selection: $area) {
                    ForEach(AreaSlug.allCases) { Text($0.name).tag($0) }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                Spacer()
                if due != nil {
                    DatePicker("Fällig am", selection: $due.asOptionalDay(default: { defaultDue }), displayedComponents: .date)
                        .labelsHidden()
                    Button { due = nil } label: {
                        Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel("Ohne Fälligkeit")
                } else {
                    Button("Fällig am …") { due = defaultDue }
                        .buttonStyle(.borderless)
                }
            }
        }
        .onChange(of: defaultDue) { old, new in
            // after midnight default to the new day
            if due == old { due = new }
        }
    }

    private func add() {
        guard !busy else { return }
        busy = true
        Task {
            if await onAdd(title, area, due) { title = "" }
            busy = false
        }
    }
}
