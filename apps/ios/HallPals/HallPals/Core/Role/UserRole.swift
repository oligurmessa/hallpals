import Foundation

enum UserRole: String, CaseIterable, Identifiable {
    case ra = "Resident Assistant"
    case resident = "Resident"

    var id: String { rawValue }

    var displayName: String { rawValue }

    var shortName: String {
        switch self {
        case .ra: return "RA"
        case .resident: return "Resident"
        }
    }

    var icon: String {
        switch self {
        case .ra: return "person.badge.key.fill"
        case .resident: return "person.fill"
        }
    }

    var description: String {
        switch self {
        case .ra:
            return "Access to rounds, events, SLED protocols, and AI assistant"
        case .resident:
            return "View events, resources, and connect with your RA"
        }
    }
}
