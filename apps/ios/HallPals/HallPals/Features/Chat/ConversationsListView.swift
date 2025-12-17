import SwiftUI
import FirebaseFirestore

/// Modern conversation list view - clean, minimal design
struct ConversationsListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var pushService: PushNotificationService
    @StateObject private var viewModel = ConversationsListViewModel()
    @State private var showCreateConversation = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()
    @State private var pendingNavigation: CreatedConversationResult?

    var body: some View {
        NavigationStack(path: $navigationPath) {
            VStack(spacing: 0) {
                // Custom header
                HStack {
                    Text("Chats")
                        .font(.system(size: 34, weight: .bold))
                        .foregroundColor(.primary)

                    Spacer()

                    Button {
                        showCreateConversation = true
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 12)

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(Color(UIColor.systemGray))

                    TextField("Search", text: $searchText)
                        .font(.system(size: 16))
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .cornerRadius(10)
                .padding(.horizontal, 20)
                .padding(.bottom, 12)

                // Content
                if viewModel.conversations.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    conversationsList
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .sheet(isPresented: $showCreateConversation, onDismiss: {
                // Navigate after sheet dismisses (single source of truth)
                if let nav = pendingNavigation {
                    let convNav = ConversationNavigation(
                        conversationId: nav.conversationId,
                        conversationType: nav.conversationType,
                        title: nav.title
                    )
                    // Small delay to ensure sheet is fully dismissed
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        navigationPath.append(convNav)
                    }
                    pendingNavigation = nil
                }
            }) {
                CreateConversationView { result in
                    pendingNavigation = result
                }
            }
            .navigationDestination(for: ConversationNavigation.self) { nav in
                ChatThreadView(
                    conversationId: nav.conversationId,
                    conversationType: nav.conversationType,
                    title: nav.title
                )
            }
            .onAppear {
                viewModel.startListening(uid: appState.currentUserId ?? "")
            }
            .onDisappear {
                viewModel.stopListening()
            }
            .onChange(of: pushService.pendingConversationId) { _, newId in
                handlePendingNavigation(conversationId: newId)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                // Check for pending navigation when app becomes active
                if let pendingId = pushService.pendingConversationId {
                    handlePendingNavigation(conversationId: pendingId)
                }
            }
        }
    }

    // MARK: - Navigation Handling

    private func handlePendingNavigation(conversationId: String?) {
        guard let conversationId = conversationId else { return }

        // Find the conversation in our list
        if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
            // Clear the pending navigation
            pushService.clearPendingNavigation()

            // Navigate to the conversation
            let nav = ConversationNavigation(
                conversationId: conversation.id,
                conversationType: conversation.type,
                title: viewModel.displayTitle(for: conversation)
            )
            navigationPath.append(nav)
        } else {
            // Conversation not loaded yet - navigate with minimal info
            pushService.clearPendingNavigation()

            let nav = ConversationNavigation(
                conversationId: conversationId,
                conversationType: .dm, // Default, will be corrected when loaded
                title: "Chat"
            )
            navigationPath.append(nav)
        }
    }

    private var filteredConversations: [ChatService.Conversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        }
        return viewModel.conversations.filter { conversation in
            // Search by display name (first + last name)
            let nameMatch = viewModel.displayTitle(for: conversation)
                .localizedCaseInsensitiveContains(searchText)

            // Search by email (for DM conversations)
            let emailMatch = viewModel.userEmail(for: conversation)?
                .localizedCaseInsensitiveContains(searchText) ?? false

            return nameMatch || emailMatch
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 80, height: 80)

                Image(systemName: "bubble.left.and.bubble.right")
                    .font(.system(size: 32))
                    .foregroundColor(Color(UIColor.systemGray3))
            }

            VStack(spacing: 8) {
                Text("No Chats Yet")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.primary)

                Text("Start a conversation with your\nhall community")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showCreateConversation = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "plus")
                        .font(.system(size: 14, weight: .semibold))
                    Text("New Chat")
                        .font(.system(size: 15, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(Color(UIColor.systemGray2))
                .cornerRadius(20)
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredConversations) { conversation in
                    Button {
                        let nav = ConversationNavigation(
                            conversationId: conversation.id,
                            conversationType: conversation.type,
                            title: viewModel.displayTitle(for: conversation)
                        )
                        navigationPath.append(nav)
                    } label: {
                        ChatRow(
                            conversation: conversation,
                            displayTitle: viewModel.displayTitle(for: conversation),
                            hasUnread: viewModel.hasUnread(conversation)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .refreshable {
            viewModel.stopListening()
            viewModel.startListening(uid: appState.currentUserId ?? "")
        }
    }
}

// MARK: - Navigation Model

struct ConversationNavigation: Hashable {
    let conversationId: String
    let conversationType: ChatService.Conversation.ConversationType
    let title: String
}

// MARK: - Chat Row

struct ChatRow: View {
    let conversation: ChatService.Conversation
    let displayTitle: String
    let hasUnread: Bool

    var body: some View {
        HStack(spacing: 12) {
            // Silhouette avatar
            avatarView

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(.system(size: 16, weight: hasUnread ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(formatDate(lastMessageAt))
                            .font(.system(size: 13))
                            .foregroundColor(Color(UIColor.systemGray))
                    }
                }

                HStack(spacing: 6) {
                    if let preview = conversation.lastMessagePreview {
                        Text(preview)
                            .font(.system(size: 14))
                            .foregroundColor(Color(UIColor.systemGray))
                            .lineLimit(1)
                    } else {
                        Text("Start the conversation")
                            .font(.system(size: 14))
                            .foregroundColor(Color(UIColor.systemGray2))
                            .italic()
                    }

                    Spacer()

                    if hasUnread {
                        Circle()
                            .fill(Color(UIColor.systemGray))
                            .frame(width: 8, height: 8)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var avatarView: some View {
        if conversation.type == .group {
            // Group avatar - silhouette style
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 48, height: 48)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
        } else {
            // DM avatar - silhouette style
            ZStack {
                Circle()
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 48, height: 48)

                Image(systemName: "person.fill")
                    .font(.system(size: 20))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
        }
    }

    private func formatDate(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return formatter.string(from: date)
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "M/d/yy"
            return formatter.string(from: date)
        }
    }
}

// MARK: - ViewModel

@MainActor
class ConversationsListViewModel: ObservableObject {
    @Published var conversations: [ChatService.Conversation] = []
    @Published var isLoading = false

    private var conversationsListener: ListenerRegistration?
    private var membershipListeners: [String: ListenerRegistration] = [:]
    private var displayNames: [String: String] = [:]
    private var userEmails: [String: String] = [:]  // uid -> email for search
    private var memberships: [String: ChatService.ConversationMember] = [:]
    private var currentUid: String?

    func startListening(uid: String) {
        guard !uid.isEmpty else { return }

        currentUid = uid
        isLoading = true

        conversationsListener = ChatService.shared.listenConversations(uid: uid) { [weak self] conversations in
            Task { @MainActor in
                guard let self = self else { return }

                self.conversations = conversations
                self.isLoading = false

                // Load display names and emails for DM participants
                for conversation in conversations where conversation.type == .dm {
                    let otherUid = conversation.participantIds.first { $0 != uid }
                    if let otherUid = otherUid, self.displayNames[otherUid] == nil {
                        Task {
                            if let info = try? await ChatService.shared.getUserInfo(uid: otherUid) {
                                await MainActor.run {
                                    self.displayNames[otherUid] = info.displayName
                                    if let email = info.email {
                                        self.userEmails[otherUid] = email
                                    }
                                    self.objectWillChange.send()
                                }
                            }
                        }
                    }
                }

                // Setup REAL-TIME membership listeners for unread detection
                // This ensures unread indicators update immediately when lastReadAt changes
                for conversation in conversations {
                    if self.membershipListeners[conversation.id] == nil {
                        let listener = ChatService.shared.listenMembership(
                            conversationId: conversation.id,
                            uid: uid
                        ) { [weak self] membership in
                            Task { @MainActor in
                                guard let self = self else { return }
                                if let membership = membership {
                                    self.memberships[conversation.id] = membership
                                } else {
                                    self.memberships.removeValue(forKey: conversation.id)
                                }
                                self.objectWillChange.send()
                            }
                        }
                        self.membershipListeners[conversation.id] = listener
                    }
                }

                // Clean up listeners for conversations we're no longer part of
                let currentIds = Set(conversations.map { $0.id })
                for (convId, listener) in self.membershipListeners where !currentIds.contains(convId) {
                    listener.remove()
                    self.membershipListeners.removeValue(forKey: convId)
                    self.memberships.removeValue(forKey: convId)
                }
            }
        }
    }

    func stopListening() {
        conversationsListener?.remove()
        conversationsListener = nil

        // Stop all membership listeners
        for (_, listener) in membershipListeners {
            listener.remove()
        }
        membershipListeners.removeAll()
    }

    func displayTitle(for conversation: ChatService.Conversation) -> String {
        if conversation.type == .group {
            return conversation.title ?? "Group Chat"
        }

        // For DM, show other participant's name
        guard let currentUid = currentUid else {
            return "Direct Message"
        }

        let otherUid = conversation.participantIds.first { $0 != currentUid }
        if let otherUid = otherUid, let name = displayNames[otherUid] {
            return name
        }

        return otherUid.map { String($0.prefix(8)) } ?? "Direct Message"
    }

    /// Get the email for a DM conversation's other participant (for search)
    func userEmail(for conversation: ChatService.Conversation) -> String? {
        guard conversation.type == .dm, let currentUid = currentUid else {
            return nil
        }

        let otherUid = conversation.participantIds.first { $0 != currentUid }
        if let otherUid = otherUid {
            return userEmails[otherUid]
        }
        return nil
    }

    func hasUnread(_ conversation: ChatService.Conversation) -> Bool {
        guard let membership = memberships[conversation.id],
              let lastMessageAt = conversation.lastMessageAt else {
            return false
        }

        return lastMessageAt > membership.lastReadAt
    }
}

#Preview {
    ConversationsListView()
        .environmentObject(AppState.shared)
        .environmentObject(PushNotificationService.shared)
}
