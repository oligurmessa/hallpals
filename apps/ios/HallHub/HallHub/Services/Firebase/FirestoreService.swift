import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Service for Firestore user and hall operations
/// Phase C2: User profile + hall membership creation on login
@MainActor
final class FirestoreService: ObservableObject {

    // MARK: - Singleton

    static let shared = FirestoreService()

    // MARK: - Constants

    private enum Collections {
        static let users = "users"
        static let halls = "halls"
        static let members = "members"
    }

    /// Default development hall ID
    static let devHallId = "hall-001"

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - User Profile

    /// Creates or updates user profile in /users/{uid}
    /// Called after successful authentication
    func createUserProfile(
        uid: String,
        email: String,
        displayName: String?,
        role: UserRole,
        hallId: String = devHallId
    ) async throws {
        #if canImport(FirebaseFirestore)
        isLoading = true
        error = nil

        defer { isLoading = false }

        let userRef = db.collection(Collections.users).document(uid)
        let now = FieldValue.serverTimestamp()

        // Check if user already exists
        let snapshot = try await userRef.getDocument()

        if snapshot.exists {
            // Update only allowed fields
            #if DEBUG
            print("🗄️ FIRESTORE: Updating existing user profile for \(uid)")
            #endif

            try await userRef.updateData([
                "displayName": displayName ?? "",
                "updatedAt": now
            ])
        } else {
            // Create new user document
            #if DEBUG
            print("🗄️ FIRESTORE: Creating new user profile for \(uid)")
            #endif

            let userData: [String: Any] = [
                "email": email.lowercased().trimmingCharacters(in: .whitespacesAndNewlines),
                "displayName": displayName ?? "",
                "role": role.rawValue,
                "hallId": hallId,
                "createdAt": now,
                "updatedAt": now
            ]

            try await userRef.setData(userData)
        }

        #if DEBUG
        print("🗄️ FIRESTORE: User profile saved successfully")
        #endif
        #else
        throw FirestoreError.notConfigured
        #endif
    }

    // MARK: - Hall Membership

    /// Creates hall membership in /halls/{hallId}/members/{uid}
    /// Required by security rules to access hall data
    func createHallMembership(
        uid: String,
        hallId: String = devHallId,
        role: UserRole
    ) async throws {
        #if canImport(FirebaseFirestore)
        isLoading = true
        error = nil

        defer { isLoading = false }

        let memberRef = db.collection(Collections.halls)
            .document(hallId)
            .collection(Collections.members)
            .document(uid)

        // Check if membership already exists
        do {
            let snapshot = try await memberRef.getDocument()

            if snapshot.exists {
                #if DEBUG
                print("🗄️ FIRESTORE: Membership already exists for \(uid) in \(hallId)")
                #endif
                return
            }
        } catch {
            #if DEBUG
            print("🗄️ FIRESTORE: Could not check existing membership - \(error.localizedDescription)")
            #endif
            // Continue to try creating - may fail if hall doesn't exist
        }

        // Create membership
        #if DEBUG
        print("🗄️ FIRESTORE: Creating membership for \(uid) in \(hallId)")
        #endif

        let memberData: [String: Any] = [
            "role": role.rawValue,
            "joinedAt": FieldValue.serverTimestamp(),
            "isActive": true
        ]

        try await memberRef.setData(memberData)

        #if DEBUG
        print("🗄️ FIRESTORE: Membership created successfully")
        #endif
        #else
        throw FirestoreError.notConfigured
        #endif
    }

    // MARK: - Combined Setup

    /// Creates both user profile and hall membership
    /// Called after successful sign-up or first sign-in
    func setupUserAndMembership(
        uid: String,
        email: String,
        displayName: String?,
        role: UserRole,
        hallId: String = devHallId
    ) async throws {
        #if DEBUG
        print("🗄️ FIRESTORE: Setting up user and membership...")
        #endif

        // Create user profile first
        try await createUserProfile(
            uid: uid,
            email: email,
            displayName: displayName,
            role: role,
            hallId: hallId
        )

        // Then create hall membership
        try await createHallMembership(
            uid: uid,
            hallId: hallId,
            role: role
        )

        #if DEBUG
        print("🗄️ FIRESTORE: User setup complete!")
        #endif
    }

    // MARK: - Fetch User Role

    /// Fetches the user's role from /users/{uid}
    /// Returns nil if user doc doesn't exist or role is missing
    func fetchUserRole(uid: String) async throws -> UserRole? {
        #if canImport(FirebaseFirestore)
        let userRef = db.collection(Collections.users).document(uid)

        do {
            let snapshot = try await userRef.getDocument()

            guard snapshot.exists, let data = snapshot.data() else {
                #if DEBUG
                print("🗄️ FIRESTORE: User doc not found for \(uid)")
                #endif
                return nil
            }

            guard let roleString = data["role"] as? String else {
                #if DEBUG
                print("🗄️ FIRESTORE: Role field missing for \(uid)")
                #endif
                return nil
            }

            // Map role string to UserRole enum
            let role: UserRole? = switch roleString {
            case "resident": .resident
            case "ra": .ra
            default: nil
            }

            #if DEBUG
            print("🗄️ FIRESTORE: Fetched role '\(roleString)' for \(uid) -> \(role?.displayName ?? "unknown")")
            #endif

            return role
        } catch {
            #if DEBUG
            print("🗄️ FIRESTORE: Error fetching user role - \(error.localizedDescription)")
            #endif
            throw error
        }
        #else
        return nil
        #endif
    }

    // MARK: - Verification

    /// Verifies that the user can read the hall document (membership check)
    func verifyHallAccess(hallId: String = devHallId) async throws -> Bool {
        #if canImport(FirebaseFirestore)
        let hallRef = db.collection(Collections.halls).document(hallId)

        do {
            let snapshot = try await hallRef.getDocument()
            #if DEBUG
            print("🗄️ FIRESTORE: Hall access verified - exists: \(snapshot.exists)")
            #endif
            return snapshot.exists
        } catch {
            #if DEBUG
            print("🗄️ FIRESTORE: Hall access denied - \(error.localizedDescription)")
            #endif
            return false
        }
        #else
        return false
        #endif
    }
}

// MARK: - Errors

enum FirestoreError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case documentNotFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Firestore is not configured"
        case .notAuthenticated:
            return "User is not authenticated"
        case .documentNotFound:
            return "Document not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
