import Foundation
import UIKit
import UserNotifications

/// APNs registration, and handing the token to the web app.
///
/// 🚨 Why this is native at all: Web Push does not work inside a
/// WKWebView. The web app's existing `push_subscriptions` machinery is
/// VAPID/Web Push and cannot serve a wrapped shell, so the shell registers
/// with APNs and posts the token to our own origin.
///
/// 🚨 The endpoint below does not exist yet on tattoonow-sites. Until it
/// does, this stores the token and reports the failure rather than
/// pretending to have registered -- a push feature that silently never
/// arrives is worse than one that is visibly not wired.
@MainActor
final class PushRegistrar {
    static let shared = PushRegistrar()
    private init() {}

    private let tokenKey = "tn.apns.token"

    /// Ask iOS for the token only when the person has ALREADY granted
    /// permission. Prompting is a separate, deliberate act that belongs to
    /// a screen with a reason on it.
    func registerIfAlreadyGranted() async {
        let settings = await UNUserNotificationCenter.current().notificationSettings()
        guard settings.authorizationStatus == .authorized else { return }
        UIApplication.shared.registerForRemoteNotifications()
    }

    /// Call from a UI affordance that says what the notifications are for.
    @discardableResult
    func requestPermission() async -> Bool {
        let granted = (try? await UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge])) ?? false
        if granted { UIApplication.shared.registerForRemoteNotifications() }
        return granted
    }

    func didRegister(deviceToken: Data) {
        let hex = deviceToken.map { String(format: "%02x", $0) }.joined()
        UserDefaults.standard.set(hex, forKey: tokenKey)
        Task { await send(token: hex) }
    }

    func didFailToRegister(error: Error) {
        // Deliberately not swallowed: a device that cannot register is a
        // device that will never buzz, and the person has no way to tell.
        NSLog("[push] APNs registration failed: \(error.localizedDescription)")
    }

    private func send(token: String) async {
        // The session cookie lives in the WebView's data store, so the
        // request is made with it rather than with any key held here.
        // 🚨 No credential is ever compiled into this app.
        let url = AppConfig.webOrigin.appendingPathComponent("api/admin/push/apns")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try? JSONSerialization.data(withJSONObject: [
            "token": token,
            "platform": "ios",
            "environment": Bundle.main.object(forInfoDictionaryKey: "TNAPNSEnvironment") as? String ?? "unknown",
        ])

        let cookies = await WKCookieBridge.currentCookies()
        if !cookies.isEmpty {
            req.setValue(cookies, forHTTPHeaderField: "Cookie")
        }

        do {
            let (_, resp) = try await URLSession.shared.data(for: req)
            if let http = resp as? HTTPURLResponse, !(200..<300).contains(http.statusCode) {
                NSLog("[push] token POST rejected: HTTP \(http.statusCode)")
            }
        } catch {
            NSLog("[push] token POST failed: \(error.localizedDescription)")
        }
    }
}

import WebKit

/// Reads the WebView's cookies so a native request can be made AS the
/// signed-in person, instead of this app holding any credential of its own.
enum WKCookieBridge {
    @MainActor
    static func currentCookies() async -> String {
        let jar = WKWebsiteDataStore.default().httpCookieStore
        let cookies = await jar.allCookies()
        return cookies
            .filter { AppConfig.webOrigin.host?.hasSuffix($0.domain.hasPrefix(".") ? String($0.domain.dropFirst()) : $0.domain) ?? false }
            .map { "\($0.name)=\($0.value)" }
            .joined(separator: "; ")
    }
}
