import SwiftUI

/// The shell. Native chrome over a phone mode of the admin (D-9/D-10).
///
/// 🚨 It strips chrome, never features. Every screen is the web app's --
/// there is deliberately no second implementation of anything here,
/// because two implementations of one screen is how the member half and
/// `/admin/me` drifted apart for months.
struct RootView: View {
    @State private var pendingPath: String?

    var body: some View {
        WebContainer(
            start: AppConfig.startURL,
            navigateTo: $pendingPath
        )
        .ignoresSafeArea(.container, edges: .bottom)
        .task {
            // Ask for push only once there is something to notify about.
            // A permission prompt on first launch, before the person has
            // seen the product, is how a grant gets refused permanently
            // ("Don't Allow" is close to irreversible on iOS).
            await PushRegistrar.shared.registerIfAlreadyGranted()
        }
        .onReceive(NotificationCenter.default.publisher(for: .tnOpenPath)) { note in
            pendingPath = note.userInfo?["path"] as? String
        }
    }
}
