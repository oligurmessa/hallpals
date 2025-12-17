import Foundation

// MARK: - Resident Model

struct Resident: Identifiable, Equatable {
    let id: String
    let name: String
    let room: String
    let email: String
    let phone: String
    var moveOutStatus: MoveOutStatus
    var moveOutDate: String?
    let rowIndex: Int

    var initials: String {
        let components = name.split(separator: " ")
        if components.count >= 2 {
            return String(components[0].prefix(1) + components[1].prefix(1))
        }
        return String(name.prefix(2)).uppercased()
    }
}

// MARK: - Move Out Status

enum MoveOutStatus: String, CaseIterable {
    case none = ""
    case requested = "Requested"
    case approved = "Approved"
    case scheduled = "Scheduled"
    case completed = "Completed"
    case cancelled = "Cancelled"

    var displayName: String {
        switch self {
        case .none: return "Active"
        case .requested: return "Requested"
        case .approved: return "Approved"
        case .scheduled: return "Scheduled"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        }
    }

    var color: String {
        switch self {
        case .none: return "green"
        case .requested: return "orange"
        case .approved: return "blue"
        case .scheduled: return "purple"
        case .completed: return "gray"
        case .cancelled: return "red"
        }
    }
}

// MARK: - Move Out Request

struct MoveOutRequest {
    let residentName: String
    let room: String
    let requestedDate: String
    let reason: String
    var status: MoveOutRequestStatus
    var notes: String?

    init(resident: Resident, date: String, reason: String, notes: String? = nil) {
        self.residentName = resident.name
        self.room = resident.room
        self.requestedDate = date
        self.reason = reason
        self.status = .pending
        self.notes = notes
    }
}

enum MoveOutRequestStatus: String {
    case pending = "Pending"
    case approved = "Approved"
    case denied = "Denied"
}

// MARK: - Mock Data for Testing

extension Resident {
    static let mockResidents: [Resident] = [
        Resident(id: "1", name: "John Smith", room: "201A", email: "jsmith@school.edu", phone: "555-0101", moveOutStatus: .none, moveOutDate: nil, rowIndex: 0),
        Resident(id: "2", name: "Emma Johnson", room: "202B", email: "ejohnson@school.edu", phone: "555-0102", moveOutStatus: .requested, moveOutDate: "2024-12-20", rowIndex: 1),
        Resident(id: "3", name: "Michael Brown", room: "203A", email: "mbrown@school.edu", phone: "555-0103", moveOutStatus: .none, moveOutDate: nil, rowIndex: 2),
        Resident(id: "4", name: "Sarah Davis", room: "204B", email: "sdavis@school.edu", phone: "555-0104", moveOutStatus: .scheduled, moveOutDate: "2024-12-15", rowIndex: 3),
        Resident(id: "5", name: "James Wilson", room: "205A", email: "jwilson@school.edu", phone: "555-0105", moveOutStatus: .none, moveOutDate: nil, rowIndex: 4),
        Resident(id: "6", name: "Ashley Martinez", room: "206B", email: "amartinez@school.edu", phone: "555-0106", moveOutStatus: .approved, moveOutDate: "2024-12-18", rowIndex: 5),
    ]
}
