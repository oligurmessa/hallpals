import SwiftUI
import FirebaseFirestore

/// Modern chat thread view - clean, minimal design
struct ChatThreadView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatThreadViewModel
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    @State private var errorMessage: String?
    @State private var showError = false

    let conversationId: String
    let conversationType: ChatService.Conversation.ConversationType
    let title: String

    init(conversationId: String, conversationType: ChatService.Conversation.ConversationType, title: String) {
        self.conversationId = conversationId
        self.conversationType = conversationType
        self.title = title
        _viewModel = StateObject(wrappedValue: ChatThreadViewModel(conversationId: conversationId))
    }

    var body: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 16) {
                        // Load more button
                        if viewModel.canLoadMore {
                            loadMoreButton
                        }

                        // Messages without date grouping for cleaner look
                        ForEach(Array(viewModel.messages.enumerated()), id: \.element.id) { index, message in
                            let isFromCurrentUser = message.senderId == appState.currentUserId
                            let showTime = shouldShowTime(message: message, index: index)

                            ChatBubble(
                                message: message,
                                isFromCurrentUser: isFromCurrentUser,
                                senderName: viewModel.senderName(for: message.senderId),
                                showTime: showTime,
                                showAvatar: !isFromCurrentUser && conversationType == .group
                            )
                            .id(message.id)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 20)
                }
                .scrollDismissesKeyboard(.interactively)
                .onChange(of: viewModel.messages.count) { _, _ in
                    if let lastMessage = viewModel.messages.last {
                        withAnimation(.easeOut(duration: 0.2)) {
                            proxy.scrollTo(lastMessage.id, anchor: .bottom)
                        }
                    }
                }
                .onAppear {
                    if let lastMessage = viewModel.messages.last {
                        proxy.scrollTo(lastMessage.id, anchor: .bottom)
                    }
                }
            }

            // Composer
            ChatComposer(isFocused: $isInputFocused) { text in
                Task {
                    do {
                        try await viewModel.sendMessage(text: text)
                    } catch {
                        await MainActor.run {
                            errorMessage = "Failed to send message. Please try again."
                            showError = true
                        }
                    }
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .alert("Error", isPresented: $showError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(Color(UIColor.systemGray))
                }
            }
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.primary)
                    if conversationType == .group {
                        Text("\(viewModel.memberCount) members")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarBackground(Color(UIColor.systemBackground), for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .onAppear {
            viewModel.startListening(uid: appState.currentUserId ?? "")
        }
        .onDisappear {
            viewModel.markAsRead()
            viewModel.stopListening()
        }
        .onChange(of: viewModel.messages.count) { oldCount, newCount in
            if newCount > 0 {
                viewModel.markAsRead()
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .background || newPhase == .inactive {
                viewModel.markAsRead()
            }
        }
    }

    // MARK: - Helper Views

    private var loadMoreButton: some View {
        Button {
            Task {
                await viewModel.loadOlderMessages()
            }
        } label: {
            if viewModel.isLoadingMore {
                ProgressView()
                    .frame(height: 32)
            } else {
                Text("Load earlier messages")
                    .font(.system(size: 13))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.vertical, 8)
            }
        }
        .frame(maxWidth: .infinity)
    }

    // Show time if there's a gap of 5+ minutes or it's the last message in a sequence
    private func shouldShowTime(message: ChatService.Message, index: Int) -> Bool {
        // Always show time for last message in conversation
        if index == viewModel.messages.count - 1 { return true }

        let nextMessage = viewModel.messages[index + 1]

        // Show time if next message is from different sender
        if nextMessage.senderId != message.senderId { return true }

        // Show time if there's a 5+ minute gap
        let timeDiff = nextMessage.createdAt.timeIntervalSince(message.createdAt)
        return timeDiff > 300 // 5 minutes
    }
}

// MARK: - Chat Bubble

struct ChatBubble: View {
    let message: ChatService.Message
    let isFromCurrentUser: Bool
    let senderName: String
    let showTime: Bool
    let showAvatar: Bool

    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            HStack(alignment: .bottom, spacing: 8) {
                if isFromCurrentUser {
                    Spacer(minLength: 60)
                } else if showAvatar {
                    // Silhouette avatar
                    silhouetteAvatar
                } else {
                    Color.clear.frame(width: 32, height: 32)
                }

                // Message content
                bubbleContent

                if !isFromCurrentUser {
                    Spacer(minLength: 60)
                }
            }

            // Timestamp below bubble
            if showTime {
                Text(formatTime(message.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(Color(UIColor.systemGray))
                    .padding(.horizontal, isFromCurrentUser ? 4 : (showAvatar ? 44 : 4))
            }
        }
    }

