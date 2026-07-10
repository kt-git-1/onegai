import FirebaseAuth
import FirebaseFirestore
import FirebaseFunctions
import Foundation

enum FirebaseEmulatorConfiguration {
    static func configureIfRequested() {
        guard ProcessInfo.processInfo.arguments.contains("-useFirebaseEmulator") else { return }

        Auth.auth().useEmulator(withHost: "127.0.0.1", port: 9099)
        let firestore = Firestore.firestore()
        let settings = firestore.settings
        settings.host = "127.0.0.1:8080"
        settings.cacheSettings = MemoryCacheSettings()
        settings.isSSLEnabled = false
        firestore.settings = settings
        Functions.functions(region: "asia-northeast1").useEmulator(withHost: "127.0.0.1", port: 5001)
    }
}
