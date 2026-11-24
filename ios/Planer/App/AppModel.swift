import Foundation
import Observation

enum AppTab: Hashable { case today, chat, calendar, areas, settings }

@MainActor
@Observable
final class AppModel {
    private(set) var client: APIClient?
    var selectedTab: AppTab = .today
    // bump -> visible views reload via .task(id:)
    private(set) var dataVersion = 0
    var notice: String?

    @ObservationIgnored private let store: CredentialStore
    @ObservationIgnored private let session: URLSession

    init(store: CredentialStore = CredentialStore(), session: URLSession = .shared) {
        self.store = store
        self.session = session
        if let config = store.loadConfig() { client = makeClient(config) }
    }

    var isConfigured: Bool { client != nil }
    var config: ServerConfig? { client?.config }

    // check /me first, then save
    func connect(_ config: ServerConfig) async throws -> String {
        let me: Me = try await APIClient(config: config, session: session).get("/me")
        try store.saveConfig(config)
        client = makeClient(config)
        notice = nil
        return me.tokenName
    }

    func logout() {
        Task { await ReminderScheduler.shared.clearAll() }
        store.clear()
        client = nil
        selectedTab = .today
    }

    func didChangeData() { dataVersion += 1 }

    private func handleUnauthorized() {
        guard client != nil else { return }
        logout()
        notice = "Der Geräte-Token ist ungültig oder gesperrt. Bitte neu einrichten."
    }

    private func makeClient(_ config: ServerConfig) -> APIClient {
        // not mainactor, apiclient calls this in the background
        APIClient(config: config, session: session, onUnauthorized: { @Sendable [weak self] in
            Task { @MainActor in self?.handleUnauthorized() }
        })
    }
}

extension ServerConfig {
    static func normalizedURL(_ input: String) -> URL? {
        var text = input.trimmingCharacters(in: .whitespacesAndNewlines)
        while text.hasSuffix("/") { text.removeLast() }
        guard !text.isEmpty else { return nil }
        if !text.contains("://") { text = "https://" + text }
        guard let url = URL(string: text),
              let scheme = url.scheme?.lowercased(), scheme == "https" || scheme == "http",
              let host = url.host, !host.isEmpty else { return nil }
        return url
    }
}
