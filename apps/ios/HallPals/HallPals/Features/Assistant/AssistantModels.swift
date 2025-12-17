import Foundation

// MARK: - Assistant Sender

enum AssistantSender: String, Codable {
    case user
    case assistant
}

// MARK: - Assistant Message

struct AssistantMessage: Identifiable, Equatable {
    let id: UUID
    let sender: AssistantSender
    let text: String
    let timestamp: Date

    init(id: UUID = UUID(), sender: AssistantSender, text: String, timestamp: Date = Date()) {
        self.id = id
        self.sender = sender
        self.text = text
        self.timestamp = timestamp
    }
}

// MARK: - Suggested Prompt

struct SuggestedPrompt: Identifiable {
    let id: UUID
    let text: String

    init(id: UUID = UUID(), text: String) {
        self.id = id
        self.text = text
    }
}

// MARK: - FAQ Item (for Resident view)

struct FAQItem: Identifiable {
    let id: UUID
    let question: String
    let icon: String
    let bulletPoints: [String]

    init(id: UUID = UUID(), question: String, icon: String, bulletPoints: [String]) {
        self.id = id
        self.question = question
        self.icon = icon
        self.bulletPoints = bulletPoints
    }
}
