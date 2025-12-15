import Foundation

// MARK: - Roompact Resident Model

struct RoompactResident: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let room: String?
    let building: String?
    let email: String?

    init(id: UUID = UUID(), name: String, room: String? = nil, building: String? = nil, email: String? = nil) {
        self.id = id
        self.name = name
        self.room = room
        self.building = building
        self.email = email
    }

    /// Display name with room if available
    var displayName: String {
        if let room = room, !room.isEmpty {
            return "\(name) - \(room)"
        }
        return name
    }

    /// First name extracted from full name
    var firstName: String {
        name.components(separatedBy: " ").first ?? name
    }

    /// Last name extracted from full name
    var lastName: String {
        let parts = name.components(separatedBy: " ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
    }
}

// MARK: - Resident Loading State

enum ResidentLoadingState {
    case idle
    case downloading
    case parsing
    case complete
    case error(String)

    var description: String {
        switch self {
        case .idle: return "Ready"
        case .downloading: return "Downloading..."
        case .parsing: return "Processing..."
        case .complete: return "Complete"
        case .error(let message): return "Error: \(message)"
        }
    }

    var isLoading: Bool {
        switch self {
        case .downloading, .parsing:
            return true
        default:
            return false
        }
    }
}

// MARK: - Resident Storage

class ResidentStore: ObservableObject {
    static let shared = ResidentStore()

    @Published var residents: [RoompactResident] = []
    @Published var lastUpdated: Date?

    private let residentsKey = "hallpals_residents"
    private let lastUpdatedKey = "hallpals_residents_last_updated"

    private init() {
        loadFromStorage()
    }

    // MARK: - Computed Properties

    var residentCount: Int {
        residents.count
    }

    var hasSyncedResidents: Bool {
        lastUpdated != nil && !residents.isEmpty
    }

    /// Residents sorted alphabetically by last name, then first name
    var sortedResidents: [RoompactResident] {
        residents.sorted { r1, r2 in
            if r1.lastName == r2.lastName {
                return r1.firstName < r2.firstName
            }
            return r1.lastName < r2.lastName
        }
    }

    /// Group residents by first letter of last name
    var groupedByLetter: [String: [RoompactResident]] {
        Dictionary(grouping: sortedResidents) { resident in
            String(resident.lastName.prefix(1)).uppercased()
        }
    }

    /// All unique buildings
    var buildings: [String] {
        let allBuildings = residents.compactMap { $0.building }
        return Array(Set(allBuildings)).sorted()
    }

    /// Filter residents by building
    func residents(in building: String) -> [RoompactResident] {
        residents.filter { $0.building == building }
    }

    /// Search residents by name
    func search(_ query: String) -> [RoompactResident] {
        guard !query.isEmpty else { return sortedResidents }
        let lowercased = query.lowercased()
        return sortedResidents.filter { resident in
            resident.name.lowercased().contains(lowercased) ||
            (resident.room?.lowercased().contains(lowercased) ?? false)
        }
    }

    // MARK: - Storage

    func saveResidents(_ newResidents: [RoompactResident]) {
        residents = newResidents
        lastUpdated = Date()

        // Persist to UserDefaults
        if let encoded = try? JSONEncoder().encode(newResidents) {
            UserDefaults.standard.set(encoded, forKey: residentsKey)
        }
        UserDefaults.standard.set(lastUpdated, forKey: lastUpdatedKey)
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: residentsKey),
           let decoded = try? JSONDecoder().decode([RoompactResident].self, from: data) {
            residents = decoded
        }

        lastUpdated = UserDefaults.standard.object(forKey: lastUpdatedKey) as? Date
    }

    func clearAll() {
        residents = []
        lastUpdated = nil

        UserDefaults.standard.removeObject(forKey: residentsKey)
        UserDefaults.standard.removeObject(forKey: lastUpdatedKey)
    }
}
