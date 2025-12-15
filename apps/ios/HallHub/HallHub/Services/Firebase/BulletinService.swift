import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Firebase service for Bulletin Board functionality
/// Syncs bulletin tasks to /halls/{hallId}/bulletin_tasks/{taskId}
@MainActor
final class BulletinService: ObservableObject {

    // MARK: - Singleton

    static let shared = BulletinService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var error: String?
    @Published private(set) var tasks: [FirebaseBulletinTask] = []

    private var listenerRegistration: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Firebase Models

    struct FirebaseBulletinTask: Identifiable, Equatable {
        let id: String
        let title: String
        let notes: String?
        let deadline: Date?
        let isCompleted: Bool
        let completedAt: Date?
        let completedBy: String?
        let createdBy: String
        let createdAt: Date
        let updatedAt: Date

        /// Check if task is overdue
        var isOverdue: Bool {
            guard let deadline = deadline, !isCompleted else { return false }
            return Date() > deadline
        }

        /// Check if deadline is approaching (within 24 hours)
        var isDeadlineApproaching: Bool {
            guard let deadline = deadline, !isCompleted else { return false }
            let hoursRemaining = deadline.timeIntervalSince(Date()) / 3600
            return hoursRemaining > 0 && hoursRemaining <= 24
        }

        /// Formatted deadline string
        var deadlineText: String? {
            guard let deadline = deadline else { return nil }

            let formatter = DateFormatter()
            let calendar = Calendar.current

            if calendar.isDateInToday(deadline) {
                formatter.dateFormat = "'Today at' h:mm a"
            } else if calendar.isDateInTomorrow(deadline) {
                formatter.dateFormat = "'Tomorrow at' h:mm a"
            } else if calendar.isDate(deadline, equalTo: Date(), toGranularity: .weekOfYear) {
                formatter.dateFormat = "EEEE 'at' h:mm a"
            } else {
                formatter.dateFormat = "MMM d 'at' h:mm a"
            }

            return formatter.string(from: deadline)
        }
    }

    // MARK: - Listen to Tasks

    /// Start listening to bulletin tasks for the current hall
    func startListening(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListening()

        #if DEBUG
        print("📋 BULLETIN: Starting listener for hall \(hallId)")
        #endif

        // Order by: incomplete first (ordered by deadline), then completed (ordered by completedAt DESC)
        let query = db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .order(by: "isCompleted", descending: false)
            .order(by: "deadline", descending: false)

        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("📋 BULLETIN: Listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.tasks = []
                return
            }

            #if DEBUG
            print("📋 BULLETIN: Received \(documents.count) tasks")
            #endif

            self.tasks = documents.compactMap { doc -> FirebaseBulletinTask? in
                self.parseTask(doc)
            }
        }
        #endif
    }

    /// Stop listening to tasks
    func stopListening() {
        #if canImport(FirebaseFirestore)
        if let registration = listenerRegistration as? ListenerRegistration {
            registration.remove()
            listenerRegistration = nil
        }
        #endif
    }

    // MARK: - Create Task

    /// Create a new bulletin task
    func createTask(
        hallId: String,
        title: String,
        notes: String? = nil,
        deadline: Date? = nil
    ) async throws -> String {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw BulletinError.notAuthenticated
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let taskRef = db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .document()

        var data: [String: Any] = [
            "title": title,
            "isCompleted": false,
            "completedAt": NSNull(),
            "completedBy": NSNull(),
            "createdBy": uid,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let notes = notes, !notes.isEmpty {
            data["notes"] = notes
        } else {
            data["notes"] = NSNull()
        }

        if let deadline = deadline {
            data["deadline"] = Timestamp(date: deadline)
        } else {
            data["deadline"] = NSNull()
        }

        try await taskRef.setData(data)

        #if DEBUG
        print("📋 BULLETIN: Created task \(taskRef.documentID)")
        #endif

        return taskRef.documentID
        #else
        throw BulletinError.notConfigured
        #endif
    }

    // MARK: - Update Task

    /// Update task title and deadline
    func updateTask(
        hallId: String,
        taskId: String,
        title: String,
        notes: String? = nil,
        deadline: Date? = nil
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let taskRef = db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .document(taskId)

        var updateData: [String: Any] = [
            "title": title,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let notes = notes, !notes.isEmpty {
            updateData["notes"] = notes
        } else {
            updateData["notes"] = NSNull()
        }

        if let deadline = deadline {
            updateData["deadline"] = Timestamp(date: deadline)
        } else {
            updateData["deadline"] = NSNull()
        }

        try await taskRef.updateData(updateData)

        #if DEBUG
        print("📋 BULLETIN: Updated task \(taskId)")
        #endif
        #else
        throw BulletinError.notConfigured
        #endif
    }

    /// Toggle task completion status
    func toggleCompletion(
        hallId: String,
        taskId: String,
        isCompleted: Bool
    ) async throws {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw BulletinError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        let taskRef = db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .document(taskId)

        var updateData: [String: Any] = [
            "isCompleted": isCompleted,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if isCompleted {
            updateData["completedAt"] = FieldValue.serverTimestamp()
            updateData["completedBy"] = uid
        } else {
            updateData["completedAt"] = NSNull()
            updateData["completedBy"] = NSNull()
        }

        try await taskRef.updateData(updateData)

        #if DEBUG
        print("📋 BULLETIN: Toggled task \(taskId) to \(isCompleted)")
        #endif
        #else
        throw BulletinError.notConfigured
        #endif
    }

    /// Delete a task
    func deleteTask(
        hallId: String,
        taskId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isLoading = true
        defer { isLoading = false }

        try await db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .document(taskId)
            .delete()

        #if DEBUG
        print("📋 BULLETIN: Deleted task \(taskId)")
        #endif
        #else
        throw BulletinError.notConfigured
        #endif
    }

    // MARK: - Computed Properties

    var pendingTasks: [FirebaseBulletinTask] {
        tasks.filter { !$0.isCompleted }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    var completedTasks: [FirebaseBulletinTask] {
        tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var pendingCount: Int {
        pendingTasks.count
    }

    var hasOverdueTasks: Bool {
        tasks.contains { $0.isOverdue }
    }

    /// Status text for display in DutyView
    var statusText: String {
        let pending = pendingCount
        if pending == 0 {
            return "All complete"
        } else if hasOverdueTasks {
            return "\(pending) pending (overdue)"
        } else {
            return "\(pending) pending"
        }
    }

    // MARK: - Helpers

    #if canImport(FirebaseFirestore)
    private func parseTask(_ doc: DocumentSnapshot) -> FirebaseBulletinTask? {
        guard let data = doc.data() else { return nil }

        guard let title = data["title"] as? String,
              let createdBy = data["createdBy"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return FirebaseBulletinTask(
            id: doc.documentID,
            title: title,
            notes: data["notes"] as? String,
            deadline: (data["deadline"] as? Timestamp)?.dateValue(),
            isCompleted: data["isCompleted"] as? Bool ?? false,
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            completedBy: data["completedBy"] as? String,
            createdBy: createdBy,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    #endif
}

// MARK: - Errors

enum BulletinError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case notFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Bulletin service is not configured"
        case .notAuthenticated:
            return "User is not authenticated"
        case .notFound:
            return "Task not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
