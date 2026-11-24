import Foundation
import Testing
@testable import Planer

@MainActor
struct AppModelTests {
    private func freshStore() -> CredentialStore {
        let suite = "planer-tests-\(UUID().uuidString)"
        return CredentialStore(service: suite, defaults: UserDefaults(suiteName: suite)!)
    }

    @Test func normalizesServerAddress() {
        #expect(ServerConfig.normalizedURL("planer.example.de")?.absoluteString == "https://planer.example.de")
        #expect(ServerConfig.normalizedURL(" https://planer.example.de/ ")?.absoluteString == "https://planer.example.de")
        #expect(ServerConfig.normalizedURL("http://192.168.1.10:8080")?.absoluteString == "http://192.168.1.10:8080")
        #expect(ServerConfig.normalizedURL("ftp://x") == nil)
        #expect(ServerConfig.normalizedURL("") == nil)
    }

    @Test func connectSavesOnlyAfterSuccessfulCheck() async throws {
        let store = freshStore()
        let model = AppModel(store: store, session: StubURLProtocol.session())
        let denied = StubServer()
        denied.on("GET", "/me", status: 403, json: "{}")
        let deniedConfig = ServerConfig(baseURL: denied.baseURL, deviceToken: "t", accessClientId: "id", accessClientSecret: "s")
        await #expect(throws: APIError.accessDenied) { _ = try await model.connect(deniedConfig) }
        #expect(store.loadConfig() == nil)
        #expect(!model.isConfigured)

        let server = StubServer()
        server.on("GET", "/me", json: #"{"token_name":"iPhone"}"#)
        let config = ServerConfig(baseURL: server.baseURL, deviceToken: "t", accessClientId: "id", accessClientSecret: "s")
        let name = try await model.connect(config)
        #expect(name == "iPhone")
        #expect(store.loadConfig() == config)
        #expect(model.isConfigured)
    }

    @Test func unauthorizedLogsOutWithNotice() async throws {
        let store = freshStore()
        let server = StubServer()
        server.on("GET", "/me", json: #"{"token_name":"iPhone"}"#)
        let model = AppModel(store: store, session: StubURLProtocol.session())
        _ = try await model.connect(ServerConfig(baseURL: server.baseURL, deviceToken: "t", accessClientId: "", accessClientSecret: ""))

        server.on("GET", "/me", status: 401, json: #"{"detail":"Token ungültig"}"#)
        let _: Me? = try? await model.client?.get("/me")
        for _ in 0..<50 where model.isConfigured {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        #expect(!model.isConfigured)
        #expect(store.loadConfig() == nil)
        #expect(model.notice?.contains("Geräte-Token") == true)
    }

    @Test func didChangeDataBumpsVersion() {
        let model = AppModel(store: freshStore(), session: StubURLProtocol.session())
        let before = model.dataVersion
        model.didChangeData()
        #expect(model.dataVersion == before + 1)
    }
}
