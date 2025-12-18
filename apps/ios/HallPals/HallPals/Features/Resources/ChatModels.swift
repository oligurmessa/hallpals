import SwiftUI

// MARK: - Chat Message

struct ChatMessage: Identifiable {
    let id = UUID()
    let text: String
    let isUser: Bool
    var image: UIImage? = nil
    let timestamp: Date = Date()
}

// MARK: - Chat Session

struct ChatSession: Identifiable {
    let id = UUID()
    var title: String
    var messages: [ChatMessage]
    let createdAt: Date
    var updatedAt: Date

    init(title: String = "New Chat", messages: [ChatMessage] = []) {
        self.title = title
        self.messages = messages
        self.createdAt = Date()
        self.updatedAt = Date()
    }

    // Generate title from first user message
    mutating func updateTitleFromFirstMessage() {
        if let firstUserMessage = messages.first(where: { $0.isUser }) {
            let text = firstUserMessage.text
            if text.count > 30 {
                title = String(text.prefix(30)) + "..."
            } else {
                title = text.isEmpty ? "New Chat" : text
            }
        }
    }
}

// MARK: - Chat Store (Simplified - No History)

class ChatStore: ObservableObject {
    @Published var currentSession: ChatSession?

    init() {
        startNewSession()
    }

    func startNewSession() {
        var session = ChatSession()
        // Add welcome message
        let welcomeMessage = ChatMessage(
            text: "Hello! I'm your HallPals AI assistant. How can I help you today?",
            isUser: false
        )
        session.messages.append(welcomeMessage)
        currentSession = session
    }

    func addMessage(_ text: String, isUser: Bool, image: UIImage? = nil) {
        guard var session = currentSession else { return }

        let message = ChatMessage(text: text, isUser: isUser, image: image)
        session.messages.append(message)
        session.updatedAt = Date()

        // Update title from first user message
        if isUser && session.messages.filter({ $0.isUser }).count == 1 {
            session.updateTitleFromFirstMessage()
        }

        currentSession = session
    }
}
