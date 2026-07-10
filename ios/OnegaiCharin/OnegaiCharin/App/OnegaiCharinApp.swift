import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct OnegaiCharinApp: App {
    @StateObject private var appState = AppState()

    init() {
        FirebaseApp.configure()
        FirebaseEmulatorConfiguration.configureIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(.light)
                .onOpenURL { url in
                    GIDSignIn.sharedInstance.handle(url)
                }
        }
    }
}
