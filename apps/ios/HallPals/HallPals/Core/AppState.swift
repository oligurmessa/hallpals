import SwiftUI
import Combine

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Navigation states for the app's auth flow
enum AppAuthState: Equatable {
    case loading           // Initial state while checking auth
    case needsAuth         // User needs to sign in (landing page)
    case needsVerification // User signed in but needs email verification
    case authenticated     // User is signed in and verified
}

/// Central coordinator for app auth state and navigation
/// Source of truth: Firebase currentUser + isEmailVerified
/// UserDefaults only stores role preference, NOT auth state
@MainActor
final class AppState: ObservableObject {

    // MARK: - Singleton

    static let shared = AppState()

    // MARK: - Published State

    @Published private(set) var authState: AppAuthState = .loading
    @Published var pendingRole: UserRole?
    @Published var errorMessage: String?

    // MARK: - Persisted Keys (for role only, NOT auth state)

    private enum Keys {
        static let userRole = "hallpals_user_role"
    }

    // MARK: - Dependencies

    private let firebaseAuth: FirebaseAuthManager
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init(firebaseAuth: FirebaseAuthManager = .shared) {
        self.firebaseAuth = firebaseAuth
        setupAuthObserver()
    }

    // MARK: - Auth State Observer

    private func setupAuthObserver() {
        // Observe Firebase auth state changes
        // Source of truth is ALWAYS Firebase, not UserDefaults
        firebaseAuth.$isAuthenticated
            .combineLatest(firebaseAuth.$isEmailVerified)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] isAuthenticated, isVerified in
                self?.evaluateState(isAuthenticated: isAuthenticated, isVerified: isVerified)
            }
            .store(in: &cancellables)
    }

    /// Evaluates and sets the correct auth state based on Firebase state
    /// This is the ONLY place authState should be set (except markEmailVerified)
    private func evaluateState(isAuthenticated: Bool, isVerified: Bool) {
        let previousState = authState

        if isAuthenticated {
            if isVerified {
                // Fully authenticated and verified
                authState = .authenticated
            } else {
                // Authenticated but needs email verification
                authState = .needsVerification
            }
        } else {
            // User needs to sign in - show landing page
            authState = .needsAuth
        }

        // Log state transitions
        if previousState != authState {
            AuthDebugLogger.logStateTransition(
                from: String(describing: previousState),
                to: String(describing: authState),
                reason: "evaluateState(isAuthenticated: \(isAuthenticated), isVerified: \(isVerified))"
            )
        }
    }

    // MARK: - Persisted Role (NOT auth state)

    /// The user's selected role - stored in UserDefaults for convenience
    /// This is NOT used to determine auth state
    var savedRole: UserRole? {
        get {
            guard let rawValue = UserDefaults.standard.string(forKey: Keys.userRole) else {
                return nil
            }
            return UserRole.allCases.first { $0.rawValue == rawValue }
        }
        set {
            if let role = newValue {
                UserDefaults.standard.set(role.rawValue, forKey: Keys.userRole)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.userRole)
            }
        }
    }

    // MARK: - Auth Actions

    func signUp(email: String, password: String, displayName: String? = nil) async throws {
        errorMessage = nil

        do {
            try await firebaseAuth.signUp(email: email, password: password, displayName: displayName)

            // Call Cloud Function to register with hall
            // V2: Server discovers hall and role via roster lookup
            let response = try await CloudFunctionsService.shared.joinHall()

            #if DEBUG
            print("🔐 AUTH: joinHall response - role: \(response.role), hallId: \(response.hallId), message: \(response.message)")
            #endif

            // Update saved role based on server response (from roster)
            if let assignedRole = UserRole.allCases.first(where: { $0.rawValue == response.role }) {
                savedRole = assignedRole
            }

            pendingRole = nil

            // State will be set to .needsVerification by the observer
            // because new users are never verified

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signIn(email: String, password: String) async throws {
        errorMessage = nil

        do {
            try await firebaseAuth.signIn(email: email, password: password)

            // Call Cloud Function to register/update hall membership
            // V2: Server discovers hall and role via roster lookup
            let response = try await CloudFunctionsService.shared.joinHall()

            #if DEBUG
            print("🔐 AUTH: joinHall response - role: \(response.role), hallId: \(response.hallId), message: \(response.message)")
            #endif

            // Update saved role based on server response (from roster)
            if let assignedRole = UserRole.allCases.first(where: { $0.rawValue == response.role }) {
                savedRole = assignedRole
            }

            pendingRole = nil

            // State will be set by the observer based on isEmailVerified

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func signInWithMicrosoft() async throws {
        errorMessage = nil

        do {
            try await firebaseAuth.signInWithMicrosoft()

            // Call Cloud Function to register/update hall membership
            // V2: Server discovers hall and role via roster lookup
            let response = try await CloudFunctionsService.shared.joinHall()

            #if DEBUG
            print("🔐 AUTH: joinHall response - role: \(response.role), hallId: \(response.hallId), message: \(response.message)")
            #endif

            // Update saved role based on server response (from roster)
            if let assignedRole = UserRole.allCases.first(where: { $0.rawValue == response.role }) {
                savedRole = assignedRole
            }

            pendingRole = nil

        } catch {
            errorMessage = error.localizedDescription
            throw error
        }
    }

    func sendPasswordReset(email: String) async throws {
        errorMessage = nil
        try await firebaseAuth.sendPasswordReset(email: email)
    }

    func signOut() throws {
        let previousRole = savedRole

        // Remove FCM token from Firestore before signing out
        PushNotificationService.shared.removeTokenFromFirestore()

        try firebaseAuth.signOut()

        // Clear role and pending state
        pendingRole = nil
        savedRole = nil
        errorMessage = nil

        // Clear all cached data in UserManager (hall, RA, residents, etc.)
        UserManager.shared.stopListening()

        // Force state to needsAuth (landing page)
        authState = .needsAuth

        AuthDebugLogger.logStateTransition(
            from: "authenticated",
            to: "needsAuth",
            reason: "User signed out (previous role: \(previousRole?.displayName ?? "none"))"
        )
    }

    // MARK: - Email Verification

    /// Manually mark email as verified and transition to authenticated state
    /// Called when EmailVerificationView confirms verification via reloadUser()
    /// IMPORTANT: Firebase auth listener does NOT fire on email verification,
    /// so we must manually advance state after confirming verification
    func markEmailVerified() {
        errorMessage = nil

        // Save role if still pending
        if let role = pendingRole {
            savedRole = role
        }
        pendingRole = nil

        authState = .authenticated

        AuthDebugLogger.logStateTransition(
            from: "needsVerification",
            to: "authenticated",
            reason: "Email verification confirmed via reloadUser()"
        )
    }

    // MARK: - Chat Support Properties

    /// Current user ID for chat operations
    var currentUserId: String? {
        firebaseAuth.currentUserId
    }

    /// Hall ID for chat operations - fetched from UserManager
    var savedHallId: String? {
        // Get hall ID from UserManager (fetched from user document)
        let hallId = UserManager.shared.currentUser?.hallId
        // Return nil if empty string (unassigned)
        return hallId?.isEmpty == true ? nil : hallId
    }
}
