import SwiftUI
import FirebaseFirestore

/// Modern conversation list view (DMs and Groups)
struct ConversationsListView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var pushService: PushNotificationService
    @StateObject private var viewModel = ConversationsListViewModel()
    @State private var showCreateConversation = false
    @State private var searchText = ""
    @State private var navigationPath = NavigationPath()

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if viewModel.conversations.isEmpty && !viewModel.isLoading {
                    emptyState
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Messages")
            .searchable(text: $searchText, prompt: "Search conversations")
            .toolbar {
                ToolbarItem(placement: .primaryAction) {
                    Button {
                        showCreateConversation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .sheet(isPresented: $showCreateConversation) {
                CreateConversationView()
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
            viewModel.displayTitle(for: conversation)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 100, height: 100)

                Image(systemName: "bubble.left.and.bubble.right.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 8) {
                Text("No Messages Yet")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(.primary)

                Text("Start a conversation with your\nhall community")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                showCreateConversation = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "plus")
                        .font(.system(size: 15, weight: .semibold))
                    Text("New Message")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 24)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(25)
            }
            .padding(.top, 8)
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
                        ModernConversationRow(
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

// MARK: - Modern Conversation Row

struct ModernConversationRow: View {
    let conversation: ChatService.Conversation
    let displayTitle: String
    let hasUnread: Bool

    var body: some View {
        HStack(spacing: 14) {
            // Avatar
            avatarView

            // Content
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(displayTitle)
                        .font(.system(size: 17, weight: hasUnread ? .semibold : .regular))
                        .foregroundColor(.primary)
                        .lineLimit(1)

                    Spacer()

                    if let lastMessageAt = conversation.lastMessageAt {
                        Text(formatDate(lastMessageAt))
                            .font(.system(size: 14))
                            .foregroundColor(hasUnread ? .blue : .secondary)
                    }
                }

                HStack(spacing: 6) {
                    if let preview = conversation.lastMessagePreview {
                        Text(preview)
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                    } else {
                        Text("Start the conversation")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                            .italic()
                    }

                    Spacer()

                    if hasUnread {
                        Circle()
                            .fill(Color.blue)
                            .frame(width: 10, height: 10)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(hasUnread ? Color.blue.opacity(0.04) : Color.clear)
    }

    @ViewBuilder
    private var avatarView: some View {
        if conversation.type == .group {
            // Group avatar with stacked circles
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.white)
            }
        } else {
            // DM avatar with initial
            ZStack {
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 56, height: 56)

                Text(String(displayTitle.prefix(1)).uppercased())
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.white)
            }
        }
    }

    private var avatarGradient: LinearGradient {
        let colors: [(Color, Color)] = [
            (.blue, .cyan),
            (.purple, .pink),
            (.orange, .red),
            (.green, .mint),
            (.indigo, .purple)
        ]
        let hash = abs(displayTitle.hashValue)
        let index = hash % colors.count
        return LinearGradient(
            colors: [colors[index].0, colors[index].1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
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

    private var listener: ListenerRegistration?
    private var displayNames: [String: String] = [:]
    private var memberships: [String: ChatService.ConversationMember] = [:]
    private var currentUid: String?

    func startListening(uid: String) {
        guard !uid.isEmpty else { return }

        currentUid = uid
        isLoading = true

        listener = ChatService.shared.listenConversations(uid: uid) { [weak self] conversations in
            Task { @MainActor in
                self?.conversations = conversations
                self?.isLoading = false

                // Load display names for DM participants
                for conversation in conversations where conversation.type == .dm {
                    let otherUid = conversation.participantIds.first { $0 != uid }
                    if let otherUid = otherUid, self?.displayNames[otherUid] == nil {
                        Task {
                            if let name = try? await ChatService.shared.getUserDisplayName(uid: otherUid) {
                                await MainActor.run {
                                    self?.displayNames[otherUid] = name
                                    self?.objectWillChange.send()
                                }
                            }
                        }
                    }
                }

                // Load memberships for unread detection
                for conversation in conversations {
                    if self?.memberships[conversation.id] == nil {
                        Task {
                            if let membership = try? await ChatService.shared.getMembership(
                                conversationId: conversation.id,
                                uid: uid
                            ) {
                                await MainActor.run {
                                    self?.memberships[conversation.id] = membership
                                    self?.objectWillChange.send()
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
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
