import SwiftUI
import FirebaseFirestore

/// Modern view for creating new conversations (DM or Group)
struct CreateConversationView: View {
    @EnvironmentObject private var appState: AppState
    @Environment(\.dismiss) private var dismiss

    @State private var selectedTab = 0
    @State private var searchText = ""
    @State private var groupTitle = ""
    @State private var selectedUsers: [SelectedUser] = []
    @State private var searchResults: [SelectedUser] = []
    @State private var isSearching = false
    @State private var isLoading = false
    @State private var error: String?
    @State private var createdConversationId: String?
    @State private var searchTask: Task<Void, Never>?
    @FocusState private var isSearchFocused: Bool

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
            .navigationDestination(item: $createdConversationId) { conversationId in
                ChatThreadView(
                    conversationId: conversationId,
                    conversationType: selectedTab == 0 ? .dm : .group,
                    title: selectedTab == 0 ? (selectedUsers.first?.displayName ?? "Chat") : groupTitle
                )
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

    // MARK: - DM Content

    private var dmContent: some View {
        VStack(spacing: 0) {
            // Search field
            searchField

            // Selected user (if any)
            if let user = selectedUsers.first {
                selectedUserBadge(user: user)
                    .padding(.horizontal, 16)
                    .padding(.top, 12)
            }

            // Content below search field
            if selectedUsers.isEmpty {
                if isSearching {
                    // Loading indicator while searching
                    ProgressView()
                        .padding(.top, 40)
                } else if !searchResults.isEmpty {
                    // Show search results
                    searchResultsList
                } else if searchText.count >= 2 {
                    // No results found
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
                } else {
                    // Search hint (when search text is empty or < 2 chars)
                    searchHint
                }
            }

            Spacer()

            // Error message
            if let error = error {
                errorBanner(error)
            }

            // Create button
            createButton(title: "Start Chat")
        }
    }

    // MARK: - Group Content

    private var groupContent: some View {
        VStack(spacing: 0) {
            // Group name field
            groupNameField

            // Search field for members
            searchField

            // Selected users
            if !selectedUsers.isEmpty {
                selectedUsersRow
            }

            // Content below search field
            if isSearching {
                // Loading indicator while searching
                ProgressView()
                    .padding(.top, 40)
            } else if !searchResults.isEmpty {
                // Show search results
                searchResultsList
            } else if searchText.count >= 2 {
                // No results found
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
            } else if selectedUsers.isEmpty {
                // Search hint (when search text is empty or < 2 chars)
                searchHint
            }

            Spacer()

            // Error message
            if let error = error {
                errorBanner(error)
            }

            // Create button
            createButton(title: "Create Group")
        }
    }

    // MARK: - Components

    private var searchField: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            TextField("Search by name or email...", text: $searchText)
                .font(.system(size: 16))
                .focused($isSearchFocused)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    performSearch(query: newValue)
                }

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                    searchResults = []
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

    private var searchResultsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(searchResults) { user in
                    Button {
                        selectUser(user)
                    } label: {
                        searchResultRow(user: user)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxHeight: 300)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }

