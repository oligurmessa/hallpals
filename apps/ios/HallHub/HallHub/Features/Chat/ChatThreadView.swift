import SwiftUI
import FirebaseFirestore

/// Modern chat thread view with iMessage-style bubbles
struct ChatThreadView: View {
    @EnvironmentObject private var appState: AppState
    @StateObject private var viewModel: ChatThreadViewModel
    @Environment(\.scenePhase) private var scenePhase
    @FocusState private var isInputFocused: Bool

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
                    LazyVStack(spacing: 2) {
                        // Load more button
                        if viewModel.canLoadMore {
                            loadMoreButton
                        }

                        // Date-grouped messages
                        ForEach(groupedMessages, id: \.date) { group in
                            // Date separator
                            dateSeparator(for: group.date)

                            ForEach(Array(group.messages.enumerated()), id: \.element.id) { index, message in
                                let isFromCurrentUser = message.senderId == appState.currentUserId
                                let showAvatar = shouldShowAvatar(
                                    message: message,
                                    index: index,
                                    in: group.messages
                                )
                                let showTail = shouldShowTail(
                                    message: message,
                                    index: index,
                                    in: group.messages
                                )

                                ModernMessageBubble(
                                    message: message,
                                    isFromCurrentUser: isFromCurrentUser,
                                    senderName: viewModel.senderName(for: message.senderId),
                                    showAvatar: showAvatar && conversationType == .group,
                                    showTail: showTail
                                )
                                .id(message.id)
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 12)
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
            ModernMessageComposer(
                isFocused: $isInputFocused
            ) { text in
                Task {
                    await viewModel.sendMessage(text: text)
                }
            }
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                VStack(spacing: 0) {
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                    if conversationType == .group {
                        Text("\(viewModel.memberCount) members")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.startListening(uid: appState.currentUserId ?? "")
        }
        .onDisappear {
            viewModel.markAsRead()
            viewModel.stopListening()
        }
        .onChange(of: viewModel.messages.count) { oldCount, newCount in
            // Mark as read when new messages arrive while viewing
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

    // MARK: - Grouped Messages

    private struct MessageGroup: Hashable {
        let date: Date
        let messages: [ChatService.Message]

        func hash(into hasher: inout Hasher) {
            hasher.combine(date)
        }

        static func == (lhs: MessageGroup, rhs: MessageGroup) -> Bool {
            lhs.date == rhs.date
        }
    }

    private var groupedMessages: [MessageGroup] {
        let calendar = Calendar.current
        var groups: [MessageGroup] = []
        var currentGroup: [ChatService.Message] = []
        var currentDate: Date?

        for message in viewModel.messages {
            let messageDate = calendar.startOfDay(for: message.createdAt)

            if let date = currentDate, calendar.isDate(date, inSameDayAs: messageDate) {
                currentGroup.append(message)
            } else {
                if let date = currentDate, !currentGroup.isEmpty {
                    groups.append(MessageGroup(date: date, messages: currentGroup))
                }
                currentDate = messageDate
                currentGroup = [message]
            }
        }

        if let date = currentDate, !currentGroup.isEmpty {
            groups.append(MessageGroup(date: date, messages: currentGroup))
        }

        return groups
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
                    .frame(height: 40)
            } else {
                Text("Load earlier messages")
                    .font(.system(size: 14))
                    .foregroundColor(.blue)
                    .padding(.vertical, 12)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func dateSeparator(for date: Date) -> some View {
        Text(formatDateSeparator(date))
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity)
    }

    private func formatDateSeparator(_ date: Date) -> String {
        let calendar = Calendar.current

        if calendar.isDateInToday(date) {
            return "Today"
        } else if calendar.isDateInYesterday(date) {
            return "Yesterday"
        } else if calendar.isDate(date, equalTo: Date(), toGranularity: .weekOfYear) {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE"
            return formatter.string(from: date)
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMMM d, yyyy"
            return formatter.string(from: date)
        }
    }

    // MARK: - Bubble Logic

    private func shouldShowAvatar(message: ChatService.Message, index: Int, in messages: [ChatService.Message]) -> Bool {
        guard message.senderId != appState.currentUserId else { return false }

        // Show avatar if this is the last message from this sender in a sequence
        if index == messages.count - 1 { return true }

        let nextMessage = messages[index + 1]
        return nextMessage.senderId != message.senderId
    }

    private func shouldShowTail(message: ChatService.Message, index: Int, in messages: [ChatService.Message]) -> Bool {
        // Show tail if this is the last message from this sender in a sequence
        if index == messages.count - 1 { return true }

        let nextMessage = messages[index + 1]
        return nextMessage.senderId != message.senderId
    }
}

// MARK: - Modern Message Bubble

struct ModernMessageBubble: View {
    let message: ChatService.Message
    let isFromCurrentUser: Bool
    let senderName: String
    let showAvatar: Bool
    let showTail: Bool

    var body: some View {
        HStack(alignment: .bottom, spacing: 8) {
            if isFromCurrentUser {
                Spacer(minLength: 60)
            } else {
                // Avatar placeholder for alignment
                if showAvatar {
                    avatarView
                } else {
                    Color.clear
                        .frame(width: 32, height: 32)
                }
            }

            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 2) {
                // Sender name (for groups, only for other users)
                if !isFromCurrentUser && showAvatar {
                    Text(senderName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                        .padding(.leading, 12)
                }

                // Message bubble
                bubbleContent
            }

            if !isFromCurrentUser {
                Spacer(minLength: 60)
            }
        }
        .padding(.vertical, showTail ? 4 : 1)
    }

    @ViewBuilder
    private var avatarView: some View {
        ZStack {
            Circle()
                .fill(avatarGradient)
                .frame(width: 32, height: 32)

            Text(String(senderName.prefix(1)).uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white)
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
        let hash = abs(senderName.hashValue)
        let index = hash % colors.count
        return LinearGradient(
            colors: [colors[index].0, colors[index].1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    @ViewBuilder
    private var bubbleContent: some View {
        if message.isDeleted {
            Text(message.displayText)
                .font(.system(size: 16))
                .italic()
                .foregroundColor(.secondary)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(UIColor.systemGray5))
                .clipShape(BubbleShape(isFromCurrentUser: isFromCurrentUser, showTail: showTail))
        } else {
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.displayText)
                    .font(.system(size: 16))
                    .foregroundColor(isFromCurrentUser ? .white : .primary)

                // Timestamp
                Text(formatTime(message.createdAt))
                    .font(.system(size: 11))
                    .foregroundColor(isFromCurrentUser ? .white.opacity(0.7) : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                isFromCurrentUser
                    ? Color.blue
                    : Color(UIColor.systemGray5)
            )
            .clipShape(BubbleShape(isFromCurrentUser: isFromCurrentUser, showTail: showTail))
        }
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

// MARK: - Bubble Shape

struct BubbleShape: Shape {
    let isFromCurrentUser: Bool
    let showTail: Bool

    func path(in rect: CGRect) -> Path {
        let radius: CGFloat = 18
        let tailSize: CGFloat = showTail ? 6 : 0

        var path = Path()

        if isFromCurrentUser {
            // Current user bubble (right side, tail on right)
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))

            if showTail {
                // Tail
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX + tailSize, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            } else {
                path.addQuadCurve(
                    to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                    control: CGPoint(x: rect.maxX, y: rect.maxY)
                )
            }

            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                control: CGPoint(x: rect.minX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        } else {
            // Other user bubble (left side, tail on left)
            path.move(to: CGPoint(x: rect.minX + radius, y: rect.minY))
            path.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX, y: rect.minY + radius),
                control: CGPoint(x: rect.maxX, y: rect.minY)
            )
            path.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.maxX - radius, y: rect.maxY),
                control: CGPoint(x: rect.maxX, y: rect.maxY)
            )
            path.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))

            if showTail {
                // Tail
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX - tailSize, y: rect.maxY),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
            } else {
                path.addQuadCurve(
                    to: CGPoint(x: rect.minX, y: rect.maxY - radius),
                    control: CGPoint(x: rect.minX, y: rect.maxY)
                )
            }

            path.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            path.addQuadCurve(
                to: CGPoint(x: rect.minX + radius, y: rect.minY),
                control: CGPoint(x: rect.minX, y: rect.minY)
            )
        }

        return path
    }
}

