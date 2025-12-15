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
    case needsRoleCode     // User needs to select role + enter code
    case needsAuth         // User selected role, needs to sign in
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
    @Published var pendingCode: String? // Store code for Cloud Function
    @Published var errorMessage: String?

    // MARK: - Persisted Keys (for role only, NOT auth state)

    private enum Keys {
        static let userRole = "hallpals_user_role"
    }

    // MARK: - Role Codes (client-side validation only)

    private let roleCodes: [UserRole: String] = [
        .resident: "DEVRES",
        .ra: "DEVRA"
    ]

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
        } else if pendingRole != nil {
            // User has selected a role, needs to authenticate
            authState = .needsAuth
        } else {
            // User needs to select role and enter code
            authState = .needsRoleCode
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

    // MARK: - Role Code Validation

    func validateCode(_ code: String, for role: UserRole) -> Bool {
        roleCodes[role]?.uppercased() == code.uppercased()
    }

    /// Submit role selection with code
    /// Returns true if code is valid (client-side check only)
    /// Server will do full validation via manifest
    func submitRoleWithCode(_ role: UserRole, code: String) -> Bool {
        errorMessage = nil

        guard validateCode(code, for: role) else {
            errorMessage = "Invalid code. Please try again."
            return false
        }

        pendingRole = role
        pendingCode = code.uppercased().trimmingCharacters(in: .whitespacesAndNewlines)
        authState = .needsAuth

        AuthDebugLogger.logStateTransition(
            from: "needsRoleCode",
            to: "needsAuth",
            reason: "Valid role code submitted for \(role.displayName)"
        )

        return true
    }

    /// Submit resident role directly without access code
    func submitResidentRole() {
        errorMessage = nil
        pendingRole = .resident
        pendingCode = "DEVRES" // Use dev code for backend consistency
        authState = .needsAuth

        AuthDebugLogger.logStateTransition(
            from: "needsRoleCode",
            to: "needsAuth",
            reason: "Resident role selected (no code required)"
        )
    }

    // MARK: - Auth Actions

    func signUp(email: String, password: String) async throws {
        errorMessage = nil

        do {
            try await firebaseAuth.signUp(email: email, password: password)

            // Call Cloud Function to register with hall
            // Server validates code and assigns role via manifest
            if let code = pendingCode {
                let response = try await CloudFunctionsService.shared.joinHallWithCode(code: code)

                #if DEBUG
                print("🔐 AUTH: joinHallWithCode response - role: \(response.role), message: \(response.message)")
                #endif

                // Update saved role based on server response
                if let assignedRole = UserRole.allCases.first(where: { $0.rawValue == response.role }) {
                    savedRole = assignedRole
                }
            }

            pendingRole = nil
            pendingCode = nil

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
            // Server validates code and assigns role via manifest
            if let code = pendingCode {
                let response = try await CloudFunctionsService.shared.joinHallWithCode(code: code)

                #if DEBUG
                print("🔐 AUTH: joinHallWithCode response - role: \(response.role), message: \(response.message)")
                #endif

                // Update saved role based on server response
                if let assignedRole = UserRole.allCases.first(where: { $0.rawValue == response.role }) {
                    savedRole = assignedRole
                }
            }

            pendingRole = nil
            pendingCode = nil

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
            if let code = pendingCode {
                let response = try await CloudFunctionsService.shared.joinHallWithCode(code: code)

                #if DEBUG
                print("🔐 AUTH: joinHallWithCode response - role: \(response.role), message: \(response.message)")
                #endif

                // Update saved role based on server response
                if let assignedRole = UserRole.allCases.first(where: { $0.rawValue == response.role }) {
                    savedRole = assignedRole
                }
            }

            pendingRole = nil
            pendingCode = nil

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

        try firebaseAuth.signOut()

        // Clear role and pending state
        pendingRole = nil
        pendingCode = nil
        savedRole = nil
        errorMessage = nil

        // Force state to needsRoleCode
        authState = .needsRoleCode

        AuthDebugLogger.logStateTransition(
            from: "authenticated",
            to: "needsRoleCode",
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
        pendingCode = nil

        authState = .authenticated

        AuthDebugLogger.logStateTransition(
            from: "needsVerification",
            to: "authenticated",
            reason: "Email verification confirmed via reloadUser()"
        )
    }

    /// Go back from auth screen to role selection
    func goBackToRoleSelection() {
        pendingRole = nil
        pendingCode = nil
        authState = .needsRoleCode

        AuthDebugLogger.logStateTransition(
            from: "needsAuth",
            to: "needsRoleCode",
            reason: "User tapped back button"
        )
    }

    // MARK: - Chat Support Properties

    /// Current user ID for chat operations
    var currentUserId: String? {
        firebaseAuth.currentUserId
    }

    /// Hall ID for chat operations (defaults to hall-001)
    var savedHallId: String? {
        // For now, always return the default hall
        // In future, this could be stored in UserDefaults or fetched from user doc
        "hall-001"
    }
}
