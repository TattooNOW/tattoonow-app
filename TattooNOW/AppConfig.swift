import Foundation

/// Everything the shell needs to know about the world outside it.
///
/// Values that differ per tier come from the xcconfig via Info.plist, so a
/// dev build can never be shipped pointing at prod by forgetting a flag.
enum AppConfig {

    /// 🚨 THE CONTRACT WITH THE WEB APP. Appended to the WKWebView's user
    /// agent; `tattoonow-sites` reads it to set `_inNativeApp`, which hides
    /// every price and upgrade CTA.
    ///
    /// App Store guideline 3.1.3(f) permits the member half only as a free
    /// companion to a paid web service, and only while nothing in the app
    /// sells and nothing points out to where it would. If this string
    /// changes, the reader in tattoonow-sites changes in the same breath --
    /// otherwise prices silently reappear and the next review rejects the
    /// binary for a reason nobody can see in the diff.
    static let userAgentSuffix = "TattooNOWApp/1.0"

    /// The admin origin this build talks to. Dev and prod differ; see
    /// Config/*.xcconfig.
    static var webOrigin: URL {
        guard
            let raw = Bundle.main.object(forInfoDictionaryKey: "TNWebOrigin") as? String,
            let url = URL(string: raw),
            url.scheme == "https",
            url.host != nil
        else {
            // A missing or malformed origin is a build misconfiguration, not
            // a runtime condition to degrade through: every screen in the
            // app is served from it, so there is nothing to show instead.
            fatalError("TNWebOrigin missing or not an https URL. Check Config/*.xcconfig.")
        }
        return url
    }

    /// Phone mode of the admin. ONE implementation of every screen: the
    /// shell strips chrome, never features (D-10).
    static var startURL: URL {
        webOrigin.appendingPathComponent("admin")
    }

    /// Hosts the WebView is allowed to navigate to in place. Anything else
    /// opens in Safari, so a link out of the product cannot end up looking
    /// like part of the app.
    static let inAppHosts: Set<String> = [
        "admin.tattoonow.com",
        "admin.tattoodirectories.com",
    ]
}
