import Foundation

// MARK: - Bulletin Task Model

struct BulletinTask: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var isCompleted: Bool
    var deadline: Date?
    var completedAt: Date?
    var notes: String?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        title: String,
        isCompleted: Bool = false,
        deadline: Date? = nil,
        completedAt: Date? = nil,
        notes: String? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.isCompleted = isCompleted
        self.deadline = deadline
        self.completedAt = completedAt
        self.notes = notes
        self.createdAt = createdAt
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

// MARK: - Bulletin Store

class BulletinStore: ObservableObject {
    static let shared = BulletinStore()

    @Published var tasks: [BulletinTask] = []

    private let tasksKey = "hallpals_bulletin_tasks"

    private init() {
        loadFromStorage()
        createDefaultTaskIfNeeded()
    }

    // MARK: - Computed Properties

    var pendingTasks: [BulletinTask] {
        tasks.filter { !$0.isCompleted }
            .sorted { ($0.deadline ?? .distantFuture) < ($1.deadline ?? .distantFuture) }
    }

    var completedTasks: [BulletinTask] {
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

    // MARK: - Task Management

    func addTask(_ task: BulletinTask) {
        tasks.append(task)
        saveToStorage()
    }

    func updateTask(_ task: BulletinTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index] = task
            saveToStorage()
        }
    }

    func deleteTask(_ task: BulletinTask) {
        tasks.removeAll { $0.id == task.id }
        saveToStorage()
    }

    func toggleCompletion(_ task: BulletinTask) {
        if let index = tasks.firstIndex(where: { $0.id == task.id }) {
            tasks[index].isCompleted.toggle()
            tasks[index].completedAt = tasks[index].isCompleted ? Date() : nil
            saveToStorage()
        }
    }

    // MARK: - Default Task

    private func createDefaultTaskIfNeeded() {
        // Create the default bulletin board task if no tasks exist
        if tasks.isEmpty {
            let sundayEvening = nextSundayEvening()
            let defaultTask = BulletinTask(
                title: "Complete bulletin board",
                deadline: sundayEvening,
                notes: "Update the bulletin board with this week's content"
            )
            tasks.append(defaultTask)
            saveToStorage()
        }
    }

    /// Calculate next Sunday at 6:00 PM
    private func nextSundayEvening() -> Date {
        let calendar = Calendar.current
        var components = calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: Date())
        components.weekday = 1 // Sunday
        components.hour = 18 // 6:00 PM
        components.minute = 0

        var nextSunday = calendar.date(from: components) ?? Date()

        // If we're past Sunday evening, get next week's Sunday
        if nextSunday <= Date() {
            nextSunday = calendar.date(byAdding: .weekOfYear, value: 1, to: nextSunday) ?? nextSunday
        }

        return nextSunday
    }

    // MARK: - Storage

    private func saveToStorage() {
        if let encoded = try? JSONEncoder().encode(tasks) {
            UserDefaults.standard.set(encoded, forKey: tasksKey)
        }
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: tasksKey),
           let decoded = try? JSONDecoder().decode([BulletinTask].self, from: data) {
            tasks = decoded
        }
    }

    func clearAll() {
        tasks = []
        UserDefaults.standard.removeObject(forKey: tasksKey)
    }
}
