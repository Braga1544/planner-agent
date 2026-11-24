import Foundation
import Testing
@testable import Planer

struct CredentialStoreTests {
    @Test func saveLoadClear() throws {
        let suite = "planer-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        let store = CredentialStore(service: suite, defaults: defaults)
        let config = ServerConfig(
            baseURL: URL(string: "https://planer.example.com")!,
            deviceToken: "t", accessClientId: "id", accessClientSecret: "s"
        )
        #expect(store.loadConfig() == nil)
        try store.saveConfig(config)
        #expect(store.loadConfig() == config)
        store.clear()
        #expect(store.loadConfig() == nil)
        defaults.removePersistentDomain(forName: suite)
    }
}
