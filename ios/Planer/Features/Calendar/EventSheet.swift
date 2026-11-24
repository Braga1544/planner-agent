import SwiftUI

struct EventSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var model: EventSheetModel
    @State private var confirmDelete = false
    let onChange: () -> Void

    init(client: APIClient, event: EventOut?, day: String, isRecurring: Bool, onChange: @escaping () -> Void) {
        _model = State(initialValue: EventSheetModel(client: client, event: event, day: day, isRecurring: isRecurring))
        self.onChange = onChange
    }

    private var reminderChoices: [(Int?, String)] {
        var choices = EventForm.reminderOptions
        if let current = model.form.reminder, !choices.contains(where: { $0.0 == current }) {
            choices.append((current, "\(current) Minuten vorher"))
        }
        return choices
    }

    private var hasEnd: Binding<Bool> {
        Binding(
            get: { !model.form.endTime.isEmpty },
            set: { on in
                if on { model.form.setDefaultEnd() } else { model.form.endTime = "" }
            }
        )
    }

    var body: some View {
        NavigationStack {
            Form {
                if model.readOnly {
                    Section { Label("Importierter Termin – nur lesbar.", systemImage: "lock") }
                } else if model.isRecurring && model.eventId != nil {
                    Section { Text("Änderungen gelten für die ganze Serie.").foregroundStyle(.secondary) }
                }
                // only disable content, a disabled form doesn't scroll
                Group {
                    Section {
                        TextField("Titel", text: $model.form.title)
                        Toggle("Ganztägig", isOn: $model.form.allDay)
                    }
                    Section {
                        DatePicker(model.form.allDay ? "Von" : "Datum", selection: $model.form.startDay.asDay(), displayedComponents: .date)
                        if model.form.allDay {
                            DatePicker("Bis (inklusive)", selection: $model.form.endDay.asDay(), displayedComponents: .date)
                        } else {
                            DatePicker("Beginn", selection: $model.form.startTime.asTime(), displayedComponents: .hourAndMinute)
                            Toggle("Mit Ende", isOn: hasEnd)
                            if hasEnd.wrappedValue {
                                DatePicker("Ende", selection: $model.form.endTime.asTime(), displayedComponents: .hourAndMinute)
                                DatePicker("Endet am", selection: $model.form.endDay.asDay(), displayedComponents: .date)
                            }
                        }
                    }
                    Section("Wiederholung") {
                        Picker("Wiederholung", selection: $model.form.repeatRule) {
                            ForEach(Repeat.allCases) { Text($0.label).tag($0) }
                        }
                        if model.form.repeatRule == .custom {
                            TextField("FREQ=WEEKLY;BYDAY=TU,TH", text: $model.form.customRule)
                                .font(.body.monospaced())
                                .textInputAutocapitalization(.characters)
                                .autocorrectionDisabled()
                        }
                    }
                    Section {
                        TextField("Ort", text: $model.form.location)
                        TextField("Notizen", text: $model.form.notes, axis: .vertical).lineLimit(3...8)
                    }
                    Section {
                        Picker("Bereich", selection: $model.form.area) {
                            Text("Keiner").tag(AreaSlug?.none)
                            ForEach(AreaSlug.allCases) { Text($0.name).tag(Optional($0)) }
                        }
                        Picker("Erinnerung", selection: $model.form.reminder) {
                            ForEach(reminderChoices, id: \.1) { Text($0.1).tag($0.0) }
                        }
                    }
                }
                .disabled(model.readOnly)
                if let error = model.error {
                    Section { ErrorText(message: error) }
                }
                if model.eventId != nil && !model.readOnly {
                    Section {
                        Button("Termin löschen", role: .destructive) { confirmDelete = true }
                    }
                }
            }
            .onChange(of: model.form.startDay) { oldDay, newDay in
                // same as web: single-day end follows start
                if model.form.endDay == oldDay || model.form.endDay < newDay { model.form.endDay = newDay }
            }
            .navigationTitle(model.eventId == nil ? "Neuer Termin" : "Termin")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(model.readOnly ? "Schließen" : "Abbrechen") { dismiss() }
                }
                if !model.readOnly {
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
            }
            .confirmationDialog("Termin löschen?", isPresented: $confirmDelete, titleVisibility: .visible) {
                Button("Löschen", role: .destructive) {
                    Task {
                        if await model.delete() {
                            onChange()
                            dismiss()
                        }
                    }
                }
            } message: {
                Text(model.isRecurring ? "Die ganze Serie wird gelöscht." : "Der Termin wird gelöscht.")
            }
        }
    }
}
