import SwiftUI
import WebKit

/// The WKWebView that is the whole member half.
struct WebContainer: UIViewRepresentable {
    let start: URL
    @Binding var navigateTo: String?

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()

        // A persistent data store, so the session cookie survives a
        // relaunch. `sessionCookieDomain()` on the web side scopes it to
        // .tattoonow.com; the shell does not mint or read it.
        config.websiteDataStore = .default()
        config.allowsInlineMediaPlayback = true

        let web = WKWebView(frame: .zero, configuration: config)
        web.navigationDelegate = context.coordinator
        web.uiDelegate = context.coordinator
        web.allowsBackForwardNavigationGestures = true

        // 🚨 The contract. See AppConfig.userAgentSuffix.
        web.customUserAgent = (web.value(forKey: "userAgent") as? String).map {
            "\($0) \(AppConfig.userAgentSuffix)"
        } ?? AppConfig.userAgentSuffix

        web.load(URLRequest(url: start))
        return web
    }

    func updateUIView(_ web: WKWebView, context: Context) {
        guard let path = navigateTo,
              var comps = URLComponents(url: AppConfig.webOrigin, resolvingAgainstBaseURL: false)
        else { return }
        comps.path = path
        if let url = comps.url {
            web.load(URLRequest(url: url))
        }
        DispatchQueue.main.async { navigateTo = nil }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {

        /// Keeps the app inside the app, and everything else outside it.
        ///
        /// 🚨 Two different reasons, both load-bearing:
        ///  - A third-party page rendered inside our chrome looks like part
        ///    of the product and is not (guideline 4.2 / 5.1.1).
        ///  - 🚨 Google OAuth is BLOCKED in an embedded web view. Sign-in
        ///    here is magic link or password (D-4 revised); a Google button
        ///    that opened in-place would dead-end. If one ever reaches the
        ///    page, pushing it to Safari at least fails visibly.
        func webView(
            _ webView: WKWebView,
            decidePolicyFor action: WKNavigationAction
        ) async -> WKNavigationActionPolicy {
            guard let url = action.request.url else { return .cancel }
            guard let host = url.host else { return .cancel }

            if AppConfig.inAppHosts.contains(host) {
                return .allow
            }

            // mailto:, tel:, maps: and any external site: hand to the system.
            await MainActor.run {
                UIApplication.shared.open(url)
            }
            return .cancel
        }

        /// `target="_blank"` has no window to open into inside a shell, so
        /// without this such links do nothing at all -- a dead button with
        /// no error, which is the hardest kind of failure to report.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for action: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if let url = action.request.url {
                if let host = url.host, AppConfig.inAppHosts.contains(host) {
                    webView.load(URLRequest(url: url))
                } else {
                    UIApplication.shared.open(url)
                }
            }
            return nil
        }
    }
}
