import Foundation
import FirebaseFirestore
import FirebaseAuth
import UserNotifications

#if canImport(FirebaseMessaging)
import FirebaseMessaging
#endif

/// Service for handling push notifications via Firebase Cloud Messaging
/// Manages FCM token registration and notification handling
@MainActor
class PushNotificationService: NSObject, ObservableObject {
    static let shared = PushNotificationService()

    @Published var fcmToken: String?
    @Published var pendingConversationId: String?

    private let db = Firestore.firestore()
    private var authStateHandle: AuthStateDidChangeListenerHandle?
    private var pendingToken: String?

    private override init() {
        super.init()
    }

    // MARK: - Setup

    /// Configure push notifications (call from AppDelegate/App init)
    func configure() {
        #if canImport(FirebaseMessaging)
        // Set messaging delegate
        Messaging.messaging().delegate = self
        #endif

        // Listen for auth state changes to save token when user logs in
        authStateHandle = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if user != nil {
                    // User logged in - save any pending token
                    if let pendingToken = self?.pendingToken {
                        #if DEBUG
                        print("📱 Saving pending FCM token after auth")
                        #endif
                        self?.saveTokenToFirestore(pendingToken)
                        self?.pendingToken = nil
                    } else if let currentToken = self?.fcmToken {
                        // Re-save current token in case it wasn't saved before
                        self?.saveTokenToFirestore(currentToken)
                    }
                }
            }
        }

        // Request notification permissions
        requestAuthorization()
    }

    /// Request notification permissions from the user
    func requestAuthorization() {
        let authOptions: UNAuthorizationOptions = [.alert, .badge, .sound]

        UNUserNotificationCenter.current().requestAuthorization(options: authOptions) { granted, error in
            if let error = error {
                #if DEBUG
                print("❌ Push notification authorization error: \(error)")
                #endif
                return
            }

            if granted {
                #if DEBUG
                print("✅ Push notification authorization granted")
                #endif
                DispatchQueue.main.async {
                    UIApplication.shared.registerForRemoteNotifications()
                }
            } else {
                #if DEBUG
                print("⚠️ Push notification authorization denied")
                #endif
            }
        }
    }

    // MARK: - Token Management

    /// Save the FCM token to Firestore user document
    func saveTokenToFirestore(_ token: String) {
        guard let uid = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("⚠️ Cannot save FCM token: No authenticated user")
            #endif
            return
        }

        let userRef = db.collection("users").document(uid)

        // Save token with device info
        let tokenData: [String: Any] = [
            "fcmToken": token,
            "fcmTokenUpdatedAt": FieldValue.serverTimestamp(),
            "platform": "ios",
            "appVersion": Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "unknown"
        ]

        userRef.updateData(tokenData) { error in
            #if DEBUG
            if let error = error {
                print("❌ Failed to save FCM token: \(error)")
            } else {
                print("✅ FCM token saved to Firestore")
            }
            #endif
        }
    }

    /// Remove FCM token from Firestore (call on logout)
    func removeTokenFromFirestore() {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let userRef = db.collection("users").document(uid)

        userRef.updateData([
            "fcmToken": FieldValue.delete(),
            "fcmTokenUpdatedAt": FieldValue.delete()
        ]) { error in
            #if DEBUG
            if let error = error {
                print("❌ Failed to remove FCM token: \(error)")
            } else {
                print("✅ FCM token removed from Firestore")
            }
            #endif
        }
    }

    // MARK: - Notification Handling

    /// Handle incoming notification when app is in foreground
    func handleForegroundNotification(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        // Extract conversation ID if present
        if let conversationId = userInfo["conversationId"] as? String {
            #if DEBUG
            print("📬 Foreground notification for conversation: \(conversationId)")
            #endif
            // Don't navigate automatically - just badge the conversation
            _ = conversationId // Silence unused variable warning in release
        }
    }

    /// Handle notification tap (app opened from notification)
    func handleNotificationTap(_ response: UNNotificationResponse) {
        let userInfo = response.notification.request.content.userInfo

        if let conversationId = userInfo["conversationId"] as? String {
            #if DEBUG
            print("📬 Notification tap - navigating to conversation: \(conversationId)")
            #endif
            pendingConversationId = conversationId
        }
    }

    /// Clear pending navigation
    func clearPendingNavigation() {
        pendingConversationId = nil
    }
}

// MARK: - MessagingDelegate

#if canImport(FirebaseMessaging)
extension PushNotificationService: MessagingDelegate {
    nonisolated func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }

        #if DEBUG
        print("📱 FCM Token received: \(token.prefix(20))...")
        #endif

        Task { @MainActor in
            self.fcmToken = token

            // Check if user is logged in
            if Auth.auth().currentUser != nil {
                self.saveTokenToFirestore(token)
            } else {
                // Store token to save later when user logs in
                #if DEBUG
                print("📱 User not logged in, storing token for later")
                #endif
                self.pendingToken = token
            }
        }
    }
}
#endif

// MARK: - UNUserNotificationCenterDelegate

extension PushNotificationService: UNUserNotificationCenterDelegate {
    /// Handle notification when app is in foreground
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show banner even when app is in foreground
        completionHandler([.banner, .sound, .badge])

        Task { @MainActor in
            self.handleForegroundNotification(notification)
        }
    }

    /// Handle notification tap
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        Task { @MainActor in
            self.handleNotificationTap(response)
        }

        completionHandler()
    }
}
