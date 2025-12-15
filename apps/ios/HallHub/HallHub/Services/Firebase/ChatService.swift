import Foundation
import FirebaseFirestore

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Service for Chat functionality
/// Phase C3.2: Global Chat with tenantId boundary
@MainActor
final class ChatService: ObservableObject {

    // MARK: - Singleton

    static let shared = ChatService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    private let db = Firestore.firestore()

    #if canImport(FirebaseFunctions)
    private lazy var functions = Functions.functions()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Models

    struct Conversation: Identifiable, Equatable {
        let id: String
        let type: ConversationType
        let title: String?
        let participantIds: [String]
        let lastMessagePreview: String?
        let lastMessageAt: Date?
        let createdAt: Date

        enum ConversationType: String {
            case dm
            case group
        }
    }

    struct ConversationMember: Identifiable, Equatable {
        let id: String  // uid
        let status: MemberStatus
        let role: MemberRole
        let joinedAt: Date
        let updatedAt: Date
        let lastReadAt: Date

        enum MemberStatus: String {
            case active
            case left
            case banned
        }

        enum MemberRole: String {
            case member
            case admin
        }
    }

    struct Message: Identifiable, Equatable {
        let id: String
        let senderId: String
        let text: String?
        let imageUrl: String?
        let createdAt: Date
        let editedAt: Date?
        let deletedAt: Date?

        var isDeleted: Bool { deletedAt != nil }

        var displayText: String {
            if isDeleted {
                return "[deleted]"
            }
            if let text = text, !text.isEmpty {
                return text
            }
            if imageUrl != nil {
                return "[image]"
            }
            return ""
        }
    }

    // MARK: - Cloud Function Calls (Global - no hallId)

    /// Creates or retrieves an existing DM conversation
    /// Returns the conversation ID (deterministic: dm_{minUid}_{maxUid})
    func createOrGetDM(otherUid: String) async throws -> String {
        #if canImport(FirebaseFunctions)
        isLoading = true
        error = nil
        defer { isLoading = false }

        #if DEBUG
        print("💬 CHAT: Creating/getting DM with \(otherUid)")
        #endif

        do {
            let result = try await functions.httpsCallable("createOrGetDM").call([
                "otherUid": otherUid
            ])

            guard let data = result.data as? [String: Any],
                  let conversationId = data["conversationId"] as? String else {
                throw ChatError.invalidResponse
            }

            let created = data["created"] as? Bool ?? false

            #if DEBUG
            print("💬 CHAT: DM \(created ? "created" : "retrieved"): \(conversationId)")
            #endif

            return conversationId
        } catch {
            self.error = parseError(error)
            throw ChatError.functionFailed(self.error ?? "Unknown error")
        }
        #else
        throw ChatError.notConfigured
        #endif
    }

    /// Creates a new group conversation
    /// Returns the conversation ID
    func createGroupConversation(title: String, memberUids: [String]) async throws -> String {
        #if canImport(FirebaseFunctions)
        isLoading = true
        error = nil
        defer { isLoading = false }

        #if DEBUG
        print("💬 CHAT: Creating group '\(title)' with \(memberUids.count) members")
        #endif

        do {
            let result = try await functions.httpsCallable("createGroupConversation").call([
                "title": title,
                "memberUids": memberUids
            ])

            guard let data = result.data as? [String: Any],
                  let conversationId = data["conversationId"] as? String else {
                throw ChatError.invalidResponse
            }

            #if DEBUG
            print("💬 CHAT: Group created: \(conversationId)")
            #endif

            return conversationId
        } catch {
            self.error = parseError(error)
            throw ChatError.functionFailed(self.error ?? "Unknown error")
        }
        #else
        throw ChatError.notConfigured
        #endif
    }

    /// Sends a message to a conversation
    /// Client generates UUID for idempotency
    func sendMessage(
        conversationId: String,
        messageId: String = UUID().uuidString,
        text: String? = nil,
        imageUrl: String? = nil
    ) async throws {
        #if canImport(FirebaseFunctions)
        isLoading = true
        error = nil
        defer { isLoading = false }

        #if DEBUG
        print("💬 CHAT: Sending message \(messageId) to \(conversationId)")
        #endif

        var params: [String: Any] = [
            "conversationId": conversationId,
            "messageId": messageId
        ]

        if let text = text {
            params["text"] = text
        }
        if let imageUrl = imageUrl {
            params["imageUrl"] = imageUrl
        }

        do {
            _ = try await functions.httpsCallable("sendMessage").call(params)

            #if DEBUG
            print("💬 CHAT: Message sent successfully")
            #endif
        } catch {
            self.error = parseError(error)
            throw ChatError.functionFailed(self.error ?? "Unknown error")
        }
        #else
        throw ChatError.notConfigured
        #endif
    }

