import Foundation
import SwiftUI

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Manages Firebase Authentication for the app
/// Handles email/password sign-up, sign-in, and sign-out
@MainActor
class FirebaseAuthManager: ObservableObject {

    static let shared = FirebaseAuthManager()

    @Published var isAuthenticated = false
    @Published var currentUserId: String?
    @Published var userEmail: String?
    @Published var isEmailVerified = false
    @Published var errorMessage: String?
    @Published var isLoading = false

    #if canImport(FirebaseAuth)
    private var authStateListener: AuthStateDidChangeListenerHandle?
    #endif

    private init() {
        setupAuthStateListener()
    }

    deinit {
        #if canImport(FirebaseAuth)
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
        #endif
    }

    // MARK: - Auth State Listener

    private func setupAuthStateListener() {
        #if canImport(FirebaseAuth)
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                let wasAuthenticated = self?.isAuthenticated ?? false
                self?.currentUserId = user?.uid
                self?.userEmail = user?.email
                self?.isEmailVerified = user?.isEmailVerified ?? false
                self?.isAuthenticated = user != nil

                // Log state change
                if wasAuthenticated != (user != nil) {
                    AuthDebugLogger.logStateTransition(
                        from: wasAuthenticated ? "authenticated" : "unauthenticated",
                        to: user != nil ? "authenticated" : "unauthenticated",
                        reason: "Firebase auth state listener fired"
                    )
                }

                // Self-heal: Ensure user document exists when user is authenticated
                // This fires both when:
                // 1. User transitions from unauthenticated -> authenticated (login)
                // 2. App launches with already-authenticated user (first listener callback)
                if user != nil {
                    await self?.callEnsureUserDoc()
                }
            }
        }
        #endif
    }

    // MARK: - User Document Self-Heal + Roster Discovery

    /// Calls joinHall to ensure user doc exists AND discover hall/role from roster
    /// Called automatically after login and on app launch when already logged in
    /// V2: Replaced ensureUserDoc with joinHall for roster-based discovery
    private func callEnsureUserDoc() async {
        do {
            let response = try await CloudFunctionsService.shared.joinHall()
            #if DEBUG
            print("🔧 AUTH: joinHall (self-heal) completed - role: \(response.role), hallId: \(response.hallId.isEmpty ? "none" : response.hallId)")
            #endif

            // Update AppState with discovered role from roster
            await MainActor.run {
                let role: UserRole = response.role == "ra" ? .ra : .resident
                AppState.shared.savedRole = role
                #if DEBUG
                print("🔧 AUTH: Updated AppState.savedRole to \(role.displayName)")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔧 AUTH: joinHall (self-heal) failed - \(error.localizedDescription)")
            // In DEBUG, we log but don't crash. The user can still use the app,
            // and the next login attempt will try again.
            #endif
        }
    }

    // MARK: - Provider Discovery

    /// Fetches sign-in methods for an email to determine if the account exists
    /// and what providers are available. This disambiguates error 17004.
    /// NOTE: This API is deprecated when Email Enumeration Protection is enabled
    /// and will return an empty array. We still call it for logging but don't
    /// rely on it for error handling.
    func fetchSignInMethods(forEmail email: String) async -> [String] {
        #if canImport(FirebaseAuth)
        let normalizedEmail = AuthDebugLogger.normalizeEmail(email)
        AuthDebugLogger.logAuthAction("FETCH_SIGN_IN_METHODS", email: normalizedEmail)

        do {
            // Note: This is deprecated and returns [] when Email Enumeration Protection is enabled
            let methods = try await Auth.auth().fetchSignInMethods(forEmail: normalizedEmail)
            AuthDebugLogger.logProviderDiscovery(email: normalizedEmail, methods: methods)
            return methods
        } catch {
            // Don't throw - this API may fail when Email Enumeration Protection is on
            AuthDebugLogger.logAuthError(action: "FETCH_SIGN_IN_METHODS", error: error)
            return []
        }
        #else
        return []
        #endif
    }

    // MARK: - Email Verification

    /// Sends/Resends email verification link
    func sendEmailVerification() async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.noUser
        }

        AuthDebugLogger.logAuthAction("SEND_VERIFICATION_EMAIL", email: user.email ?? "unknown")

        do {
            try await user.sendEmailVerification()
            AuthDebugLogger.logAuthSuccess(
                action: "SEND_VERIFICATION_EMAIL",
                uid: user.uid,
                email: user.email,
                isVerified: false
            )
        } catch {
            AuthDebugLogger.logAuthError(action: "SEND_VERIFICATION_EMAIL", error: error)
            throw error
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    /// Reloads user profile to check for verification updates
    /// Returns true if email is now verified
    @discardableResult
    func reloadUser() async throws -> Bool {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.noUser
        }

        AuthDebugLogger.logAuthAction("RELOAD_USER", email: user.email ?? "unknown")

        do {
            try await user.reload()

            // IMPORTANT: After reload(), we must re-fetch currentUser to get updated state
            let refreshedUser = Auth.auth().currentUser
            let verified = refreshedUser?.isEmailVerified ?? false

            // Update published state on main actor
            self.isEmailVerified = verified
            self.userEmail = refreshedUser?.email
            self.currentUserId = refreshedUser?.uid

            AuthDebugLogger.logVerificationCheck(isVerified: verified, userEmail: refreshedUser?.email)
            return verified
        } catch {
            AuthDebugLogger.logAuthError(action: "RELOAD_USER", error: error)
            throw error
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Sign Up

    /// Creates a new user account with email and password
    /// Optionally sets the user's display name
    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        #if canImport(FirebaseAuth)
        let normalizedEmail = AuthDebugLogger.normalizeEmail(email)

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Validate config first
        let (isValid, configError) = AuthDebugLogger.validateFirebaseConfig()
        guard isValid else {
            let error = configError ?? "Unknown configuration error"
            errorMessage = error
            throw FirebaseAuthError.signUpFailed(error)
        }

        AuthDebugLogger.logAuthAction("SIGN_UP", email: normalizedEmail)

        do {
            let result = try await Auth.auth().createUser(withEmail: normalizedEmail, password: password)

            // Update display name if provided
            if let displayName = displayName, !displayName.isEmpty {
                let changeRequest = result.user.createProfileChangeRequest()
                changeRequest.displayName = displayName
                try await changeRequest.commitChanges()

                #if DEBUG
                print("🔐 AUTH: Display name set to '\(displayName)'")
                #endif
            }

            currentUserId = result.user.uid
            userEmail = result.user.email
            isEmailVerified = false // New users are never verified
            isAuthenticated = true

            AuthDebugLogger.logAuthSuccess(
                action: "SIGN_UP",
                uid: result.user.uid,
                email: result.user.email,
                isVerified: false
            )

            // Send verification email automatically
            AuthDebugLogger.logAuthAction("AUTO_SEND_VERIFICATION", email: normalizedEmail)
            try await result.user.sendEmailVerification()
            AuthDebugLogger.logAuthSuccess(
                action: "AUTO_SEND_VERIFICATION",
                uid: result.user.uid,
                email: result.user.email,
                isVerified: false
            )

        } catch {
            AuthDebugLogger.logAuthError(action: "SIGN_UP", error: error)
            errorMessage = friendlyErrorMessage(for: error, action: "sign up")
            throw FirebaseAuthError.signUpFailed(errorMessage ?? error.localizedDescription)
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Sign In

    /// Signs in an existing user with email and password
    /// Includes provider discovery to diagnose 17004 errors
    func signIn(email: String, password: String) async throws {
        #if canImport(FirebaseAuth)
        let normalizedEmail = AuthDebugLogger.normalizeEmail(email)

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        // Validate config first
        let (isValid, configError) = AuthDebugLogger.validateFirebaseConfig()
        guard isValid else {
            let error = configError ?? "Unknown configuration error"
            errorMessage = error
            throw FirebaseAuthError.signInFailed(error)
        }

        AuthDebugLogger.logAuthAction("SIGN_IN", email: normalizedEmail)

        // Provider discovery: Check what methods are available for this email
        // Note: This is deprecated and may return [] when Email Enumeration Protection is enabled
        // We log it for diagnostics but don't rely on it for error handling
        let methods = await fetchSignInMethods(forEmail: normalizedEmail)

        // Only use methods if not empty (Email Enumeration Protection returns [])
        if !methods.isEmpty {
            if !methods.contains("password") {
                // Account exists but not with email/password (e.g., only OAuth)
                errorMessage = "This email is not configured for password sign-in. Methods available: \(methods.joined(separator: ", "))"
                throw FirebaseAuthError.signInFailed(errorMessage!)
            }
        }

        // Now attempt the actual sign-in
        do {
            let result = try await Auth.auth().signIn(withEmail: normalizedEmail, password: password)

            currentUserId = result.user.uid
            userEmail = result.user.email
            isEmailVerified = result.user.isEmailVerified
            isAuthenticated = true

            AuthDebugLogger.logAuthSuccess(
                action: "SIGN_IN",
                uid: result.user.uid,
                email: result.user.email,
                isVerified: result.user.isEmailVerified
            )

        } catch {
            AuthDebugLogger.logAuthError(action: "SIGN_IN", error: error)
            errorMessage = friendlyErrorMessage(for: error, action: "sign in")
            throw FirebaseAuthError.signInFailed(errorMessage ?? error.localizedDescription)
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Sign Out

    /// Signs out the current user
    func signOut() throws {
        #if canImport(FirebaseAuth)
        AuthDebugLogger.logAuthAction("SIGN_OUT", email: userEmail ?? "unknown")

        do {
            try Auth.auth().signOut()

            // Clear ALL state
            currentUserId = nil
            userEmail = nil
            isEmailVerified = false
            isAuthenticated = false
            errorMessage = nil

            AuthDebugLogger.logStateTransition(
                from: "authenticated",
                to: "unauthenticated",
                reason: "User signed out"
            )

        } catch {
            AuthDebugLogger.logAuthError(action: "SIGN_OUT", error: error)
            errorMessage = error.localizedDescription
            throw FirebaseAuthError.signOutFailed(error.localizedDescription)
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Microsoft Sign In (Disabled)

    /// Signs in using Microsoft OAuth via Firebase
    /// NOTE: Currently disabled pending Firebase Console configuration
    func signInWithMicrosoft() async throws {
        #if canImport(FirebaseAuth)
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        AuthDebugLogger.logAuthAction("SIGN_IN_MICROSOFT", email: "oauth")

        // Get the presenting view controller for the OAuth flow
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            throw FirebaseAuthError.microsoftSignInFailed("Could not find view controller to present sign-in")
        }

        do {
            let provider = OAuthProvider(providerID: "microsoft.com")
            provider.customParameters = [
                "prompt": "select_account",
                "tenant": "common"
            ]
            provider.scopes = ["email", "profile", "openid"]

            let uiDelegate = FirebaseAuthUIDelegate(viewController: viewController)

            let authResult = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<AuthDataResult, Error>) in
                provider.getCredentialWith(uiDelegate) { credential, error in
                    if let error = error {
                        continuation.resume(throwing: error)
                        return
                    }

                    guard let credential = credential else {
                        continuation.resume(throwing: FirebaseAuthError.microsoftSignInFailed("No credential returned"))
                        return
                    }

                    Auth.auth().signIn(with: credential) { authResult, signInError in
                        if let signInError = signInError {
                            continuation.resume(throwing: signInError)
                        } else if let authResult = authResult {
                            continuation.resume(returning: authResult)
                        } else {
                            continuation.resume(throwing: FirebaseAuthError.microsoftSignInFailed("Unknown error"))
                        }
                    }
                }
            }

            currentUserId = authResult.user.uid
            userEmail = authResult.user.email
            isEmailVerified = authResult.user.isEmailVerified
            isAuthenticated = true

            AuthDebugLogger.logAuthSuccess(
                action: "SIGN_IN_MICROSOFT",
                uid: authResult.user.uid,
                email: authResult.user.email,
                isVerified: authResult.user.isEmailVerified
            )

        } catch {
            AuthDebugLogger.logAuthError(action: "SIGN_IN_MICROSOFT", error: error)
            errorMessage = error.localizedDescription
            throw FirebaseAuthError.microsoftSignInFailed(error.localizedDescription)
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Password Reset

    /// Sends a password reset email
    func sendPasswordReset(email: String) async throws {
        #if canImport(FirebaseAuth)
        let normalizedEmail = AuthDebugLogger.normalizeEmail(email)

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        AuthDebugLogger.logAuthAction("SEND_PASSWORD_RESET", email: normalizedEmail)

        do {
            try await Auth.auth().sendPasswordReset(withEmail: normalizedEmail)
            AuthDebugLogger.logAuthSuccess(
                action: "SEND_PASSWORD_RESET",
                uid: "n/a",
                email: normalizedEmail,
                isVerified: false
            )
        } catch {
            AuthDebugLogger.logAuthError(action: "SEND_PASSWORD_RESET", error: error)
            errorMessage = error.localizedDescription
            throw FirebaseAuthError.passwordResetFailed(error.localizedDescription)
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Get ID Token

    /// Gets the current user's ID token for authenticated API calls
    func getIdToken() async throws -> String {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.noUser
        }

        do {
            return try await user.getIDToken()
        } catch {
            throw FirebaseAuthError.tokenFailed(error.localizedDescription)
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Delete Account

    /// Permanently deletes the user's account
    /// This will delete the Firebase Auth account and trigger cleanup of user data
    func deleteAccount() async throws {
        #if canImport(FirebaseAuth)
        guard let user = Auth.auth().currentUser else {
            throw FirebaseAuthError.noUser
        }

        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        AuthDebugLogger.logAuthAction("DELETE_ACCOUNT", email: user.email ?? "unknown")

        do {
            // Delete the Firebase Auth user
            // Note: Firestore user data cleanup should be handled via Cloud Functions
            // using a Firebase Auth trigger (onDelete)
            #if DEBUG
            print("🗑️ AUTH: Attempting to delete Firebase Auth user: \(user.uid.prefix(8))...")
            #endif

            try await user.delete()

            #if DEBUG
            print("🗑️ AUTH: Firebase Auth user deleted successfully")
            #endif

            // Clear all local state
            currentUserId = nil
            userEmail = nil
            isEmailVerified = false
            isAuthenticated = false
            errorMessage = nil

            // Also clear AppState - similar to signOut but don't call signOut
            // since the user is already being deleted from Firebase Auth
            await MainActor.run {
                AppState.shared.savedRole = nil
                AppState.shared.pendingRole = nil
            }

            AuthDebugLogger.logStateTransition(
                from: "authenticated",
                to: "deleted",
                reason: "User deleted their account"
            )

        } catch {
            #if DEBUG
            print("🗑️ AUTH: Delete failed with error: \(error)")
            print("🗑️ AUTH: Error code: \((error as NSError).code)")
            #endif
            AuthDebugLogger.logAuthError(action: "DELETE_ACCOUNT", error: error)

            // Check if re-authentication is required
            let nsError = error as NSError
            if nsError.code == 17014 { // ERROR_REQUIRES_RECENT_LOGIN
                errorMessage = "For security, please sign out and sign back in before deleting your account."
                throw FirebaseAuthError.deleteAccountFailed("Please sign out and sign back in, then try again.")
            }

            errorMessage = error.localizedDescription
            throw FirebaseAuthError.deleteAccountFailed(error.localizedDescription)
        }
        #else
        throw FirebaseAuthError.firebaseNotAvailable
        #endif
    }

    // MARK: - Helper Methods

    private func friendlyErrorMessage(for error: Error, action: String) -> String {
        guard let nsError = error as NSError? else {
            return error.localizedDescription
        }

        switch nsError.code {
        case 17004: // ERROR_INVALID_CREDENTIAL
            return "Invalid email or password. Please check your credentials and try again."
        case 17007: // ERROR_EMAIL_ALREADY_IN_USE
            return "An account with this email already exists. Please sign in instead."
        case 17008: // ERROR_INVALID_EMAIL
            return "Please enter a valid email address."
        case 17009: // ERROR_WRONG_PASSWORD (legacy)
            return "Incorrect password. Please try again."
        case 17010: // ERROR_USER_DISABLED
            return "This account has been disabled. Please contact support."
        case 17011: // ERROR_USER_NOT_FOUND (legacy)
            return "No account found with this email. Please sign up first."
        case 17020: // ERROR_NETWORK_REQUEST_FAILED
            return "Network error. Please check your internet connection."
        case 17026: // ERROR_WEAK_PASSWORD
            return "Password is too weak. Please use at least 6 characters."
        default:
            return error.localizedDescription
        }
    }
}

// MARK: - Error Types

enum FirebaseAuthError: LocalizedError {
    case firebaseNotAvailable
    case signUpFailed(String)
    case signInFailed(String)
    case signOutFailed(String)
    case passwordResetFailed(String)
    case microsoftSignInFailed(String)
    case deleteAccountFailed(String)
    case noUser
    case tokenFailed(String)

    var errorDescription: String? {
        switch self {
        case .firebaseNotAvailable:
            return "Firebase SDK not available. Add Firebase packages to your project."
        case .signUpFailed(let message):
            return message
        case .signInFailed(let message):
            return message
        case .signOutFailed(let message):
            return "Sign out failed: \(message)"
        case .passwordResetFailed(let message):
            return "Password reset failed: \(message)"
        case .microsoftSignInFailed(let message):
            return "Microsoft sign in failed: \(message)"
        case .deleteAccountFailed(let message):
            return "Failed to delete account: \(message)"
        case .noUser:
            return "No user is currently signed in."
        case .tokenFailed(let message):
            return "Failed to get ID token: \(message)"
        }
    }
}

// MARK: - Auth UI Delegate

#if canImport(FirebaseAuth)
import UIKit

/// UIDelegate for Firebase OAuth providers to present sign-in UI
class FirebaseAuthUIDelegate: NSObject, AuthUIDelegate {
    private let viewController: UIViewController

    init(viewController: UIViewController) {
        self.viewController = viewController
        super.init()
    }

    func present(_ viewControllerToPresent: UIViewController, animated flag: Bool, completion: (() -> Void)?) {
        viewController.present(viewControllerToPresent, animated: flag, completion: completion)
    }

    func dismiss(animated flag: Bool, completion: (() -> Void)?) {
        viewController.dismiss(animated: flag, completion: completion)
    }
}
#endif
