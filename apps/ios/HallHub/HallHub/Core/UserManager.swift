import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Profile Model

struct HallPalsUser: Codable, Equatable {
    let uid: String
    let email: String
    var displayName: String?
    var role: String
    var hallId: String?
    var floor: Int?
    var wing: String?
    var createdAt: Date?
    var updatedAt: Date?
}

// MARK: - User Manager

/// Manages the current user's profile data from Firestore
/// Provides user context (uid, hallId, floor, wing) for other services
@MainActor
final class UserManager: ObservableObject {

    // MARK: - Singleton

    static let shared = UserManager()

    // MARK: - Published State

    @Published private(set) var currentUser: HallPalsUser?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Computed Properties

    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }

    var isAuthenticated: Bool {
        currentUserId != nil
    }

    var hallId: String? {
        currentUser?.hallId
    }

    var floor: Int? {
        currentUser?.floor
    }

    var wing: String? {
        currentUser?.wing
    }

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        setupAuthObserver()
    }

    deinit {
        userListener?.remove()
        userListener = nil
    }

    // MARK: - Auth Observer

    private func setupAuthObserver() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let uid = user?.uid {
                    self?.startListening(uid: uid)
                } else {
                    self?.stopListening()
                    self?.currentUser = nil
                }
            }
        }
    }

    // MARK: - Firestore Listener

    /// Start listening to the current user's profile document
    func startListening(uid: String) {
        stopListening()

        isLoading = true
        error = nil

        #if DEBUG
        print("👤 USER: Starting listener for user \(uid)")
        #endif

        let userRef = db.collection("users").document(uid)

        userListener = userRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            self.isLoading = false

            if let error = error {
                #if DEBUG
                print("👤 USER: Error listening to user profile - \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                #if DEBUG
                print("👤 USER: User document not found for \(uid)")
                #endif
                self.currentUser = nil
                return
            }

            // Parse user data
            let user = HallPalsUser(
                uid: uid,
                email: data["email"] as? String ?? "",
                displayName: data["displayName"] as? String,
                role: data["role"] as? String ?? "resident",
                hallId: data["hallId"] as? String,
                floor: data["floor"] as? Int,
                wing: data["wing"] as? String,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
            )

            self.currentUser = user

            #if DEBUG
            print("👤 USER: Profile loaded - role: \(user.role), hallId: \(user.hallId ?? "none"), floor: \(user.floor ?? -1), wing: \(user.wing ?? "none")")
            #endif
        }
    }

    /// Stop listening to user profile changes
    func stopListening() {
        userListener?.remove()
        userListener = nil
    }

    // MARK: - Manual Fetch (for one-time reads)

    /// Fetch the current user's profile once (non-realtime)
    func fetchCurrentUser() async throws -> HallPalsUser? {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw UserManagerError.notAuthenticated
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let snapshot = try await db.collection("users").document(uid).getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }

        let user = HallPalsUser(
            uid: uid,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String,
            role: data["role"] as? String ?? "resident",
            hallId: data["hallId"] as? String,
            floor: data["floor"] as? Int,
            wing: data["wing"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )

        self.currentUser = user
        return user
    }

    // MARK: - Staff Profile Fetch

    /// Fetch the staff profile for the current user (for RA floor/wing assignment)
    /// Staff profiles are stored at /halls/{hallId}/staff/{uid}
    func fetchStaffProfile() async throws -> StaffProfile? {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw UserManagerError.notAuthenticated
        }

        guard let hallId = currentUser?.hallId ?? "hall-001" as String? else {
            throw UserManagerError.noHallAssigned
        }

        let staffRef = db.collection("halls").document(hallId).collection("staff").document(uid)
        let snapshot = try await staffRef.getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            #if DEBUG
            print("👤 USER: No staff profile found for \(uid) in hall \(hallId)")
            #endif
            return nil
        }

        let profile = StaffProfile(
            uid: uid,
            hallId: hallId,
            floor: data["floor"] as? Int,
            wing: data["wing"] as? String,
            role: data["role"] as? String ?? "ra",
            isActive: data["isActive"] as? Bool ?? true
        )

        #if DEBUG
        print("👤 USER: Staff profile loaded - floor: \(profile.floor ?? -1), wing: \(profile.wing ?? "none")")
        #endif

        return profile
    }
}

// MARK: - Staff Profile Model

struct StaffProfile: Codable, Equatable {
    let uid: String
    let hallId: String
    var floor: Int?
    var wing: String?
    var role: String
    var isActive: Bool
}

// MARK: - Errors

enum UserManagerError: LocalizedError {
    case notAuthenticated
    case noHallAssigned
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .noHallAssigned:
            return "User has no hall assigned"
        case .profileNotFound:
            return "User profile not found"
        }
    }
}
