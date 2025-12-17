import SwiftUI

/// Modern landing page with HallPals branding
/// Sleek, minimal design with logo and auth options
struct LandingView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var firebaseAuth: FirebaseAuthManager

    @State private var showAuthSheet = false
    @State private var isSignUp = false

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                colors: [
                    Color(UIColor.systemBackground),
                    Color(UIColor.systemGray6)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo and branding
                brandingSection
                    .padding(.bottom, 60)

                Spacer()

                // Auth buttons
                authButtonsSection
                    .padding(.horizontal, 24)
                    .padding(.bottom, 40)

                // Footer
                footerSection
                    .padding(.bottom, 20)
            }
        }
        .sheet(isPresented: $showAuthSheet) {
            AuthSheetView(isSignUp: isSignUp)
        }
    }

    // MARK: - Branding Section

    private var brandingSection: some View {
        VStack(spacing: 20) {
            // App Logo
            Image("HallPalsLogo")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 120, height: 120)
                .clipShape(RoundedRectangle(cornerRadius: 28))
                .shadow(color: Color.black.opacity(0.1), radius: 20, x: 0, y: 10)

            // App name
            Text("HallPals")
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            // Tagline
            Text("Your residence life companion")
                .font(.system(size: 17, weight: .regular))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Auth Buttons

    private var authButtonsSection: some View {
        VStack(spacing: 14) {
            // Sign In button
            Button {
                isSignUp = false
                showAuthSheet = true
            } label: {
                Text("Sign In")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.appPrimary)
                    .cornerRadius(14)
            }

            // Create Account button
            Button {
                isSignUp = true
                showAuthSheet = true
            } label: {
                Text("Create Account")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.appPrimary)
                    .frame(maxWidth: .infinity)
                    .frame(height: 54)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(14)
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        Text("University of St. Thomas Residence Life")
            .font(.system(size: 13))
            .foregroundColor(.secondary)
    }
}

// MARK: - Auth Sheet View

struct AuthSheetView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var firebaseAuth: FirebaseAuthManager
    @Environment(\.dismiss) private var dismiss

    let isSignUp: Bool

    @State private var email = ""
    @State private var password = ""
    @State private var firstName = ""
    @State private var lastName = ""
    @State private var localError: String?
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var showResetConfirmation = false

    @FocusState private var focusedField: Field?

    private enum Field {
        case firstName, lastName, email, password
    }

    private var effectiveError: String? {
        localError ?? appState.errorMessage ?? firebaseAuth.errorMessage
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .padding(.top, 8)

                    // Form fields
                    formSection

                    // Error
                    if let error = effectiveError {
                        errorView(error)
                    }

                    // Submit button
                    submitButton

                    // Forgot password (sign in only)
                    if !isSignUp {
                        forgotPasswordButton
                    }

                    Spacer(minLength: 40)
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
            .sheet(isPresented: $showResetPassword) {
                resetPasswordSheet
            }
            .alert("Password Reset Sent", isPresented: $showResetConfirmation) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Check your email for a password reset link.")
            }
        }
        .presentationDragIndicator(.visible)
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 8) {
            Text(isSignUp ? "Create Account" : "Welcome Back")
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.primary)

            Text(isSignUp ? "Join your residence hall community" : "Sign in to continue")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Form

    private var formSection: some View {
        VStack(spacing: 16) {
            // Name fields (signup only)
            if isSignUp {
                HStack(spacing: 12) {
                    // First name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("First Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("First", text: $firstName)
                            .textContentType(.givenName)
                            .autocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .firstName)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }

                    // Last name
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Last Name")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)

                        TextField("Last", text: $lastName)
                            .textContentType(.familyName)
                            .autocapitalization(.words)
                            .autocorrectionDisabled()
                            .focused($focusedField, equals: .lastName)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                    }
                }
            }

            // Email field
            VStack(alignment: .leading, spacing: 6) {
                Text("Email")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                TextField("you@stthomas.edu", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .email)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }

            // Password field
            VStack(alignment: .leading, spacing: 6) {
                Text("Password")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                SecureField("Min. 6 characters", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .focused($focusedField, equals: .password)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.circle.fill")
                .font(.system(size: 16))
                .foregroundColor(.red)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.red)

            Spacer()
        }
        .padding(12)
        .background(Color.red.opacity(0.1))
        .cornerRadius(10)
    }

    // MARK: - Submit Button

    private var submitButton: some View {
        Button {
            Task { await submitAuth() }
        } label: {
            Group {
                if firebaseAuth.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text(isSignUp ? "Create Account" : "Sign In")
                }
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(isFormValid ? Color.appPrimary : Color.gray.opacity(0.5))
            .cornerRadius(14)
        }
        .disabled(!isFormValid || firebaseAuth.isLoading)
    }

    // MARK: - Forgot Password

    private var forgotPasswordButton: some View {
        Button {
            resetEmail = email
            showResetPassword = true
        } label: {
            Text("Forgot Password?")
                .font(.system(size: 15))
                .foregroundColor(.appPrimary)
        }
    }

    // MARK: - Reset Password Sheet

    private var resetPasswordSheet: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)

                TextField("Email", text: $resetEmail)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)

                Button {
                    Task { await sendReset() }
                } label: {
                    Text("Send Reset Link")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(resetEmail.isEmpty ? Color.gray.opacity(0.5) : Color.appPrimary)
                        .cornerRadius(14)
                }
                .disabled(resetEmail.isEmpty || firebaseAuth.isLoading)

                Spacer()
            }
            .padding(24)
            .navigationTitle("Reset Password")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        showResetPassword = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    // MARK: - Validation

    private var isFormValid: Bool {
        if isSignUp {
            return !firstName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !lastName.trimmingCharacters(in: .whitespaces).isEmpty &&
                   !email.isEmpty &&
                   password.count >= 6
        } else {
            return !email.isEmpty && password.count >= 6
        }
    }

    // MARK: - Actions

    private func submitAuth() async {
        localError = nil
        focusedField = nil

        do {
            if isSignUp {
                let displayName = "\(firstName.trimmingCharacters(in: .whitespaces)) \(lastName.trimmingCharacters(in: .whitespaces))"
                try await appState.signUp(email: email, password: password, displayName: displayName)
            } else {
                try await appState.signIn(email: email, password: password)
            }
            dismiss()
        } catch {
            localError = error.localizedDescription
        }
    }

    private func sendReset() async {
        do {
            try await appState.sendPasswordReset(email: resetEmail)
            showResetPassword = false
            showResetConfirmation = true
        } catch {
            // Error shown in sheet
        }
    }
}

#Preview("Landing") {
    LandingView()
        .environmentObject(AppState.shared)
        .environmentObject(FirebaseAuthManager.shared)
}

#Preview("Auth Sheet - Sign In") {
    AuthSheetView(isSignUp: false)
        .environmentObject(AppState.shared)
        .environmentObject(FirebaseAuthManager.shared)
}

#Preview("Auth Sheet - Sign Up") {
    AuthSheetView(isSignUp: true)
        .environmentObject(AppState.shared)
        .environmentObject(FirebaseAuthManager.shared)
}
