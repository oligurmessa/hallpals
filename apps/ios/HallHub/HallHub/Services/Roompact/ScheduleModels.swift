import Foundation

// MARK: - Shift Model

struct Shift: Identifiable, Codable, Equatable {
    let id: UUID
    let start: Date
    let end: Date

    init(id: UUID = UUID(), start: Date, end: Date) {
        self.id = id
        self.start = start
        self.end = end
    }

    /// Duration in hours
    var durationHours: Double {
        end.timeIntervalSince(start) / 3600
    }

    /// Check if shift is currently active
    var isActive: Bool {
        let now = Date()
        return now >= start && now <= end
    }

    /// Check if shift is upcoming (within next 24 hours)
    var isUpcoming: Bool {
        let now = Date()
        let twentyFourHoursFromNow = Calendar.current.date(byAdding: .hour, value: 24, to: now)!
        return start > now && start <= twentyFourHoursFromNow
    }

    /// Check if shift is today
    var isToday: Bool {
        Calendar.current.isDateInToday(start)
    }

    /// Check if shift is tomorrow
    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(start)
    }

    /// Formatted start time (e.g., "4:30 PM")
    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: start)
    }

    /// Formatted end time (e.g., "8:00 AM")
    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: end)
    }

    /// Formatted date (e.g., "Mon, Dec 16")
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: start)
    }

    /// Full formatted range (e.g., "Mon, Dec 16 • 4:30 PM - 8:00 AM")
    var formattedRange: String {
        "\(formattedDate) • \(formattedStartTime) - \(formattedEndTime)"
    }
}

// MARK: - Schedule State

enum ScheduleLoadingState {
    case idle
    case authenticating
    case extractingUserId
    case downloadingSchedule
    case parsing
    case complete
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .authenticating: return "Authenticating..."
        case .extractingUserId: return "Detecting user..."
        case .downloadingSchedule: return "Downloading schedule..."
        case .parsing: return "Processing..."
        case .complete: return "Complete"
        case .error(let message): return "Error: \(message)"
        }
    }

    var isLoading: Bool {
        switch self {
        case .authenticating, .extractingUserId, .downloadingSchedule, .parsing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Schedule Storage

class ScheduleStore: ObservableObject {
    static let shared = ScheduleStore()

    @Published var shifts: [Shift] = []
    @Published var lastUpdated: Date?

    private let shiftsKey = "hallpals_shifts"
    private let lastUpdatedKey = "hallpals_shifts_last_updated"

    private init() {
        loadFromStorage()
    }

    // MARK: - Computed Properties

    var activeShift: Shift? {
        shifts.first { $0.isActive }
    }

    var nextShift: Shift? {
        let now = Date()
        return shifts
            .filter { $0.start > now }
            .sorted { $0.start < $1.start }
            .first
    }

    var upcomingShifts: [Shift] {
        let now = Date()
        return shifts
            .filter { $0.start > now }
            .sorted { $0.start < $1.start }
    }

    var thisWeekShifts: [Shift] {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now)!

        return shifts
            .filter { $0.start >= now && $0.start <= endOfWeek }
            .sorted { $0.start < $1.start }
    }

    var isOnDuty: Bool {
        activeShift != nil
    }

    var hasSyncedSchedule: Bool {
        lastUpdated != nil && !shifts.isEmpty
    }

    // MARK: - Storage

    func saveShifts(_ newShifts: [Shift]) {
        shifts = newShifts
        lastUpdated = Date()

        // Persist to UserDefaults
        if let encoded = try? JSONEncoder().encode(newShifts) {
            UserDefaults.standard.set(encoded, forKey: shiftsKey)
        }
        UserDefaults.standard.set(lastUpdated, forKey: lastUpdatedKey)
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: shiftsKey),
           let decoded = try? JSONDecoder().decode([Shift].self, from: data) {
            shifts = decoded
        }

        lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }

    func clearAll() {
        shifts = []
        lastUpdated = nil

        UserDefaults.standard.removeObject(forKey: shiftsKey)
        UserDefaults.standard.removeObject(forKey: lastUpdatedKey)
    }
}

// MARK: - Mock Data

extension Shift {
    static let mockShifts: [Shift] = {
        let calendar = Calendar.current
        var shifts: [Shift] = []

        // Generate shifts for the next 2 weeks
        for dayOffset in [0, 3, 5, 7, 10, 12, 14] {
            let baseDate = calendar.date(byAdding: .day, value: dayOffset, to: Date())!

            // Start at 4:30 PM
            let start = calendar.date(bySettingHour: 16, minute: 30, second: 0, of: baseDate)!

            // End at 8:00 AM next day
            let endDay = calendar.date(byAdding: .day, value: 1, to: baseDate)!
            let end = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: endDay)!

            shifts.append(Shift(start: start, end: end))
        }

        return shifts
    }()
}