    /// Updates the lastReadAt timestamp for the current user
    /// Monotonic: only moves forward
    func updateLastRead(conversationId: String, lastReadAt: Date) async throws {
        #if canImport(FirebaseFunctions)
        // Don't set isLoading for this background operation

        #if DEBUG
        print("💬 CHAT: Updating lastReadAt for \(conversationId)")
        #endif

        do {
            _ = try await functions.httpsCallable("updateLastRead").call([
                "conversationId": conversationId,
                "lastReadAt": [
                    "_seconds": Int(lastReadAt.timeIntervalSince1970),
                    "_nanoseconds": 0
                ]
            ])

            #if DEBUG
            print("💬 CHAT: lastReadAt updated")
            #endif
        } catch {
            // Silently fail for lastRead updates - not critical
            #if DEBUG
            print("💬 CHAT: lastReadAt update failed: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    // MARK: - Firestore Listeners (Global paths)

    /// Listen to conversations for a user
    /// Two-query approach: conversations with messages (ordered) + without messages
    func listenConversations(
        uid: String,
        onUpdate: @escaping ([Conversation]) -> Void
    ) -> ListenerRegistration {
        // Primary query: conversations with lastMessageAt (ordered by recency)
        let primaryQuery = db.collection("conversations")
            .whereField("participantIds", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .limit(to: 30)

        #if DEBUG
        print("💬 CHAT: Starting conversation listener for uid: \(uid)")
        #endif

        return primaryQuery.addSnapshotListener { [weak self] snapshot, error in
            if let error = error {
                #if DEBUG
                print("💬 CHAT: Error listening to conversations: \(error.localizedDescription)")
                print("💬 CHAT: Error code: \((error as NSError).code)")
                print("💬 CHAT: Error domain: \((error as NSError).domain)")
                #endif

                // If permission denied, the user might need to check their membership
                if (error as NSError).code == 7 {
                    #if DEBUG
                    print("💬 CHAT: Permission denied - user may not have active memberships")
                    #endif
                }
                return
            }

            guard let documents = snapshot?.documents else {
                #if DEBUG
                print("💬 CHAT: No documents in snapshot")
                #endif
                onUpdate([])
                return
            }

            #if DEBUG
            print("💬 CHAT: Received \(documents.count) conversations")
            #endif

            let conversations = documents.compactMap { doc -> Conversation? in
                let data = doc.data()

                guard let typeString = data["type"] as? String,
                      let type = Conversation.ConversationType(rawValue: typeString),
                      let participantIds = data["participantIds"] as? [String],
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    #if DEBUG
                    print("💬 CHAT: Failed to parse conversation \(doc.documentID)")
                    #endif
                    return nil
                }

                return Conversation(
                    id: doc.documentID,
                    type: type,
                    title: data["title"] as? String,
                    participantIds: participantIds,
                    lastMessagePreview: data["lastMessagePreview"] as? String,
                    lastMessageAt: (data["lastMessageAt"] as? Timestamp)?.dateValue(),
                    createdAt: createdAt
                )
            }

            // Also fetch conversations without lastMessageAt (newly created)
            self?.fetchNewConversations(uid: uid, existingIds: Set(conversations.map { $0.id })) { newConversations in
                let allConversations = conversations + newConversations
                onUpdate(allConversations)
            }
        }
    }

    /// Fetch conversations that don't have lastMessageAt yet (newly created)
    private func fetchNewConversations(
        uid: String,
        existingIds: Set<String>,
        completion: @escaping ([Conversation]) -> Void
    ) {
        // Query for conversations where user is participant but no messages yet
        // These won't show up in the lastMessageAt ordered query
        db.collection("conversations")
            .whereField("participantIds", arrayContains: uid)
            .whereField("lastMessageAt", isEqualTo: NSNull())
            .limit(to: 10)
            .getDocuments { snapshot, error in
                if let error = error {
                    #if DEBUG
                    print("💬 CHAT: Error fetching new conversations: \(error.localizedDescription)")
                    #endif
                    completion([])
                    return
                }

                guard let documents = snapshot?.documents else {
                    completion([])
                    return
                }

                let newConversations = documents.compactMap { doc -> Conversation? in
                    // Skip if already in existing list
                    guard !existingIds.contains(doc.documentID) else { return nil }

                    let data = doc.data()

                    guard let typeString = data["type"] as? String,
                          let type = Conversation.ConversationType(rawValue: typeString),
                          let participantIds = data["participantIds"] as? [String],
                          let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                        return nil
                    }

                    return Conversation(
                        id: doc.documentID,
                        type: type,
                        title: data["title"] as? String,
                        participantIds: participantIds,
                        lastMessagePreview: nil,
                        lastMessageAt: nil,
                        createdAt: createdAt
                    )
                }

                #if DEBUG
                if !newConversations.isEmpty {
                    print("💬 CHAT: Found \(newConversations.count) new conversations without messages")
                }
                #endif

                completion(newConversations)
            }
    }

    /// Listen to messages in a conversation
    /// Stable ordering: (createdAt, documentId) to prevent duplicates under pagination
    func listenMessages(
        conversationId: String,
        limit: Int = 50,
        onUpdate: @escaping ([Message]) -> Void
    ) -> ListenerRegistration {
        // Stable ordering: createdAt ASC, then documentId ASC
        let query = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .order(by: FieldPath.documentID(), descending: false)
            .limit(toLast: limit)

        return query.addSnapshotListener { snapshot, error in
            if let error = error {
                #if DEBUG
                print("💬 CHAT: Error listening to messages: \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = snapshot?.documents else {
                onUpdate([])
                return
            }

            let messages = documents.compactMap { doc -> Message? in
                let data = doc.data()

                guard let senderId = data["senderId"] as? String,
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                    return nil
                }

                return Message(
                    id: doc.documentID,
                    senderId: senderId,
                    text: data["text"] as? String,
                    imageUrl: data["imageUrl"] as? String,
                    createdAt: createdAt,
                    editedAt: (data["editedAt"] as? Timestamp)?.dateValue(),
                    deletedAt: (data["deletedAt"] as? Timestamp)?.dateValue()
                )
            }

            onUpdate(messages)
        }
    }

    /// Load older messages with pagination (cursor-based)
    /// Uses full snapshot cursor for stable pagination with composite ordering
    func loadOlderMessages(
        conversationId: String,
        beforeMessageId: String,
        beforeCreatedAt: Date,
        limit: Int = 30
    ) async throws -> [Message] {
        // Stable ordering: createdAt DESC, documentId DESC (for older messages)
        // Cursor uses both values for deterministic pagination
        let query = db.collection("conversations")
            .document(conversationId)
            .collection("messages")
            .order(by: "createdAt", descending: true)
            .order(by: FieldPath.documentID(), descending: true)
            .start(after: [Timestamp(date: beforeCreatedAt), beforeMessageId])
            .limit(to: limit)

        let snapshot = try await query.getDocuments()

        return snapshot.documents.compactMap { doc -> Message? in
            let data = doc.data()

            guard let senderId = data["senderId"] as? String,
                  let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() else {
                return nil
            }

            return Message(
                id: doc.documentID,
                senderId: senderId,
                text: data["text"] as? String,
                imageUrl: data["imageUrl"] as? String,
                createdAt: createdAt,
                editedAt: (data["editedAt"] as? Timestamp)?.dateValue(),
                deletedAt: (data["deletedAt"] as? Timestamp)?.dateValue()
            )
        }.reversed()  // Return in chronological order
    }

    /// Get the current user's membership in a conversation
    func getMembership(conversationId: String, uid: String) async throws -> ConversationMember? {
        let doc = try await db.collection("conversations")
            .document(conversationId)
            .collection("members")
            .document(uid)
            .getDocument()

        guard doc.exists, let data = doc.data() else {
            return nil
        }

        guard let statusString = data["status"] as? String,
              let status = ConversationMember.MemberStatus(rawValue: statusString),
              let roleString = data["role"] as? String,
              let role = ConversationMember.MemberRole(rawValue: roleString),
              let joinedAt = (data["joinedAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue(),
              let lastReadAt = (data["lastReadAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return ConversationMember(
            id: uid,
            status: status,
            role: role,
            joinedAt: joinedAt,
            updatedAt: updatedAt,
            lastReadAt: lastReadAt
        )
    }

    /// Get user display name for chat
    /// Uses /users/{uid} displayName field
    func getUserDisplayName(uid: String) async throws -> String {
        let doc = try await db.collection("users")
            .document(uid)
            .getDocument()

        guard doc.exists, let data = doc.data() else {
            return String(uid.prefix(8))
        }

        if let displayName = data["displayName"] as? String, !displayName.isEmpty {
            return displayName
        }

        return String(uid.prefix(8))
    }

    // MARK: - Error Handling

    private func parseError(_ error: Error) -> String {
        if let nsError = error as NSError? {
            if nsError.domain == "com.firebase.functions" {
                switch nsError.code {
                case 3: return "Invalid request"
                case 5: return "Not found"
                case 7: return "Permission denied"
                case 16: return "Please sign in first"
                default: return nsError.localizedDescription
                }
            }
        }
        return error.localizedDescription
    }
}

// MARK: - Errors

enum ChatError: LocalizedError {
    case notConfigured
    case invalidResponse
    case functionFailed(String)
    case notMember

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Chat is not configured"
        case .invalidResponse:
            return "Invalid response from server"
        case .functionFailed(let message):
            return message
        case .notMember:
            return "You are not a member of this conversation"
        }
    }
}
