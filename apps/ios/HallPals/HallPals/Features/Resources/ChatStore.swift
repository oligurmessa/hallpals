import SwiftUI
import Combine

// MARK: - Chat Models

struct ChatSession: Identifiable, Codable, Hashable {
    let id: UUID
    var title: String
    let date: Date
    var messages: [ChatMessage]
    
    // Custom formatted date for display
    var dateString: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}

struct ChatMessage: Identifiable, Codable, Hashable {
    let id: UUID
    let text: String
    let isUser: Bool
    
    // Transient - not persisted
    var image: UIImage? = nil
    
    enum CodingKeys: String, CodingKey {
        case id, text, isUser
    }
    
    init(id: UUID = UUID(), text: String, isUser: Bool, image: UIImage? = nil) {
        self.id = id
        self.text = text
        self.isUser = isUser
        self.image = image
    }
}

// MARK: - Chat Store

@MainActor
class ChatStore: ObservableObject {
    @Published var sessions: [ChatSession] = []
    @Published var currentSession: ChatSession?
    
    private let saveKey = "hallpals_chat_history"
    
    init() {
        loadSessions()
    }
    
    // MARK: - Session Management
    
    func startNewSession() {
        let newSession = ChatSession(
            id: UUID(),
            title: "New Chat",
            date: Date(),
            messages: [
                ChatMessage(text: "Hello! I'm your HallPals AI assistant. How can I help you today?", isUser: false)
            ]
        )
        // Add to beginning of list
        sessions.insert(newSession, at: 0)
        currentSession = newSession
        saveSessions()
    }
    
    func selectSession(_ session: ChatSession) {
        currentSession = session
        // Move to top of list as "most recently accessed" roughly
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.move(fromOffsets: IndexSet(integer: index), toOffset: 0)
        }
    }
    
    func addMessage(_ text: String, isUser: Bool, image: UIImage? = nil) {
        guard currentSession != nil else { return }
        
        let newMessage = ChatMessage(text: text, isUser: isUser, image: image)
        
        // Update current session
        if var session = currentSession {
            session.messages.append(newMessage)
            
            // Update title if it's the first user message
            if session.messages.filter({ $0.isUser }).count == 1 && isUser {
                session.title = text.prefix(30).trimmingCharacters(in: .whitespacesAndNewlines)
                if text.count > 30 { session.title += "..." }
            }
            
            currentSession = session
            
            // Update in list
            if let index = sessions.firstIndex(where: { $0.id == session.id }) {
                sessions[index] = session
            }
            
            saveSessions()
        }
    }
    
    func deleteSession(_ session: ChatSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions.remove(at: index)
            if currentSession?.id == session.id {
                startNewSession()
            }
            saveSessions()
        }
    }
    
    func deleteSession(at offsets: IndexSet) {
        sessions.remove(atOffsets: offsets)
        // Check if current session was deleted
        if let current = currentSession, !sessions.contains(where: { $0.id == current.id }) {
            startNewSession()
        }
        saveSessions()
    }
    
    // MARK: - Persistence
    
    private func saveSessions() {
        do {
            let data = try JSONEncoder().encode(sessions)
            UserDefaults.standard.set(data, forKey: saveKey)
        } catch {
            print("Failed to save chat sessions: \(error)")
        }
    }
    
    private func loadSessions() {
        guard let data = UserDefaults.standard.data(forKey: saveKey) else { return }
        
        do {
            sessions = try JSONDecoder().decode([ChatSession].self, from: data)
        } catch {
            print("Failed to load chat sessions: \(error)")
        }
    }
}