    private func searchResultRow(user: SelectedUser) -> some View {
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

            // Already selected indicator
            if selectedUsers.contains(where: { $0.id == user.id }) {
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
                if isLoading {
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
        .disabled(!isFormValid || isLoading)
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

    private func performSearch(query: String) {
        // Cancel previous search
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)

        // Clear results if query is too short
        guard trimmed.count >= 2 else {
            searchResults = []
            isSearching = false
            return
        }

        isSearching = true

        // Debounce search
        searchTask = Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 300ms debounce

            guard !Task.isCancelled else { return }

            await searchUsers(query: trimmed)
        }
    }

    private func searchUsers(query: String) async {
        let db = Firestore.firestore()
        let currentUid = appState.currentUserId ?? ""

        #if DEBUG
        print("🔍 SEARCH: Starting search for '\(query)' (currentUid: \(currentUid))")
        #endif

        do {
            // Multiple search strategies for better results:
            // 1. Capitalized name (e.g., "John")
            // 2. Lowercase name (e.g., "john")
            // 3. As-typed (preserves case)
            // 4. Email prefix match (lowercase)

            let capitalizedQuery = query.prefix(1).uppercased() + query.dropFirst().lowercased()
            let lowercaseQuery = query.lowercased()

            // Search by displayName with capitalized first letter
            let nameCapQuery = db.collection("users")
                .whereField("displayName", isGreaterThanOrEqualTo: capitalizedQuery)
                .whereField("displayName", isLessThan: capitalizedQuery + "\u{f8ff}")
                .limit(to: 10)

            // Search by displayName as-typed
            let nameAsTypedQuery = db.collection("users")
                .whereField("displayName", isGreaterThanOrEqualTo: query)
                .whereField("displayName", isLessThan: query + "\u{f8ff}")
                .limit(to: 10)

            // Search by email (lowercase)
            let emailQuery = db.collection("users")
                .whereField("email", isGreaterThanOrEqualTo: lowercaseQuery)
                .whereField("email", isLessThan: lowercaseQuery + "\u{f8ff}")
                .limit(to: 10)

            // Run all queries in parallel
            async let nameCapResults = nameCapQuery.getDocuments()
            async let nameAsTypedResults = nameAsTypedQuery.getDocuments()
            async let emailResults = emailQuery.getDocuments()

            let (nameCapSnapshot, nameAsTypedSnapshot, emailSnapshot) = try await (nameCapResults, nameAsTypedResults, emailResults)

            #if DEBUG
            print("🔍 SEARCH: Found \(nameCapSnapshot.documents.count) cap, \(nameAsTypedSnapshot.documents.count) as-typed, \(emailSnapshot.documents.count) email results")
            #endif

            var users: [SelectedUser] = []
            var seenIds = Set<String>()

            // Helper to process documents
            func processDocuments(_ documents: [QueryDocumentSnapshot]) {
                for doc in documents {
                    let uid = doc.documentID
                    guard uid != currentUid, !seenIds.contains(uid) else { continue }
                    seenIds.insert(uid)

                    let data = doc.data()
                    let displayName = data["displayName"] as? String ?? uid
                    let email = data["email"] as? String

                    users.append(SelectedUser(id: uid, displayName: displayName, email: email))
                }
            }

            // Process all results
            processDocuments(nameCapSnapshot.documents)
            processDocuments(nameAsTypedSnapshot.documents)
            processDocuments(emailSnapshot.documents)

            #if DEBUG
            print("🔍 SEARCH: Total unique users: \(users.count)")
            for user in users {
                print("🔍 SEARCH:   - \(user.displayName) (\(user.email ?? "no email"))")
            }
            #endif

            await MainActor.run {
                self.searchResults = users
                self.isSearching = false
            }
        } catch {
            #if DEBUG
            print("🔍 SEARCH ERROR: \(error.localizedDescription)")
            print("🔍 SEARCH ERROR details: \(error)")
            #endif
            await MainActor.run {
                self.searchResults = []
                self.isSearching = false
            }
        }
    }

    private func selectUser(_ user: SelectedUser) {
        // Don't add duplicates
        guard !selectedUsers.contains(where: { $0.id == user.id }) else {
            return
        }

        // For DM, only allow one user
        if selectedTab == 0 {
            selectedUsers = [user]
            searchText = ""
            searchResults = []
        } else {
            selectedUsers.append(user)
        }
    }

    private func createConversation() async {
        isLoading = true
        error = nil

        do {
            if selectedTab == 0 {
                // Create DM
                guard let user = selectedUsers.first else { return }
                let conversationId = try await ChatService.shared.createOrGetDM(otherUid: user.id)
                createdConversationId = conversationId
            } else {
                // Create Group
                let title = groupTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                let uids = selectedUsers.map { $0.id }

                let conversationId = try await ChatService.shared.createGroupConversation(
                    title: title,
                    memberUids: uids
                )
                createdConversationId = conversationId
            }
        } catch {
            self.error = error.localizedDescription
        }

        isLoading = false
    }
}

#Preview {
    CreateConversationView()
        .environmentObject(AppState.shared)
}
