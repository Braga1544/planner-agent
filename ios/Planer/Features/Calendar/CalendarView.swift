import SwiftUI

private enum EventSheetTarget: Identifiable {
    case new(day: String)
    case edit(EventOut, isRecurring: Bool)

    var id: String {
        switch self {
        case .new(let day): "new-\(day)"
        case .edit(let event, _): event.id
        }
    }
}

struct CalendarView: View {
    @Environment(AppModel.self) private var app
    @State private var model: CalendarViewModel
    @State private var sheet: EventSheetTarget?

    init(client: APIClient) {
        _model = State(initialValue: CalendarViewModel(client: client))
    }

    var body: some View {
        List {
            // not in the title, gets cut off between the buttons
            Text(model.title)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .listRowBackground(Color.clear)
                .accessibilityAddTraits(.isHeader)
            if let error = model.error {
                Section { ErrorText(message: error) }
            }
            ForEach(model.days, id: \.self) { day in
                Section {
                    let occurrences = model.grouped[day] ?? []
                    if occurrences.isEmpty {
                        Text("Keine Termine").foregroundStyle(.tertiary)
                    }
                    ForEach(occurrences) { occurrence in
                        Button {
                            Task { await open(occurrence) }
                        } label: {
                            OccurrenceRowView(occurrence: occurrence)
                        }
                        .tint(.primary)
                    }
                } header: {
                    dayHeader(day)
                }
            }
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 40).onEnded { value in
                guard abs(value.translation.width) > abs(value.translation.height) * 2 else { return }
                Task { await model.move(weeks: value.translation.width < 0 ? 1 : -1) }
            }
        )
        .navigationTitle("Kalender")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItemGroup(placement: .topBarLeading) {
                Button { Task { await model.move(weeks: -1) } } label: { Label("Vorherige Woche", systemImage: "chevron.left") }
                Button("Heute") { Task { await model.goToToday() } }
                Button { Task { await model.move(weeks: 1) } } label: { Label("Nächste Woche", systemImage: "chevron.right") }
            }
            ToolbarItem(placement: .primaryAction) {
                Button {
                    sheet = .new(day: model.days.contains(model.today) ? model.today : model.weekStart)
                } label: {
                    Label("Neuer Termin", systemImage: "plus")
                }
            }
        }
        .refreshable { await model.load() }
        .task(id: app.dataVersion) { await model.load() }
        .sheet(item: $sheet) { target in
            switch target {
            case .new(let day):
                EventSheet(client: model.client, event: nil, day: day, isRecurring: false) { app.didChangeData() }
            case .edit(let event, let isRecurring):
                EventSheet(client: model.client, event: event, day: model.weekStart, isRecurring: isRecurring) { app.didChangeData() }
            }
        }
    }

    private func dayHeader(_ day: String) -> some View {
        let isToday = day == model.today
        return HStack(spacing: 6) {
            Text(BerlinTime.weekdayShort(day))
            Text(BerlinTime.dayNumber(day))
                .fontWeight(.semibold)
                .foregroundStyle(isToday ? Color.white : Color.primary)
                .padding(.horizontal, 7)
                .padding(.vertical, 2)
                .background(isToday ? Color.accentColor : Color.clear, in: Capsule())
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(BerlinTime.formatLongDay(day) + (isToday ? ", heute" : ""))
    }

    private func open(_ occurrence: Occurrence) async {
        do {
            let event = try await model.loadEvent(id: occurrence.eventId)
            sheet = .edit(event, isRecurring: occurrence.isRecurring)
        } catch {
            model.error = errorMessage(error)
        }
    }
}
