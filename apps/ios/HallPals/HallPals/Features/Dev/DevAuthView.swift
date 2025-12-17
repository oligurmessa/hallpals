#if DEBUG
import SwiftUI

/// Debug-only view for testing Firebase Authentication
/// Only compiled in DEBUG builds
struct DevAuthView: View {
    @EnvironmentObject private var firebaseAuth: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss

    @State private var email = ""
    @State private var password = ""
    @State private var statusMessage = ""
    @State private var isSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                // Auth State Section
                Section("Current Auth State") {
                    if firebaseAuth.isAuthenticated {
                        VStack(alignment: .leading, spacing: 4) {
                            Label("Signed In", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text("UID: \(firebaseAuth.currentUserId ?? "unknown")")
                                .font(.caption)
                                .monospaced()
                            Text("Email: \(firebaseAuth.userEmail ?? "unknown")")
                                .font(.caption)
                        }
                    } else {
                        Label("Signed Out", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                }

                // Credentials Section
                Section("Credentials") {
                    TextField("Email", text: $email)
                        .textContentType(.emailAddress)
                        .keyboardType(.emailAddress)
                        .autocapitalization(.none)
                        .autocorrectionDisabled()

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                }

                // Actions Section
                Section("Actions") {
                    Button {
                        Task { await signUp() }
                    } label: {
                        Label("Sign Up", systemImage: "person.badge.plus")
                    }
                    .disabled(email.isEmpty || password.isEmpty || firebaseAuth.isLoading)

                    Button {
                        Task { await signIn() }
                    } label: {
                        Label("Sign In", systemImage: "arrow.right.circle")
                    }
                    .disabled(email.isEmpty || password.isEmpty || firebaseAuth.isLoading)

                    Button {
                        signOut()
                    } label: {
                        Label("Sign Out", systemImage: "arrow.left.circle")
                    }
                    .disabled(!firebaseAuth.isAuthenticated || firebaseAuth.isLoading)

                    Button {
                        Task { await resetPassword() }
                    } label: {
                        Label("Reset Password", systemImage: "key")
                    }
                    .disabled(email.isEmpty || firebaseAuth.isLoading)
                }

                // Status Section
                if !statusMessage.isEmpty {
                    Section("Status") {
                        Text(statusMessage)
                            .foregroundStyle(isSuccess ? .green : .red)
                            .font(.callout)
                    }
                }

                // Loading indicator
                if firebaseAuth.isLoading {
                    Section {
                        HStack {
                            Spacer()
                            ProgressView()
                            Spacer()
                        }
                    }
                }
            }
            .navigationTitle("Dev Auth")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func signUp() async {
        statusMessage = ""
        do {
            try await firebaseAuth.signUp(email: email, password: password)
            statusMessage = "Sign up successful! UID: \(firebaseAuth.currentUserId ?? "?")"
            isSuccess = true
        } catch {
            statusMessage = "Sign up failed: \(error.localizedDescription)"
            isSuccess = false
        }
    }

    private func signIn() async {
        statusMessage = ""
        do {
            try await firebaseAuth.signIn(email: email, password: password)
            statusMessage = "Sign in successful!"
            isSuccess = true
        } catch {
            statusMessage = "Sign in failed: \(error.localizedDescription)"
            isSuccess = false
        }
    }

    private func signOut() {
        statusMessage = ""
        do {
            try firebaseAuth.signOut()
            statusMessage = "Signed out successfully"
            isSuccess = true
        } catch {
            statusMessage = "Sign out failed: \(error.localizedDescription)"
            isSuccess = false
        }
    }

    private func resetPassword() async {
        statusMessage = ""
        do {
            try await firebaseAuth.sendPasswordReset(email: email)
            statusMessage = "Password reset email sent to \(email)"
            isSuccess = true
        } catch {
            statusMessage = "Reset failed: \(error.localizedDescription)"
            isSuccess = false
        }
    }
}

#Preview {
    DevAuthView()
        .environmentObject(FirebaseAuthManager.shared)
}
#endif
