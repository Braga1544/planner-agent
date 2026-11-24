import SwiftUI

struct RootView: View {
    @Environment(AppModel.self) private var app

    var body: some View {
        Group {
            if let client = app.client {
                // new credentials = new client, rebuild everything
                MainTabView(client: client).id(ObjectIdentifier(client))
            } else {
                SetupView()
            }
        }
        // picker always berlin, no matter what the device says
        .environment(\.timeZone, BerlinTime.timeZone)
        .environment(\.calendar, BerlinTime.calendar)
        .environment(\.locale, BerlinTime.locale)
    }
}
