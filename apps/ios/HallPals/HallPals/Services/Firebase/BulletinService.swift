import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Firebase service for Bulletin Board functionality
/// Reads bulletin tasks from /halls/{hallId}/bulletin_tasks/{taskId}
/// Schema matches web admin: title, description, assignee, deadline (ISO string), status, priority
@MainActor
final class BulletinService: ObservableObject {

    // MARK: - Singleton

    static let shared = BulletinService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var error: String?
    @Published private(set) var tasks: [BulletinTask] = []

    private var listenerRegistration: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Task Model (matches web schema)
    // Type alias for backwards compatibility with BulletinView
    typealias FirebaseBulletinTask = BulletinTask

    struct BulletinTask: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let assignee: String
        let deadline: Date?
        let status: TaskStatus
        let priority: TaskPriority
        let createdAt: Date
        let completedAt: Date?

        enum TaskStatus: String {
            case pending = "pending"
            case inProgress = "in_progress"
            case completed = "completed"
        }

        enum TaskPriority: String {
            case low = "low"
            case medium = "medium"
            case high = "high"
        }

        var isCompleted: Bool {
            status == .completed
        }

        var isOverdue: Bool {
            guard let deadline = deadline, !isCompleted else { return false }
            return Date() > deadline
        }

        var isDeadlineApproaching: Bool {
            guard let deadline = deadline, !isCompleted else { return false }
            let hoursRemaining = deadline.timeIntervalSince(Date()) / 3600
            return hoursRemaining > 0 && hoursRemaining <= 24
        }

        var deadlineText: String? {
            guard let deadline = deadline else { return nil }

            let formatter = DateFormatter()
            let calendar = Calendar.current

            if calendar.isDateInToday(deadline) {
                formatter.dateFormat = "'Today'"
            } else if calendar.isDateInTomorrow(deadline) {
                formatter.dateFormat = "'Tomorrow'"
            } else if calendar.isDate(deadline, equalTo: Date(), toGranularity: .weekOfYear) {
                formatter.dateFormat = "EEEE"
            } else {
                formatter.dateFormat = "MMM d"
            }

            return formatter.string(from: deadline)
        }
    }

    // MARK: - Listen to Tasks

    func startListening(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListening()
        isLoading = true
        error = nil

        #if DEBUG
        print("📋 BULLETIN: Starting listener for hall \(hallId)")
        #endif

        let query = db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .order(by: "createdAt", descending: true)

        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, err in
            guard let self = self else { return }
            self.isLoading = false

            if let err = err {
                #if DEBUG
                print("📋 BULLETIN: Listener error: \(err.localizedDescription)")
                #endif
                self.error = err.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.tasks = []
                return
            }

            #if DEBUG
            print("📋 BULLETIN: Received \(documents.count) tasks")
            #endif

            self.tasks = documents.compactMap { doc -> BulletinTask? in
                self.parseTask(doc)
            }

            #if DEBUG
            print("📋 BULLETIN: Parsed \(self.tasks.count) tasks successfully")
            #endif
        }
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        if let registration = listenerRegistration as? ListenerRegistration {
            registration.remove()
            listenerRegistration = nil
        }
        #endif
    }

    // MARK: - Update Task Status

    func updateStatus(hallId: String, taskId: String, status: BulletinTask.TaskStatus) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        try await db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .document(taskId)
            .updateData([
                "status": status.rawValue,
                "updatedAt": FieldValue.serverTimestamp()
            ])

        #if DEBUG
        print("📋 BULLETIN: Updated task \(taskId) status to \(status.rawValue)")
        #endif
        #endif
    }

    // MARK: - Computed Properties

    var pendingTasks: [BulletinTask] {
        tasks.filter { !$0.isCompleted }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    var completedTasks: [BulletinTask] {
        tasks.filter { $0.isCompleted }
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

    // MARK: - Create Task

    func createTask(hallId: String, title: String, deadline: Date? = nil) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        var data: [String: Any] = [
            "title": title,
            "description": "",
            "assignee": "",
            "status": "pending",
            "priority": "medium",
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if let deadline = deadline {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            data["deadline"] = formatter.string(from: deadline)
        } else {
            data["deadline"] = ""
        }

        try await db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .addDocument(data: data)

        #if DEBUG
        print("📋 BULLETIN: Created task '\(title)'")
        #endif
        #endif
    }

    // MARK: - Toggle Completion (for BulletinView compatibility)

    func toggleCompletion(hallId: String, taskId: String, isCompleted: Bool) async throws {
        let newStatus: BulletinTask.TaskStatus = isCompleted ? .completed : .pending
        try await updateStatus(hallId: hallId, taskId: taskId, status: newStatus)
    }

    // MARK: - Delete Task

    func deleteTask(hallId: String, taskId: String) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        try await db.collection("halls")
            .document(hallId)
            .collection("bulletin_tasks")
            .document(taskId)
            .delete()

        #if DEBUG
        print("📋 BULLETIN: Deleted task \(taskId)")
        #endif
        #endif
    }

    // MARK: - Helpers

    #if canImport(FirebaseFirestore)
    private func parseTask(_ doc: DocumentSnapshot) -> BulletinTask? {
        guard let data = doc.data() else {
            #if DEBUG
            print("📋 BULLETIN: No data for doc \(doc.documentID)")
            #endif
            return nil
        }

        guard let title = data["title"] as? String else {
            #if DEBUG
            print("📋 BULLETIN: Missing title for doc \(doc.documentID)")
            #endif
            return nil
        }

        // Parse deadline - could be ISO string from web or Timestamp
        var deadline: Date? = nil
        if let deadlineStr = data["deadline"] as? String, !deadlineStr.isEmpty {
            // ISO date string from web (YYYY-MM-DD)
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            deadline = formatter.date(from: deadlineStr)
        } else if let timestamp = data["deadline"] as? Timestamp {
            deadline = timestamp.dateValue()
        }

        // Parse status
        let statusStr = data["status"] as? String ?? "pending"
        let status = BulletinTask.TaskStatus(rawValue: statusStr) ?? .pending

        // Parse priority
        let priorityStr = data["priority"] as? String ?? "medium"
        let priority = BulletinTask.TaskPriority(rawValue: priorityStr) ?? .medium

        // Parse createdAt
        var createdAt = Date()
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        }

        // Parse completedAt (may not exist)
        var completedAt: Date? = nil
        if let timestamp = data["completedAt"] as? Timestamp {
            completedAt = timestamp.dateValue()
        }

        return BulletinTask(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? "",
            assignee: data["assignee"] as? String ?? "",
            deadline: deadline,
            status: status,
            priority: priority,
            createdAt: createdAt,
            completedAt: completedAt
        )
    }
    #endif
}
