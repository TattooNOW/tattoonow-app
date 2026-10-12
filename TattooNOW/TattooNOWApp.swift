import SwiftUI
import UIKit

@main
struct TattooNOWApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        WindowGroup {
            RootView()
        }
    }
}

/// 🚨 This delegate exists for ONE reason: push.
///
/// Web Push does not work inside a WKWebView. The member half is served
/// from the web app, so everything else it needs it already has -- but a
/// notification has to be registered for, received and routed natively or
/// it does not arrive at all. Nothing else belongs in here.
final class AppDelegate: NSObject, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        PushRegistrar.shared.didRegister(deviceToken: deviceToken)
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        PushRegistrar.shared.didFailToRegister(error: error)
    }

    /// A notification arriving while the app is open must still be drawn.
    /// 🚨 iOS will not show one for an app you are looking at unless this
    /// says so -- which is exactly the state a person is in when they press
    /// "Send test", so without this the feature reads as broken while
    /// working. (PUSH-NOTIFICATIONS-TEST-PLAN names this as the trap that
    /// costs the most time.)
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification
    ) async -> UNNotificationPresentationOptions {
        [.banner, .sound, .badge]
    }

    /// Tapping a notification opens the thing it is about. The payload
    /// carries a path on our own origin; anything else is ignored rather
    /// than followed.
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse
    ) async {
        let info = response.notification.request.content.userInfo
        guard let path = info["path"] as? String, path.hasPrefix("/") else { return }
        await MainActor.run {
            NotificationCenter.default.post(
                name: .tnOpenPath,
                object: nil,
                userInfo: ["path": path]
            )
        }
    }
}

extension Notification.Name {
    static let tnOpenPath = Notification.Name("tn.openPath")
}
