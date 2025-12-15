import SwiftUI

#if canImport(FirebaseFirestore)
import FirebaseFirestore
#endif

/// Full-screen settings view with Notion-style design
/// Displays real user data from Firebase
struct SettingsView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var roleManager: RoleManager
    @EnvironmentObject private var firebaseAuth: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var showSignOutConfirmation = false
    @State private var userData: UserData?
    @State private var isLoading = true

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    // Profile Header
                    profileHeader
                        .padding(.bottom, 32)

                    // Settings Sections
                    VStack(spacing: 24) {
                        accountSection
                        appSection
                        supportSection
                        signOutSection
                    }
                    .padding(.horizontal, 20)
                }
                .padding(.top, 20)
                .padding(.bottom, 40)
            }
            .background(Color(UIColor.systemGroupedBackground))
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .alert("Sign Out", isPresented: $showSignOutConfirmation) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    signOut()
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .task {
                await loadUserData()
            }
        }
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar
            ZStack {
                Circle()
                    .fill(roleColor.opacity(0.15))
                    .frame(width: 88, height: 88)

                Text(initials)
                    .font(.system(size: 32, weight: .semibold))
                    .foregroundColor(roleColor)
            }

            // Name and Email
            VStack(spacing: 4) {
                Text(displayName)
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.primary)

                Text(firebaseAuth.userEmail ?? "No email")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            // Role Badge
            HStack(spacing: 6) {
                Image(systemName: roleIcon)
                    .font(.system(size: 12, weight: .semibold))
                Text(roleDisplayName)
                    .font(.system(size: 13, weight: .semibold))
            }
            .foregroundColor(roleColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(roleColor.opacity(0.12))
            .cornerRadius(20)
        }
    }

    // MARK: - Account Section

    private var accountSection: some View {
        SettingsSection(title: "Account") {
            SettingsRow(
                icon: "envelope.fill",
                iconColor: .blue,
                title: "Email",
                value: firebaseAuth.userEmail ?? "Not set"
            )

            SettingsRow(
                icon: "person.badge.shield.checkmark.fill",
                iconColor: roleColor,
                title: "Role",
                value: roleDisplayName
            )

            if let hallId = userData?.hallId, !hallId.isEmpty {
                SettingsRow(
                    icon: "building.2.fill",
                    iconColor: .purple,
                    title: "Hall",
                    value: hallId == "hall-001" ? "Default Hall" : hallId
                )
            }

            if let tenantId = userData?.tenantId {
                SettingsRow(
                    icon: "building.columns.fill",
                    iconColor: .orange,
                    title: "Organization",
                    value: tenantId.uppercased()
                )
            }
        }
    }

    // MARK: - App Section

    private var appSection: some View {
        SettingsSection(title: "App") {
            SettingsRow(
                icon: "info.circle.fill",
                iconColor: .gray,
                title: "Version",
                value: appVersion
            )

            SettingsRow(
                icon: "checkmark.seal.fill",
                iconColor: firebaseAuth.isEmailVerified ? .green : .orange,
                title: "Email Verified",
                value: firebaseAuth.isEmailVerified ? "Yes" : "No"
            )
        }
    }

    // MARK: - Support Section

    private var supportSection: some View {
        SettingsSection(title: "Support") {
            SettingsLinkRow(
                icon: "questionmark.circle.fill",
                iconColor: .blue,
                title: "Help & FAQ"
            ) {
                // Future: Open help
            }

            SettingsLinkRow(
                icon: "envelope.badge.fill",
                iconColor: .green,
                title: "Contact Support"
            ) {
                // Future: Open support
            }

            SettingsLinkRow(
                icon: "doc.text.fill",
                iconColor: .gray,
                title: "Privacy Policy"
            ) {
                // Future: Open privacy policy
            }
        }
    }

    // MARK: - Sign Out Section

    private var signOutSection: some View {
        VStack(spacing: 0) {
            Button {
                showSignOutConfirmation = true
            } label: {
                HStack {
                    Image(systemName: "rectangle.portrait.and.arrow.right")
                        .font(.system(size: 17))
                    Text("Sign Out")
                        .font(.system(size: 17))
                    Spacer()
                }
                .foregroundColor(.red)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.secondarySystemGroupedBackground))
                .cornerRadius(12)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Computed Properties

    private var displayName: String {
        if let name = userData?.displayName, !name.isEmpty {
            return name
        }
        if let email = firebaseAuth.userEmail {
            return email.components(separatedBy: "@").first ?? "User"
        }
        return "User"
    }

    private var initials: String {
        let name = displayName
        let components = name.components(separatedBy: " ")
        if components.count >= 2 {
            let first = components[0].prefix(1)
            let last = components[1].prefix(1)
            return "\(first)\(last)".uppercased()
        }
        return String(name.prefix(2)).uppercased()
    }

    private var roleDisplayName: String {
        if let role = roleManager.selectedRole {
            return role.displayName
        }
        if let roleStr = userData?.role {
            switch roleStr {
            case "ra": return "Resident Advisor"
            case "staff": return "Staff"
            default: return "Resident"
            }
        }
        return "Resident"
    }

    private var roleIcon: String {
        if let role = roleManager.selectedRole {
            return role.icon
        }
        if let roleStr = userData?.role {
            switch roleStr {
            case "ra": return "shield.fill"
            default: return "person.fill"
            }
        }
        return "person.fill"
    }

    private var roleColor: Color {
        if let role = roleManager.selectedRole {
            switch role {
            case .ra: return .blue
            case .resident: return .green
            }
        }
        if let roleStr = userData?.role {
            switch roleStr {
            case "ra": return .blue
            default: return .green
            }
        }
        return .green
    }

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "\(version) (\(build))"
    }

    // MARK: - Data Loading

    private func loadUserData() async {
        guard let uid = firebaseAuth.currentUserId else {
            isLoading = false
            return
        }

        #if canImport(FirebaseFirestore)
        let db = Firestore.firestore()
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let data = doc.data() {
                userData = UserData(
                    email: data["email"] as? String ?? "",
                    displayName: data["displayName"] as? String ?? "",
                    role: data["role"] as? String ?? "resident",
                    hallId: data["hallId"] as? String ?? "",
                    tenantId: data["tenantId"] as? String ?? ""
                )
            }
        } catch {
            #if DEBUG
            print("⚙️ SETTINGS: Error loading user data: \(error)")
            #endif
        }
        #endif

        isLoading = false
    }

    // MARK: - Actions

    private func signOut() {
        do {
            try appState.signOut()
            dismiss()
        } catch {
            #if DEBUG
            print("⚙️ SETTINGS: Sign out error: \(error)")
            #endif
        }
    }
}

// MARK: - User Data Model

private struct UserData {
    let email: String
    let displayName: String
    let role: String
    let hallId: String
    let tenantId: String
}

// MARK: - Settings Section

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .padding(.horizontal, 16)

            VStack(spacing: 0) {
                content
            }
            .background(Color(UIColor.secondarySystemGroupedBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Settings Row

private struct SettingsRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let value: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 17))
                .foregroundColor(iconColor)
                .frame(width: 28)

            Text(title)
                .font(.system(size: 17))
                .foregroundColor(.primary)

            Spacer()

            Text(value)
                .font(.system(size: 17))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }
}

// MARK: - Settings Link Row

private struct SettingsLinkRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 17))
                    .foregroundColor(iconColor)
                    .frame(width: 28)

                Text(title)
                    .font(.system(size: 17))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(Color(UIColor.tertiaryLabel))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppState.shared)
        .environmentObject({
            let rm = RoleManager()
            rm.selectRole(.ra)
            return rm
        }())
        .environmentObject(FirebaseAuthManager.shared)
}