// MARK: - Modern Message Composer

struct ModernMessageComposer: View {
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
                HStack(alignment: .bottom, spacing: 8) {
                    TextField("Message", text: $text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(.system(size: 16))
                        .focused(isFocused)
                        .lineLimit(1...6)
                        .padding(.vertical, 10)
                        .padding(.leading, 14)

                    // Send button inside text field
                    Button {
                        guard canSend else { return }
                        onSend(text.trimmingCharacters(in: .whitespacesAndNewlines))
                        text = ""
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 30))
                            .foregroundColor(canSend ? .blue : Color(UIColor.systemGray4))
                    }
                    .disabled(!canSend)
                    .padding(.trailing, 6)
                    .padding(.bottom, 4)
                }
                .background(Color(UIColor.systemGray6))
                .cornerRadius(22)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(Color(UIColor.systemBackground))
        }
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

    func sendMessage(text: String) async {
        let messageId = UUID().uuidString

        do {
            try await ChatService.shared.sendMessage(
                conversationId: conversationId,
                messageId: messageId,
                text: text
            )
        } catch {
            #if DEBUG
            print("Failed to send message: \(error)")
            #endif
        }
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

        // Use current time to ensure lastReadAt is always >= lastMessageAt
        // This guarantees the message will be marked as read
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