    private var silhouetteAvatar: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.systemGray5))
                .frame(width: 32, height: 32)

            Image(systemName: "person.fill")
                .font(.system(size: 14))
                .foregroundColor(Color(UIColor.systemGray3))
        }
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.isDeleted {
            Text(message.displayText)
                .font(.system(size: 15))
                .italic()
                .foregroundColor(Color(UIColor.systemGray))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            Text(message.displayText)
                .font(.system(size: 15))
                .foregroundColor(isFromCurrentUser ? Color(UIColor.systemBlue).opacity(0.9) : .primary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    isFromCurrentUser
                        ? Color(red: 0.85, green: 0.92, blue: 1.0) // Light blue like reference
                        : Color(UIColor.systemGray6) // Light grey for others
                )
                .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Chat Composer

struct ChatComposer: View {
    var isFocused: FocusState<Bool>.Binding
    let onSend: (String) -> Void

    @State private var text = ""

    private var canSend: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            Divider()

            HStack(alignment: .bottom, spacing: 12) {
                // Text input
                TextField("Type a message...", text: $text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(.system(size: 15))
                    .focused(isFocused)
                    .lineLimit(1...4)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 16)
                    .background(Color(UIColor.systemGray6))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))

                // Send button - minimal
                Button {
                    guard canSend else { return }
                    onSend(text.trimmingCharacters(in: .whitespacesAndNewlines))
                    text = ""
                } label: {
                    Image(systemName: "arrow.up")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(width: 32, height: 32)
                        .background(canSend ? Color(UIColor.systemGray2) : Color(UIColor.systemGray4))
                        .clipShape(Circle())
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color(UIColor.systemBackground))
    }
}

// MARK: - ViewModel

@MainActor
class ChatThreadViewModel: ObservableObject {
    @Published var messages: [ChatService.Message] = []
    @Published var isLoadingMore = false
    @Published var canLoadMore = true
    @Published var memberCount: Int = 0

    let conversationId: String
    private var listener: ListenerRegistration?
    private var senderNames: [String: String] = [:]
    private var currentUid: String?

    init(conversationId: String) {
        self.conversationId = conversationId
    }

    func startListening(uid: String) {
        guard !conversationId.isEmpty else { return }

        currentUid = uid

        // Load member count for group chats
        Task {
            do {
                let count = try await ChatService.shared.getMemberCount(conversationId: conversationId)
                await MainActor.run {
                    self.memberCount = count
                }
            } catch {
                #if DEBUG
                print("💬 CHAT: Failed to load member count: \(error.localizedDescription)")
                #endif
            }
        }

        listener = ChatService.shared.listenMessages(
            conversationId: conversationId,
            limit: 50
        ) { [weak self] messages in
            Task { @MainActor in
                self?.messages = messages

                // Load sender names
                let uniqueSenderIds = Set(messages.map { $0.senderId })
                for senderId in uniqueSenderIds where self?.senderNames[senderId] == nil {
                    Task {
                        if let name = try? await ChatService.shared.getUserDisplayName(uid: senderId) {
                            await MainActor.run {
                                self?.senderNames[senderId] = name
                                self?.objectWillChange.send()
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

    func sendMessage(text: String) async throws {
        let messageId = UUID().uuidString

        try await ChatService.shared.sendMessage(
            conversationId: conversationId,
            messageId: messageId,
            text: text
        )
    }

    func loadOlderMessages() async {
        guard !isLoadingMore, let oldestMessage = messages.first else { return }

        isLoadingMore = true

        do {
            let olderMessages = try await ChatService.shared.loadOlderMessages(
                conversationId: conversationId,
                beforeMessageId: oldestMessage.id,
                beforeCreatedAt: oldestMessage.createdAt,
                limit: 30
            )

            await MainActor.run {
                if olderMessages.isEmpty {
                    canLoadMore = false
                } else {
                    messages.insert(contentsOf: olderMessages, at: 0)
                }
                isLoadingMore = false
            }
        } catch {
            await MainActor.run {
                isLoadingMore = false
            }
            #if DEBUG
            print("Failed to load older messages: \(error)")
            #endif
        }
    }

    func markAsRead() {
        guard !messages.isEmpty else { return }

        Task {
            try? await ChatService.shared.updateLastRead(
                conversationId: conversationId,
                lastReadAt: Date()
            )
        }
    }

    func senderName(for senderId: String) -> String {
        if senderId == currentUid {
            return "You"
        }
        return senderNames[senderId] ?? String(senderId.prefix(8))
    }
}

#Preview {
    NavigationStack {
        ChatThreadView(
            conversationId: "test-conversation",
            conversationType: .dm,
            title: "John Doe"
        )
        .environmentObject(AppState.shared)
    }
}
