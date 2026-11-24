import Testing
@testable import Planer

struct SmokeTests {
    @Test func appModuleLoads() {
        #expect(AppInfo.name == "Planer")
    }
}
