import Foundation

/// Centralized debug logging utility
/// - All logging is completely stripped from Release builds
/// - Sensitive data (UIDs, emails, room numbers) is automatically masked
/// - Use this instead of direct print() statements
enum DebugLog {

    // MARK: - Public Logging Methods

    /// Log a general message (stripped in Release)
    static func log(_ message: String, category: Category = .general) {
        #if DEBUG
        print("\(category.emoji) \(category.prefix): \(message)")
        #endif
    }

    /// Log with automatic UID masking
    static func log(_ message: String, uid: String?, category: Category = .general) {
        #if DEBUG
        let masked = uid.map { maskUID($0) } ?? "nil"
        print("\(category.emoji) \(category.prefix): \(message) | uid: \(masked)")
        #endif
    }

    /// Log with automatic email masking
    static func log(_ message: String, email: String?, category: Category = .general) {
        #if DEBUG
        let masked = email.map { maskEmail($0) } ?? "nil"
        print("\(category.emoji) \(category.prefix): \(message) | email: \(masked)")
        #endif
    }

    /// Log an error (stripped in Release)
    static func error(_ message: String, error: Error? = nil, category: Category = .general) {
        #if DEBUG
        var output = "❌ \(category.prefix): \(message)"
        if let error = error {
            output += " | \(error.localizedDescription)"
        }
        print(output)
        #endif
    }

    /// Log success (stripped in Release)
    static func success(_ message: String, category: Category = .general) {
        #if DEBUG
        print("✅ \(category.prefix): \(message)")
        #endif
    }

    /// Log a warning (stripped in Release)
    static func warning(_ message: String, category: Category = .general) {
        #if DEBUG
        print("⚠️ \(category.prefix): \(message)")
        #endif
    }

    // MARK: - Categories

    enum Category {
        case general
        case auth
        case user
        case hall
        case chat
        case schedule
        case residents
        case tasks
        case firestore
        case functions
        case living
        case roomCheck
        case bulletin
        case meetings
        case rounds
        case docs
        case resources
        case notifications
        case concern
        case noise

        var emoji: String {
            switch self {
            case .general: return "📌"
            case .auth: return "🔐"
            case .user: return "👤"
            case .hall: return "🏢"
            case .chat: return "💬"
            case .schedule: return "📅"
            case .residents: return "🏠"
            case .tasks: return "📋"
            case .firestore: return "🗄️"
            case .functions: return "☁️"
            case .living: return "🏠"
            case .roomCheck: return "🏠"
            case .bulletin: return "📋"
            case .meetings: return "📅"
            case .rounds: return "📍"
            case .docs: return "📄"
            case .resources: return "📚"
            case .notifications: return "📱"
            case .concern: return "📝"
            case .noise: return "🔊"
            }
        }

        var prefix: String {
            switch self {
            case .general: return "LOG"
            case .auth: return "AUTH"
            case .user: return "USER"
            case .hall: return "HALL"
            case .chat: return "CHAT"
            case .schedule: return "SCHEDULE"
            case .residents: return "RESIDENTS"
            case .tasks: return "TASKS"
            case .firestore: return "FIRESTORE"
            case .functions: return "FUNCTIONS"
            case .living: return "LIVING"
            case .roomCheck: return "ROOMCHECK"
            case .bulletin: return "BULLETIN"
            case .meetings: return "MEETINGS"
            case .rounds: return "ROUNDS"
            case .docs: return "DOCS"
            case .resources: return "RESOURCES"
            case .notifications: return "PUSH"
            case .concern: return "CONCERN"
            case .noise: return "NOISE"
            }
        }
    }

    // MARK: - Masking Utilities

    /// Masks a UID to show only first 8 characters
    static func maskUID(_ uid: String) -> String {
        guard uid.count > 8 else { return "***" }
        return "\(uid.prefix(8))..."
    }

    /// Masks an email to show first 2 chars + domain
    static func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return "***" }
        let localPart = email[..<atIndex]
        let domain = email[atIndex...]
        if localPart.count <= 2 {
            return "**\(domain)"
        }
        return "\(localPart.prefix(2))***\(domain)"
    }

    /// Masks a room number to show only floor indicator
    static func maskRoom(_ room: String) -> String {
        // Extract just the floor number if present (e.g., "IRE-135" -> "1xx")
        let digits = room.filter { $0.isNumber }
        if let first = digits.first {
            return "\(first)xx"
        }
        return "***"
    }

    /// Masks a conversation/document ID
    static func maskDocID(_ docID: String) -> String {
        guard docID.count > 6 else { return "***" }
        return "\(docID.prefix(6))..."
    }
}
