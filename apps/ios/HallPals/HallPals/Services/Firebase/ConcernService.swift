import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Simple concern/report service for residents to report issues to the on-duty RA
/// Collection: /halls/{hallId}/concerns/{concernId}
@MainActor
final class ConcernService: ObservableObject {

    // MARK: - Singleton

    static let shared = ConcernService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var isSubmitting = false
    @Published private(set) var error: String?
    @Published private(set) var concerns: [Concern] = []

    private var listenerRegistration: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    #if canImport(FirebaseFunctions)
    private lazy var functions = Functions.functions()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Concern Model

    struct Concern: Identifiable, Equatable {
        let id: String
        let category: ConcernCategory
        let message: String
        let residentUid: String?  // Optional for anonymous concerns
        let residentName: String
        let residentRoom: String?
        let onDutyRAUid: String?  // Optional if no RA on duty
        let onDutyRAName: String?  // Optional if no RA on duty
        let status: ConcernStatus
        let createdAt: Date
        let resolvedAt: Date?
        let resolvedBy: String?
        let raNote: String?
        let isAnonymous: Bool

        var timeAgo: String {
            let interval = Date().timeIntervalSince(createdAt)
            if interval < 60 {
                return "Just now"
            } else if interval < 3600 {
                let mins = Int(interval / 60)
                return "\(mins)m ago"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours)h ago"
            } else {
                let days = Int(interval / 86400)
                return "\(days)d ago"
            }
        }
    }

    enum ConcernCategory: String, CaseIterable, Codable {
        case noise = "noise"
        case maintenance = "maintenance"
        case safety = "safety"
        case roommate = "roommate"
        case other = "other"

        var displayName: String {
            switch self {
            case .noise: return "Noise Complaint"
            case .maintenance: return "Maintenance Issue"
            case .safety: return "Safety Concern"
            case .roommate: return "Roommate Issue"
            case .other: return "Other"
            }
        }

        var icon: String {
            switch self {
            case .noise: return "speaker.wave.3"
            case .maintenance: return "wrench.and.screwdriver"
            case .safety: return "exclamationmark.shield"
            case .roommate: return "person.2"
            case .other: return "ellipsis.circle"
            }
        }
    }

    enum ConcernStatus: String, Codable {
        case pending = "pending"
        case inProgress = "in_progress"
        case resolved = "resolved"

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .resolved: return "Resolved"
            }
        }

        var color: String {
            switch self {
            case .pending: return "orange"
            case .inProgress: return "blue"
            case .resolved: return "green"
            }
        }
    }

    // MARK: - Submit Concern (Resident) - via Cloud Function

    /// Submit a concern via Cloud Function, which sends push notification to RA
    /// - Parameters:
    ///   - hallId: The hall ID
    ///   - category: Category of concern (noise, maintenance, safety, roommate, other)
    ///   - message: Description of the concern
    ///   - location: Optional location information
    ///   - isAnonymous: Whether to submit anonymously
    func submitConcern(
        hallId: String,
        category: ConcernCategory,
        message: String,
        location: String? = nil,
        isAnonymous: Bool = false
    ) async throws {
        #if canImport(FirebaseFunctions)
        isSubmitting = true
        error = nil

        defer { isSubmitting = false }

        var requestData: [String: Any] = [
            "hallId": hallId,
            "category": category.rawValue,
            "message": message,
            "isAnonymous": isAnonymous
        ]

        if let location = location, !location.isEmpty {
            requestData["location"] = location
        }

        #if DEBUG
        print("📝 CONCERN: Submitting via Cloud Function - category: \(category.rawValue), anonymous: \(isAnonymous)")
        #endif

        do {
            let result = try await functions.httpsCallable("submitConcern").call(requestData)

            if let response = result.data as? [String: Any],
               let success = response["success"] as? Bool,
               success {
                #if DEBUG
                let concernId = response["concernId"] as? String ?? "unknown"
                print("📝 CONCERN: Submitted successfully - ID: \(concernId)")
                #endif
            } else {
                throw NSError(domain: "ConcernService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to submit concern"])
            }
        } catch {
            self.error = error.localizedDescription
            #if DEBUG
            print("📝 CONCERN: Submit failed - \(error.localizedDescription)")
            #endif
            throw error
        }
        #else
        throw NSError(domain: "ConcernService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Firebase Functions not available"])
        #endif
    }

    /// Legacy submit method for backward compatibility (calls new method internally)
    func submitConcern(
        hallId: String,
        category: ConcernCategory,
        message: String,
        residentName: String,
        residentRoom: String?,
        onDutyRAUid: String,
        onDutyRAName: String
    ) async throws {
        // Call the new Cloud Function-based method
        // The function will find the on-duty RA automatically
        try await submitConcern(
            hallId: hallId,
            category: category,
            message: message,
            location: nil,
            isAnonymous: false
        )
    }

    // MARK: - Listen to Concerns (RA)

    #if canImport(FirebaseFirestore)
    func startListening(hallId: String) {
        stopListening()
        isLoading = true

        let query = db.collection("halls")
            .document(hallId)
            .collection("concerns")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)

        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                self.error = error.localizedDescription
                #if DEBUG
                print("📝 CONCERN: Listen error - \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = snapshot?.documents else {
                self.concerns = []
                return
            }

            self.concerns = documents.compactMap { doc -> Concern? in
                let data = doc.data()
                guard let categoryStr = data["category"] as? String,
                      let category = ConcernCategory(rawValue: categoryStr),
                      let message = data["message"] as? String,
                      let residentName = data["residentName"] as? String,
                      let statusStr = data["status"] as? String,
                      let status = ConcernStatus(rawValue: statusStr),
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                else { return nil }

                return Concern(
                    id: doc.documentID,
                    category: category,
                    message: message,
                    residentUid: data["residentUid"] as? String,
                    residentName: residentName,
                    residentRoom: data["residentRoom"] as? String,
                    onDutyRAUid: data["onDutyRAUid"] as? String,
                    onDutyRAName: data["onDutyRAName"] as? String,
                    status: status,
                    createdAt: createdAt,
                    resolvedAt: (data["resolvedAt"] as? Timestamp)?.dateValue(),
                    resolvedBy: data["resolvedBy"] as? String,
                    raNote: data["raNote"] as? String,
                    isAnonymous: data["isAnonymous"] as? Bool ?? false
                )
            }

            #if DEBUG
            print("📝 CONCERN: Loaded \(self.concerns.count) concerns")
            #endif
        }
    }

    func stopListening() {
        if let listener = listenerRegistration as? ListenerRegistration {
            listener.remove()
        }
        listenerRegistration = nil
    }
    #endif

    // MARK: - Update Concern Status (RA)

    #if canImport(FirebaseFirestore)
    func updateStatus(hallId: String, concernId: String, status: ConcernStatus, note: String? = nil) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "ConcernService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var updateData: [String: Any] = [
            "status": status.rawValue
        ]

        if status == .resolved {
            updateData["resolvedAt"] = FieldValue.serverTimestamp()
            updateData["resolvedBy"] = uid
        }

        if let note = note, !note.isEmpty {
            updateData["raNote"] = note
        }

        try await db.collection("halls")
            .document(hallId)
            .collection("concerns")
            .document(concernId)
            .updateData(updateData)

        #if DEBUG
        print("📝 CONCERN: Updated status to \(status.rawValue) for \(concernId)")
        #endif
    }
    #endif

    // MARK: - Get Pending Concerns Count

    var pendingCount: Int {
        concerns.filter { $0.status == .pending }.count
    }

    var activeConcerns: [Concern] {
        concerns.filter { $0.status != .resolved }
    }
}
