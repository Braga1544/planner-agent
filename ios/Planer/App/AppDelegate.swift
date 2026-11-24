import UIKit
import UserNotifications

@MainActor
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    weak var app: AppModel? {
        didSet {
            if let tab = pendingTab {
                app?.selectedTab = tab
                pendingTab = nil
            }
        }
    }
    private var pendingTab: AppTab?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .list, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let raw = response.notification.request.content.userInfo["tab"] as? String
        let tab: AppTab = raw == "calendar" ? .calendar : .today
        await MainActor.run {
            if let app = self.app {
                app.selectedTab = tab
            } else {
                self.pendingTab = tab
            }
        }
    }
}
