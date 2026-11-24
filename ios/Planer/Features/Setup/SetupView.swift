import SwiftUI

struct ConnectionForm: View {
    @Environment(AppModel.self) private var app
    var onConnected: (String) -> Void = { _ in }

    @State private var serverURL: String
    @State private var accessId: String
    @State private var accessSecret: String
    @State private var deviceToken: String
    @State private var testing = false
    @State private var error: String?

    init(initial: ServerConfig? = nil, onConnected: @escaping (String) -> Void = { _ in }) {
        self.onConnected = onConnected
        _serverURL = State(initialValue: initial?.baseURL.absoluteString ?? "")
        _accessId = State(initialValue: initial?.accessClientId ?? "")
        _accessSecret = State(initialValue: initial?.accessClientSecret ?? "")
        _deviceToken = State(initialValue: initial?.deviceToken ?? "")
    }

    var body: some View {
        Form {
            if let notice = app.notice {
                Section { ErrorText(message: notice) }
            }
            Section {
                TextField("https://planer.deinedomain.de", text: $serverURL)
                    .keyboardType(.URL)
                    .textContentType(.URL)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
            } header: {
                Text("Server-Adresse")
            }
            Section {
                TextField("Client-ID", text: $accessId)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                SecureField("Client-Secret", text: $accessSecret)
            } header: {
                Text("Cloudflare-Service-Token")
            } footer: {
                Text("Aus Cloudflare Zero Trust → Access → Service Auth. Leer lassen, wenn der Server ohne Cloudflare Access erreichbar ist (z. B. im WLAN).")
            }
            Section {
                SecureField("Geräte-Token", text: $deviceToken)
            } header: {
                Text("Geräte-Token")
            } footer: {
                Text("Auf dem Server erzeugen: python -m app.cli create-token \"iPhone\"")
            }
            Section {
                Button {
                    Task { await connect() }
                } label: {
                    if testing { ProgressView() } else { Text("Verbindung testen und speichern") }
                }
                .disabled(testing || serverURL.isEmpty || deviceToken.isEmpty)
                if let error { ErrorText(message: error) }
            }
        }
    }

    private func clean(_ value: String) -> String { value.trimmingCharacters(in: .whitespacesAndNewlines) }

    private func connect() async {
        error = nil
        guard let url = ServerConfig.normalizedURL(serverURL) else {
            error = "Ungültige Server-Adresse."
            return
        }
        testing = true
        defer { testing = false }
        let config = ServerConfig(
            baseURL: url, deviceToken: clean(deviceToken),
            accessClientId: clean(accessId), accessClientSecret: clean(accessSecret)
        )
        do {
            onConnected(try await app.connect(config))
        } catch {
            self.error = errorMessage(error)
        }
    }
}

struct SetupView: View {
    var body: some View {
        NavigationStack {
            ConnectionForm()
                .navigationTitle("Planer einrichten")
        }
    }
}
