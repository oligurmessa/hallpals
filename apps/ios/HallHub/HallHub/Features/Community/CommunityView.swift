import SwiftUI
import FirebaseFirestore

struct CommunityView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var pushService: PushNotificationService
    @StateObject private var viewModel = CommunityConversationsViewModel()
    @StateObject private var residentStore = ResidentStore.shared
    @State private var selectedTab: CommunityTab = .messages
    @State private var searchText = ""
    @State private var showCreateConversation = false
    @State private var navigationPath = NavigationPath()

    enum CommunityTab: String, CaseIterable {
        case messages = "Messages"
        case residents = "Residents"
    }

    var body: some View {
        NavigationStack(path: $navigationPath) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .padding(.horizontal, 20)

                    // Segmented Picker
                    segmentedPicker
                        .padding(.horizontal, 20)

                    // Content
                    contentSection
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationDestination(for: ConversationNavigation.self) { nav in
                ChatThreadView(
                    conversationId: nav.conversationId,
                    conversationType: nav.conversationType,
                    title: nav.title
                )
            }
            .sheet(isPresented: $showCreateConversation) {
                CreateConversationView()
            }
            .onAppear {
                if viewModel.conversations.isEmpty {
                    viewModel.startListening(uid: appState.currentUserId ?? "")
                } else {
                    // Returning to view - refresh memberships to update unread status
                    viewModel.refreshMemberships()
                }
            }
            .onDisappear {
                // Don't stop listening - we want real-time updates
                // viewModel.stopListening()
            }
            .onChange(of: pushService.pendingConversationId) { _, newId in
                handlePendingNavigation(conversationId: newId)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                if let pendingId = pushService.pendingConversationId {
                    handlePendingNavigation(conversationId: pendingId)
                }
            }
        }
    }

    // MARK: - Push Notification Navigation

    private func handlePendingNavigation(conversationId: String?) {
        guard let conversationId = conversationId else { return }

        if let conversation = viewModel.conversations.first(where: { $0.id == conversationId }) {
            pushService.clearPendingNavigation()
            let nav = ConversationNavigation(
                conversationId: conversation.id,
                conversationType: conversation.type,
                title: viewModel.displayTitle(for: conversation)
            )
            navigationPath.append(nav)
        } else {
            pushService.clearPendingNavigation()
            let nav = ConversationNavigation(
                conversationId: conversationId,
                conversationType: .dm,
                title: "Chat"
            )
            navigationPath.append(nav)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Community")
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)

                Text("\(viewModel.conversations.count) chats · \(residentStore.residentCount) residents")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // New message button
            Button {
                showCreateConversation = true
            } label: {
                Image(systemName: "square.and.pencil")
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 36, height: 36)
                    .background(Color.blue.opacity(0.12))
                    .clipShape(Circle())
            }
        }
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(CommunityTab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = tab
                    }
                } label: {
                    Text(tab.rawValue)
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(selectedTab == tab ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == tab
                                ? Color.blue
                                : Color.clear
                        )
                        .cornerRadius(8)
                }
            }
        }
        .padding(4)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Content Section

    private var contentSection: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case .messages:
                messagesList
            case .residents:
                residentsList
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 20)
    }

    // MARK: - Messages List (Real Firebase Conversations)

    private var filteredConversations: [ChatService.Conversation] {
        if searchText.isEmpty {
            return viewModel.conversations
        }
        return viewModel.conversations.filter { conversation in
            viewModel.displayTitle(for: conversation)
                .localizedCaseInsensitiveContains(searchText)
        }
    }

    private var messagesList: some View {
        VStack(spacing: 0) {
            if viewModel.isLoading {
                // Loading state
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.2)
                    Text("Loading conversations...")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(40)
            } else if viewModel.conversations.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 80, height: 80)

                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }

                    Text("No Messages Yet")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Start a conversation with your\nhall community")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)

                    Button {
                        showCreateConversation = true
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "plus")
                                .font(.system(size: 14, weight: .semibold))
                            Text("New Message")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .padding(.horizontal, 20)
                        .padding(.vertical, 12)
                        .background(Color.blue)
                        .cornerRadius(20)
                    }
                    .padding(.top, 8)
                }
                .padding(40)
            } else {
                // Conversations list
                ForEach(Array(filteredConversations.enumerated()), id: \.element.id) { index, conversation in
                    Button {
                        let nav = ConversationNavigation(
                            conversationId: conversation.id,
                            conversationType: conversation.type,
                            title: viewModel.displayTitle(for: conversation)
                        )
                        navigationPath.append(nav)
                    } label: {
                        ConversationRow(
                            conversation: conversation,
                            displayTitle: viewModel.displayTitle(for: conversation),
                            hasUnread: viewModel.hasUnread(conversation),
                            isLast: index == filteredConversations.count - 1
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Residents List

    private var filteredResidents: [RoompactResident] {
        if searchText.isEmpty {
            return residentStore.sortedResidents
        }
        return residentStore.search(searchText)
    }

    private var residentsList: some View {
        VStack(spacing: 0) {
            if residentStore.residents.isEmpty {
                // Empty state
                VStack(spacing: 16) {
                    Image(systemName: "person.3.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.secondary)

                    Text("No Residents")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("Import residents from the Duty tab to see them here")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(40)
            } else {
                // Search bar
                HStack(spacing: 10) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)

                    TextField("Search residents...", text: $searchText)
                        .font(.system(size: 16))

                    if !searchText.isEmpty {
                        Button {
                            searchText = ""
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                }
                .padding(12)
                .background(Color(UIColor.systemBackground))

                Divider()

                // Residents count
                HStack {
                    Text("\(filteredResidents.count) residents")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .background(Color(UIColor.tertiarySystemBackground))

                // List of residents
                ForEach(Array(filteredResidents.enumerated()), id: \.element.id) { index, resident in
                    CommunityResidentRow(resident: resident, isLast: index == filteredResidents.count - 1)
                }
            }
        }
    }
}

// MARK: - Conversation Row (Firebase)

struct ConversationRow: View {
    let conversation: ChatService.Conversation
    let displayTitle: String
    let hasUnread: Bool
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Avatar
                avatarView

                // Content
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(displayTitle)
                            .font(.system(size: 16, weight: hasUnread ? .semibold : .regular))
                            .foregroundColor(.primary)
                            .lineLimit(1)

                        Spacer()

                        if let lastMessageAt = conversation.lastMessageAt {
                            Text(formatDate(lastMessageAt))
                                .font(.system(size: 13))
                                .foregroundColor(hasUnread ? .blue : .secondary)
                        }
                    }

                    HStack(spacing: 6) {
                        if let preview = conversation.lastMessagePreview {
                            Text(preview)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        } else {
                            Text("Start the conversation")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .italic()
                        }

                        Spacer()

                        if hasUnread {
                            Circle()
                                .fill(Color.blue)
                                .frame(width: 8, height: 8)
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(hasUnread ? Color.blue.opacity(0.04) : Color.clear)

            if !isLast {
                Divider()
                    .padding(.leading, 78)
            }
        }
        .contentShape(Rectangle())
    }

    @ViewBuilder
    private var avatarView: some View {
        if conversation.type == .group {
            // Group avatar
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)

                Image(systemName: "person.2.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.white)
            }
        } else {
            // DM avatar with initial
            ZStack {
                Circle()
                    .fill(avatarGradient)
                    .frame(width: 48, height: 48)

                Text(String(displayTitle.prefix(1)).uppercased())
                    .font(.system(size: 18, weight: .semibold))
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

// MARK: - Community Conversations ViewModel

@MainActor
class CommunityConversationsViewModel: ObservableObject {
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

                // Load memberships for unread detection (only if not loaded yet)
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

    /// Refresh all memberships to get updated lastReadAt values
    /// Call this when returning to the community view after reading messages
    func refreshMemberships() {
        guard let uid = currentUid else { return }

        for conversation in conversations {
            Task {
                if let membership = try? await ChatService.shared.getMembership(
                    conversationId: conversation.id,
                    uid: uid
                ) {
                    await MainActor.run {
                        self.memberships[conversation.id] = membership
                        self.objectWillChange.send()
                    }
                }
            }
        }
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

// MARK: - Community Resident Row

struct CommunityResidentRow: View {
    let resident: RoompactResident
    let isLast: Bool
    @State private var showingDetail = false

    var body: some View {
        Button {
            showingDetail = true
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Avatar with initials
                    ZStack {
                        Circle()
                            .fill(avatarColor)
                            .frame(width: 48, height: 48)

                        Text(initials)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                    }

                    // Name and room
                    VStack(alignment: .leading, spacing: 3) {
                        Text(resident.name)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        if let room = resident.room, !room.isEmpty {
                            HStack(spacing: 6) {
                                Image(systemName: "door.left.hand.closed")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)

                                Text("Room \(room)")
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()

                    // Email button and chevron
                    HStack(spacing: 12) {
                        if let email = resident.email, !email.isEmpty {
                            Button {
                                if let url = URL(string: "mailto:\(email)") {
                                    UIApplication.shared.open(url)
                                }
                            } label: {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.blue)
                                    .frame(width: 32, height: 32)
                                    .background(Color.blue.opacity(0.12))
                                    .clipShape(Circle())
                            }
                        }

                        Image(systemName: "chevron.right")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !isLast {
                    Divider()
                        .padding(.leading, 78)
                }
            }
        }
        .sheet(isPresented: $showingDetail) {
            ResidentDetailSheet(resident: resident)
        }
    }

    private var initials: String {
        let names = resident.name.split(separator: " ")
        if names.count >= 2 {
            return "\(names[0].prefix(1))\(names[1].prefix(1))"
        }
        return String(resident.name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        let hash = resident.name.hashValue
        let index = ((hash % colors.count) + colors.count) % colors.count
        return colors[index]
    }
}

// MARK: - Resident Detail Sheet

struct ResidentDetailSheet: View {
    let resident: RoompactResident
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Profile header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(avatarColor)
                                .frame(width: 80, height: 80)

                            Text(initials)
                                .font(.system(size: 28, weight: .bold))
                                .foregroundColor(.white)
                        }

                        VStack(spacing: 4) {
                            Text(resident.name)
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.primary)

                            if let room = resident.room, !room.isEmpty {
                                Text("Room \(room)")
                                    .font(.system(size: 16))
                                    .foregroundColor(.secondary)
                            }

                            if let building = resident.building, !building.isEmpty {
                                Text(building)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.top, 20)

                    // Contact info
                    if let email = resident.email, !email.isEmpty {
                        VStack(spacing: 0) {
                            contactRow(icon: "envelope.fill", label: "Email", value: email, color: .blue) {
                                if let url = URL(string: "mailto:\(email)") {
                                    UIApplication.shared.open(url)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)

                        // Quick actions
                        Button {
                            if let url = URL(string: "mailto:\(email)") {
                                UIApplication.shared.open(url)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "envelope.fill")
                                    .font(.system(size: 16))
                                Text("Send Email")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .padding(.horizontal, 20)
                    }

                    Spacer()
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func contactRow(icon: String, label: String, value: String, color: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(value)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
    }

    private var initials: String {
        let names = resident.name.split(separator: " ")
        if names.count >= 2 {
            return "\(names[0].prefix(1))\(names[1].prefix(1))"
        }
        return String(resident.name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .orange, .green, .pink, .teal, .indigo]
        let hash = resident.name.hashValue
        let index = ((hash % colors.count) + colors.count) % colors.count
        return colors[index]
    }
}

#Preview {
    CommunityView()
        .environmentObject(AppState.shared)
        .environmentObject(PushNotificationService.shared)
}
