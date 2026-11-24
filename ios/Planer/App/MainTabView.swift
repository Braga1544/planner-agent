import SwiftUI

struct MainTabView: View {
    @Environment(AppModel.self) private var app
    let client: APIClient
    @Environment(\.scenePhase) private var scenePhase

    var body: some View {
        @Bindable var app = app
        TabView(selection: $app.selectedTab) {
            NavigationStack { TodayView(client: client) }
                .tabItem { Label("Heute", systemImage: "sun.max") }
                .tag(AppTab.today)
            ChatListView(client: client)
                .tabItem { Label("Chat", systemImage: "bubble.left.and.bubble.right") }
                .tag(AppTab.chat)
            NavigationStack { CalendarView(client: client) }
                .tabItem { Label("Kalender", systemImage: "calendar") }
                .tag(AppTab.calendar)
            AreasView(client: client)
                .tabItem { Label("Bereiche", systemImage: "square.grid.2x2") }
                .tag(AppTab.areas)
            NavigationStack { SettingsView(client: client) }
                .tabItem { Label("Einstellungen", systemImage: "gearshape") }
                .tag(AppTab.settings)
        }
        .task(id: app.dataVersion) {
            await ReminderScheduler.shared.refresh(client: client)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                Task { await ReminderScheduler.shared.refresh(client: client) }
            }
        }
    }
}
