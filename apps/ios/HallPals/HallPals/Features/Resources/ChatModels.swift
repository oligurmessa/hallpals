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

    // Formatted date string for display
    var dateString: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(updatedAt) {
            let formatter = DateFormatter()
            formatter.timeStyle = .short
            return formatter.string(from: updatedAt)
        } else if calendar.isDateInYesterday(updatedAt) {
            return "Yesterday"
        } else {
            let formatter = DateFormatter()
            formatter.dateStyle = .short
            return formatter.string(from: updatedAt)
        }
    }
}

// MARK: - Chat Store

class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var currentSession: ChatSession?

    init() {
        // Start with a welcome session
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

        // Save to history if it has user messages
        if isUser {
            saveCurrentSessionToHistory()
        }
    }

    func selectSession(_ session: ChatSession) {
        currentSession = session
    }

    private func saveCurrentSessionToHistory() {
        guard let current = currentSession else { return }

        // Update existing or add new
        if let index = sessions.firstIndex(where: { $0.id == current.id }) {
            sessions[index] = current
        } else {
            sessions.insert(current, at: 0)
        }

        // Keep only last 20 sessions
        if sessions.count > 20 {
            sessions = Array(sessions.prefix(20))
        }
    }

    func deleteSession(_ session: ChatSession) {
        sessions.removeAll { $0.id == session.id }
        if currentSession?.id == session.id {
            startNewSession()
        }
    }

    func deleteSession(at offsets: IndexSet) {
        for index in offsets {
            let session = sessions[index]
            if currentSession?.id == session.id {
                startNewSession()
            }
        }
        sessions.remove(atOffsets: offsets)
    }
}
