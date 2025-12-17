import SwiftUI

/// Result passed to parent when a conversation is created
struct CreatedConversationResult {
    let conversationId: String
    let conversationType: ChatService.Conversation.ConversationType
    let title: String
}

/// Modern view for creating new conversations (DM or Group)
struct CreateConversationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    /// Callback when conversation is created - parent handles navigation (single source of truth)
    var onConversationCreated: ((CreatedConversationResult) -> Void)?

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var groupTitle = ""
    @State private var selectedUsers: [SelectedUser] = []
    @State private var allHallUsers: [SelectedUser] = []
    @State private var isLoadingUsers = false
    @State private var isCreating = false
    @State private var error: String?

    struct SelectedUser: Identifiable, Hashable {
        let id: String
        let displayName: String
        let email: String?
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Tab picker
                segmentedPicker
                    .padding(.horizontal, 16)
                    .padding(.top, 12)

                // Content
                if selectedTab == 0 {
                    dmContent
                } else {
                    groupContent
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("New Message")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                loadHallUsers()
            }
        }
    }

    // MARK: - Load Tenant Users

    private func loadHallUsers() {
        guard allHallUsers.isEmpty else { return }

        isLoadingUsers = true

        Task {
            let currentUid = appState.currentUserId ?? ""

            #if DEBUG
            print("🔍 CHAT: Loading tenant users via Cloud Function")
            #endif

            do {
                // Use tenant-wide search to find all users in the organization
                let users = try await ChatService.shared.getTenantUsers(excludeUid: currentUid)

                await MainActor.run {
                    self.allHallUsers = users.map { user in
                        SelectedUser(id: user.uid, displayName: user.displayName, email: user.email)
                    }
                    self.isLoadingUsers = false

                    #if DEBUG
                    print("🔍 CHAT: Loaded \(self.allHallUsers.count) tenant users")
                    for user in self.allHallUsers {
                        print("🔍 CHAT:   - \(user.displayName) (\(user.email ?? "no email"))")
                    }
                    #endif
                }
            } catch {
                #if DEBUG
                print("🔍 CHAT: Failed to load tenant users: \(error)")
                #endif
                await MainActor.run {
                    self.isLoadingUsers = false
                    self.error = "Unable to load users. Please try again."
                }
            }
        }
    }

    // MARK: - Segmented Picker

    private var segmentedPicker: some View {
        HStack(spacing: 0) {
            ForEach(["Direct Message", "Group Chat"].indices, id: \.self) { index in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selectedTab = index
                        selectedUsers.removeAll()
                        searchText = ""
                    }
                } label: {
                    Text(index == 0 ? "Direct Message" : "Group Chat")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(selectedTab == index ? .white : .secondary)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(
                            selectedTab == index
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

    // MARK: - Filtered Users

    /// Filter users based on search text (local filtering)
    private var filteredUsers: [SelectedUser] {
        let selectedIds = Set(selectedUsers.map { $0.id })
        let baseUsers = selectedTab == 0 ? allHallUsers : allHallUsers.filter { !selectedIds.contains($0.id) }

        guard !searchText.isEmpty else { return baseUsers }
        let query = searchText.lowercased()
        return baseUsers.filter { $0.displayName.lowercased().contains(query) || ($0.email?.lowercased().contains(query) ?? false) }
    }

    // MARK: - DM Content

    private var dmContent: some View {
        VStack(spacing: 0) {
            searchField

            if let user = selectedUsers.first {
                selectedUserBadge(user: user)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            if selectedUsers.isEmpty {
                usersContentView(users: filteredUsers)
            }

            Spacer()
            errorBannerIfNeeded
            createButton(title: "Start Chat")
        }
    }

    // MARK: - Group Content

    private var groupContent: some View {
        VStack(spacing: 0) {
            groupNameField
            searchField

            if !selectedUsers.isEmpty {
                selectedUsersRow
            }

            if selectedUsers.isEmpty || !filteredUsers.isEmpty {
                usersContentView(users: filteredUsers)
            }

            Spacer()
            errorBannerIfNeeded
            createButton(title: "Create Group")
        }
    }

    // MARK: - Shared Components

    /// Displays loading, empty, or user list based on state
    /// Only shows results when user is actively searching
    @ViewBuilder
    private func usersContentView(users: [SelectedUser]) -> some View {
        if searchText.isEmpty {
            // Show hint when not searching
            searchHint
        } else if isLoadingUsers {
            loadingView
        } else if users.isEmpty {
            noResultsView
        } else {
            usersList(users: users)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading people...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .padding(.top, 40)
    }

    private var noResultsView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No users found")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Text("Try a different name or email")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.top, 40)
    }

    private var emptyHallView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            Text("No users found")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
            Text("No one else has signed up yet")
                .font(.system(size: 14))
                .foregroundColor(.secondary.opacity(0.7))
        }
        .padding(.top, 40)
    }

    @ViewBuilder
    private var errorBannerIfNeeded: some View {
        if let error = error {
            errorBanner(error)
        }
    }

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            TextField("Search by name or email...", text: $searchText)
                .font(.system(size: 16))
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    /// Unified user list view
    private func usersList(users: [SelectedUser]) -> some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(users) { user in
                    Button { selectUser(user) } label: {
                        userRow(user: user, showCheckmark: selectedTab == 1 && selectedUsers.contains { $0.id == user.id })
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: selectedTab == 0 ? 350 : 300)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func userRow(user: SelectedUser, showCheckmark: Bool = false) -> some View {
        HStack(spacing: 12) {
            // Avatar
            ZStack {
                Circle()
                    .fill(avatarGradient(for: user.displayName))
                    .frame(width: 44, height: 44)

                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                if let email = user.email {
                    Text(email)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Selection indicator
            if showCheckmark {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(.green)
            } else {
                Image(systemName: "plus.circle")
                    .font(.system(size: 22))
                    .foregroundColor(.blue)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.systemBackground))
    }

    private func avatarGradient(for name: String) -> LinearGradient {
        let colors: [(Color, Color)] = [
            (.blue, .cyan),
            (.purple, .pink),
            (.orange, .red),
            (.green, .mint),
            (.indigo, .purple)
        ]
        let hash = abs(name.hashValue)
        let index = hash % colors.count
        return LinearGradient(
            colors: [colors[index].0, colors[index].1],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var groupNameField: some View {
        HStack(spacing: 12) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            TextField("Group name", text: $groupTitle)
                .font(.system(size: 16))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 16)
    }

    private func selectedUserBadge(user: SelectedUser) -> some View {
        HStack(spacing: 10) {
            ZStack {
                Circle()
                    .fill(avatarGradient(for: user.displayName))
                    .frame(width: 40, height: 40)

                Text(String(user.displayName.prefix(1)).uppercased())
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(user.displayName)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.primary)

                if let email = user.email {
                    Text(email)
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Button {
                selectedUsers.removeAll { $0.id == user.id }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.system(size: 22))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var selectedUsersRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(selectedUsers) { user in
                    HStack(spacing: 6) {
                        Text(user.displayName)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)

                        Button {
                            withAnimation {
                                selectedUsers.removeAll { $0.id == user.id }
                            }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 16))
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 12)
    }

    private var searchHint: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)

                Image(systemName: selectedTab == 0 ? "person.fill" : "person.3.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 6) {
                Text(selectedTab == 0 ? "Find Someone" : "Add Members")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                Text(selectedTab == 0
                     ? "Search by name or email to start a conversation"
                     : "Search by name or email to add people")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.top, 60)
        .padding(.horizontal, 40)
    }

    private func errorBanner(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 14))
                .foregroundColor(.orange)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.primary)

            Spacer()
        }
        .padding(12)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(10)
        .padding(.horizontal, 16)
        .padding(.bottom, 8)
    }

    private func createButton(title: String) -> some View {
        Button {
            Task {
                await createConversation()
            }
        } label: {
            HStack(spacing: 8) {
                if isCreating {
                    ProgressView()
                        .tint(.white)
                } else {
                    Image(systemName: selectedTab == 0 ? "paperplane.fill" : "plus.circle.fill")
                        .font(.system(size: 16))
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(isFormValid ? Color.blue : Color(UIColor.systemGray4))
            .cornerRadius(14)
        }
        .disabled(!isFormValid || isCreating)
        .padding(.horizontal, 16)
        .padding(.bottom, 16)
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        if selectedTab == 0 {
            return selectedUsers.count == 1
        } else {
            return !groupTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                   !selectedUsers.isEmpty
        }
    }

    // MARK: - Actions

    private func selectUser(_ user: SelectedUser) {
        // Don't add duplicates
        guard !selectedUsers.contains(where: { $0.id == user.id }) else {
            return
        }

        // For DM, only allow one user
        if selectedTab == 0 {
            selectedUsers = [user]
            searchText = ""
        } else {
            selectedUsers.append(user)
        }
    }

    private func createConversation() async {
        isCreating = true
        error = nil

        do {
            let result: CreatedConversationResult

            if selectedTab == 0 {
                // Create DM
                guard let user = selectedUsers.first else { return }
                let conversationId = try await ChatService.shared.createOrGetDM(otherUid: user.id)
                result = CreatedConversationResult(
                    conversationId: conversationId,
                    conversationType: .dm,
                    title: user.displayName
                )
            } else {
                // Create Group
                let title = groupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let uids = selectedUsers.map { $0.id }

                let conversationId = try await ChatService.shared.createGroupConversation(
                    title: title,
                    memberUids: uids
                )
                result = CreatedConversationResult(
                    conversationId: conversationId,
                    conversationType: .group,
                    title: title
                )
            }

            isCreating = false

            // Dismiss sheet and notify parent to navigate
            // Parent's NavigationStack is the single source of truth
            dismiss()
            onConversationCreated?(result)
        } catch {
            self.error = error.localizedDescription
            isCreating = false
        }
    }
}

#Preview {
    CreateConversationView()
        .environmentObject(AppState.shared)
}
