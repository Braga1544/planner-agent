import SwiftUI

@main
struct PlanerApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @State private var app = AppModel()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(app)
                .onAppear { delegate.app = app }
        }
    }
}

enum AppInfo {
    static let name = "Planer"
}
