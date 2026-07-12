import SwiftUI
import FirebaseCore
import GoogleSignIn

@main
struct OnegaiCharinApp: App {
    @UIApplicationDelegateAdaptor(PushNotificationController.self) private var pushNotificationController
    @StateObject private var appState = AppState()
    @AppStorage("themeMode") private var themeMode = "system"

    init() {
        FirebaseApp.configure()
        FirebaseEmulatorConfiguration.configureIfRequested()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(appState)
                .preferredColorScheme(preferredColorScheme)
                .onOpenURL { url in
                    if !GIDSignIn.sharedInstance.handle(url) {
                        Task { await appState.handleIncomingURL(url) }
                    }
                }
                .onReceive(NotificationCenter.default.publisher(for: .didReceiveFCMToken)) { notification in
                    guard let token = notification.object as? String else { return }
                    Task { await appState.saveDeviceToken(token) }
                }
        }
    }

    private var preferredColorScheme: ColorScheme? {
        switch themeMode {
        case "light": .light
        case "dark": .dark
        default: nil
        }
    }
}
