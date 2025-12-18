import SwiftUI
import UserNotifications

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

@main
struct HallPalsApp: App {
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    @StateObject private var roleManager = RoleManager()
    @StateObject private var resourceStore = ResourceStore()

    init() {
        #if canImport(FirebaseCore)
        // Configure Firebase BEFORE any Firebase services are accessed
        FirebaseApp.configure()

        // Validate configuration and fail loudly if misconfigured
        let (isValid, error) = AuthDebugLogger.validateFirebaseConfig()
        if !isValid {
            // This is a fatal configuration error - app cannot function
            fatalError("❌ FIREBASE CONFIGURATION ERROR: \(error ?? "Unknown error"). Check GoogleService-Info.plist")
        }
        #else
        print("⚠️ FirebaseCore not available - running without Firebase")
        #endif
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(AppState.shared)
                .environmentObject(roleManager)
                .environmentObject(resourceStore)
                .environmentObject(FirebaseAuthManager.shared)
                .environmentObject(PushNotificationService.shared)
                .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                    // Clear badge when app becomes active
                    UNUserNotificationCenter.current().setBadgeCount(0)
                }
        }
    }
}

// MARK: - AppDelegate for Push Notifications

class AppDelegate: NSObject, UIApplicationDelegate {
    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        // Set notification center delegate
        UNUserNotificationCenter.current().delegate = PushNotificationService.shared

        // Configure push notification service
        Task { @MainActor in
            PushNotificationService.shared.configure()
        }

        return true
    }

    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        #if canImport(FirebaseMessaging)
        // Pass APNs token to Firebase Messaging
        Messaging.messaging().apnsToken = deviceToken
        #endif

        #if DEBUG
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("📱 APNs device token: \(tokenString.prefix(20))...")
        #endif
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        #if DEBUG
        print("❌ Failed to register for remote notifications: \(error)")
        #endif
    }

    // Handle background push notifications
    func application(
        _ application: UIApplication,
        didReceiveRemoteNotification userInfo: [AnyHashable: Any],
        fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
    ) {
        #if DEBUG
        print("📬 Received remote notification: \(userInfo)")
        #endif

        // Let Firebase handle the notification
        #if canImport(FirebaseMessaging)
        // appDidReceiveMessage returns MessagingMessageInfo, just call it for FCM processing
        _ = Messaging.messaging().appDidReceiveMessage(userInfo)
        #endif

        completionHandler(.newData)
    }
}
