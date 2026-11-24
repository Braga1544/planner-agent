import SwiftUI

struct SettingsView: View {
    @Environment(AppModel.self) private var app
    let client: APIClient

    @State private var tokenName: String?
    @State private var connectionError: String?
    @State private var editingConnection = false
    @State private var confirmLogout = false
    @State private var reminders = ReminderSettings.load()
    @State private var sources: CalendarSourcesViewModel
    @State private var pendingDelete: CalendarSource?

    init(client: APIClient) {
        self.client = client
        _sources = State(initialValue: CalendarSourcesViewModel(client: client))
    }

    private var briefingTime: Binding<String> {
        Binding(
            get: { String(format: "%02d:%02d", reminders.briefingMinutes / 60, reminders.briefingMinutes % 60) },
            set: { value in
                let parts = value.split(separator: ":").compactMap { Int($0) }
                if parts.count == 2 { reminders.briefingMinutes = parts[0] * 60 + parts[1] }
            }
        )
    }

    var body: some View {
        Form {
            Section {
                LabeledContent("Server", value: client.config.baseURL.host ?? client.config.baseURL.absoluteString)
                if let connectionError {
                    ErrorText(message: connectionError)
                } else {
                    Label(
                        tokenName.map { "Verbunden als \($0)" } ?? "Prüfe Verbindung…",
                        systemImage: tokenName == nil ? "circle.dotted" : "checkmark.circle.fill"
                    )
                }
                LabeledContent("Cloudflare-Service-Token", value: client.config.accessClientId.isEmpty ? "nicht gesetzt" : "gesetzt")
                Button("Zugangsdaten ändern") { editingConnection = true }
                Button("Abmelden", role: .destructive) { confirmLogout = true }
            } header: {
                Text("Verbindung")
            }

            CalendarSourcesSection(model: sources, pendingDelete: $pendingDelete)

            Section {
                Toggle("Termin-Erinnerungen", isOn: $reminders.eventReminders)
                Toggle("Morgen-Briefing", isOn: $reminders.briefing)
                if reminders.briefing {
                    DatePicker("Uhrzeit", selection: briefingTime.asTime(), displayedComponents: .hourAndMinute)
                }
            } header: {
                Text("Benachrichtigungen")
            } footer: {
                Text("Ohne Push-Dienst gilt der Briefing-Text vom letzten Öffnen der App. Erinnerungen gibt es für die Termine der nächsten 14 Tage, die beim letzten Öffnen bekannt waren.")
            }

            Section("Kalender-Abo (ICS-Feed)") {
                Text("Eigene Termine in iCloud oder Outlook abonnieren: \(client.config.baseURL.absoluteString)/calendar/<ICS_FEED_TOKEN>.ics – den Token findest du in der Server-Konfiguration (ICS_FEED_TOKEN).")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
        .navigationTitle("Einstellungen")
        .task(id: app.dataVersion) {
            await checkConnection()
            await sources.load()
        }
        .onChange(of: reminders) {
            reminders.save()
            Task { await ReminderScheduler.shared.refresh(client: client) }
        }
        .sheet(isPresented: $editingConnection) {
            NavigationStack {
                ConnectionForm(initial: client.config) { _ in editingConnection = false }
                    .navigationTitle("Zugangsdaten")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Abbrechen") { editingConnection = false }
                        }
                    }
            }
        }
        .confirmationDialog(
            "Kalenderquelle „\(pendingDelete?.name ?? "")“ und ihre Termine löschen?",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("Löschen", role: .destructive) {
                if let source = pendingDelete {
                    Task { if await sources.remove(source) { app.didChangeData() } }
                }
            }
        }
        .confirmationDialog("Abmelden?", isPresented: $confirmLogout, titleVisibility: .visible) {
            Button("Abmelden", role: .destructive) { app.logout() }
        } message: {
            Text("Server-Adresse und Zugangsdaten werden von diesem iPhone gelöscht.")
        }
    }

    private func checkConnection() async {
        do {
            let me: Me = try await client.get("/me")
            tokenName = me.tokenName
            connectionError = nil
        } catch {
            guard !isCancellation(error) else { return }
            connectionError = errorMessage(error)
        }
    }
}
