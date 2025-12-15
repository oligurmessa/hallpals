import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - RA Task Model

struct RATask: Identifiable, Equatable {
    let id: String
    let title: String
    let description: String?
    let deadline: Date?
    let priority: TaskPriority
    let isCompleted: Bool
    let completedAt: Date?
    let completedBy: String?
    let assignedTo: [String] // Array of RA user IDs
    let assignedBy: String // Staff/Lead who assigned it
    let assignedByName: String?
    let createdAt: Date
    let updatedAt: Date

    enum TaskPriority: String, Codable, CaseIterable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "orange"
            case .high: return "red"
            }
        }

        var displayName: String {
            rawValue.capitalized
        }
    }

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

// MARK: - RA Task Service

/// Firebase service for RA Tasks
/// Fetches tasks assigned to the current RA from /halls/{hallId}/ra_tasks
@MainActor
final class RATaskService: ObservableObject {

    // MARK: - Singleton

    static let shared = RATaskService()

    // MARK: - Published State

    @Published private(set) var tasks: [RATask] = []
    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var error: String?

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: - Init

    private init() {}

    deinit {
        listener?.remove()
        listener = nil
    }

    // MARK: - Computed Properties

    var pendingTasks: [RATask] {
        tasks.filter { !$0.isCompleted }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    var completedTasks: [RATask] {
        tasks.filter { $0.isCompleted }
            .sorted { ($0.completedAt ?? $0.createdAt) > ($1.completedAt ?? $1.createdAt) }
    }

    var pendingCount: Int {
        pendingTasks.count
    }

    var hasOverdueTasks: Bool {
        tasks.contains { $0.isOverdue }
    }

    var highPriorityCount: Int {
        pendingTasks.filter { $0.priority == .high }.count
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

    // MARK: - Listen to Tasks

    /// Start listening to tasks assigned to the current RA
    func startListening(hallId: String = "hall-001") {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.error = "Not authenticated"
            return
        }

        stopListening()
        isLoading = true
        error = nil

        #if DEBUG
        print("📋 TASKS: Starting listener for RA \(uid) in hall \(hallId)")
        #endif

        // Query tasks where current user is in assignedTo array
        let query = db.collection("halls")
            .document(hallId)
            .collection("ra_tasks")
            .whereField("assignedTo", arrayContains: uid)
            .order(by: "deadline", descending: false)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            self.isLoading = false

            if let error = error {
                #if DEBUG
                print("📋 TASKS: Listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.tasks = []
                return
            }

            #if DEBUG
            print("📋 TASKS: Received \(documents.count) tasks")
            #endif

            self.tasks = documents.compactMap { doc -> RATask? in
                self.parseTask(doc)
            }
        }
    }

    /// Stop listening to tasks
    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Toggle Completion

    /// Toggle task completion status
    func toggleCompletion(taskId: String, isCompleted: Bool, hallId: String = "hall-001") async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw RATaskError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        let taskRef = db.collection("halls")
            .document(hallId)
            .collection("ra_tasks")
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
        print("📋 TASKS: Toggled task \(taskId) to \(isCompleted)")
        #endif
    }

    // MARK: - Helpers

    private func parseTask(_ doc: DocumentSnapshot) -> RATask? {
        guard let data = doc.data() else { return nil }

        guard let title = data["title"] as? String,
              let assignedBy = data["assignedBy"] as? String,
              let assignedTo = data["assignedTo"] as? [String],
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            #if DEBUG
            print("📋 TASKS: Failed to parse task \(doc.documentID) - missing required fields")
            #endif
            return nil
        }

        let priorityString = data["priority"] as? String ?? "medium"
        let priority = RATask.TaskPriority(rawValue: priorityString) ?? .medium

        return RATask(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String,
            deadline: (data["deadline"] as? Timestamp)?.dateValue(),
            priority: priority,
            isCompleted: data["isCompleted"] as? Bool ?? false,
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue(),
            completedBy: data["completedBy"] as? String,
            assignedTo: assignedTo,
            assignedBy: assignedBy,
            assignedByName: data["assignedByName"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Errors

enum RATaskError: LocalizedError {
    case notAuthenticated
    case notFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .notFound:
            return "Task not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
