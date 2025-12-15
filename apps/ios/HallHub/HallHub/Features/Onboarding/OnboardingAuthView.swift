import SwiftUI

/// Authentication view with email/password and Microsoft sign-in
struct OnboardingAuthView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var firebaseAuth: FirebaseAuthManager

    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var showResetPassword = false
    @State private var resetEmail = ""
    @State private var showResetConfirmation = false
    @State private var localError: String?

    private var effectiveError: String? {
        localError ?? appState.errorMessage ?? firebaseAuth.errorMessage
    }

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.xl) {
                // Header with back button
                header

                // Role indicator
                if let role = appState.pendingRole {
                    roleIndicator(role)
                }

                // Auth form
                authForm

                // Microsoft sign-in temporarily disabled
                // TODO: Re-enable when Microsoft provider is configured in Firebase Console
                // dividerWithText("or")
                // microsoftSignInButton

                Spacer(minLength: 40)
            }
            .padding(.horizontal, AppSpacing.lg)
            .padding(.top, AppSpacing.lg)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .sheet(isPresented: $showResetPassword) {
            resetPasswordSheet
        }
        .alert("Password Reset Sent", isPresented: $showResetConfirmation) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Check your email for a password reset link.")
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack {
            Button {
                appState.goBackToRoleSelection()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 14, weight: .semibold))
                    Text("Back")
                        .font(.system(size: 16, weight: .medium))
                }
                .foregroundColor(.appPrimary)
            }
            Spacer()
        }
    }

    // MARK: - Role Indicator

    private func roleIndicator(_ role: UserRole) -> some View {
        HStack(spacing: AppSpacing.sm) {
            Image(systemName: role.icon)
                .font(.system(size: 20))
                .foregroundColor(.appPrimary)

            Text("Signing in as \(role.shortName)")
                .appStyle(.body, color: .textSecondary)
        }
        .padding(.vertical, AppSpacing.sm)
        .padding(.horizontal, AppSpacing.md)
        .background(Color.appPrimary.opacity(0.1))
        .cornerRadius(AppRadius.chip)
    }

    // MARK: - Auth Form

    private var authForm: some View {
        VStack(spacing: AppSpacing.md) {
            // Title
            Text(isSignUp ? "Create Account" : "Sign In")
                .appStyle(.titleMedium)
                .frame(maxWidth: .infinity, alignment: .leading)

            // Email field
            VStack(alignment: .leading, spacing: 4) {
                Text("Email")
                    .appStyle(.label, color: .textSecondary)

                TextField("you@example.com", text: $email)
                    .textContentType(.emailAddress)
                    .keyboardType(.emailAddress)
                    .autocapitalization(.none)
                    .autocorrectionDisabled()
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }

            // Password field
            VStack(alignment: .leading, spacing: 4) {
                Text("Password")
                    .appStyle(.label, color: .textSecondary)

                SecureField("Password", text: $password)
                    .textContentType(isSignUp ? .newPassword : .password)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }

            // Error message
            if let error = effectiveError {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Submit button
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
                .frame(height: 50)
                .background(isFormValid ? Color.appPrimary : Color.gray)
                .cornerRadius(12)
            }
            .disabled(!isFormValid || firebaseAuth.isLoading)

            // Toggle and forgot password
            HStack {
                Button {
                    withAnimation {
                        isSignUp.toggle()
                        localError = nil
                    }
                } label: {
                    Text(isSignUp ? "Already have an account? Sign In" : "Don't have an account? Sign Up")
                        .font(.system(size: 14))
                        .foregroundColor(.appPrimary)
                }

                Spacer()

                if !isSignUp {
                    Button {
                        resetEmail = email
                        showResetPassword = true
                    } label: {
                        Text("Forgot Password?")
                            .font(.system(size: 14))
                            .foregroundColor(.textSecondary)
                    }
                }
            }
        }
    }

    // MARK: - Divider

    private func dividerWithText(_ text: String) -> some View {
        HStack {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)

            Text(text)
                .font(.system(size: 14))
                .foregroundColor(.textSecondary)
                .padding(.horizontal, 8)

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(height: 1)
        }
    }

    // MARK: - Microsoft Sign-In

    private var microsoftSignInButton: some View {
        Button {
            Task { await signInWithMicrosoft() }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: "building.columns.fill")
                    .font(.system(size: 20))

                Text("Sign in with Microsoft")
                    .font(.system(size: 17, weight: .medium))
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
            )
        }
        .disabled(firebaseAuth.isLoading)
    }

    // MARK: - Reset Password Sheet

    private var resetPasswordSheet: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Text("Enter your email address and we'll send you a link to reset your password.")
                    .appStyle(.body, color: .textSecondary)
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
                        .frame(height: 50)
                        .background(resetEmail.isEmpty ? Color.gray : Color.appPrimary)
                        .cornerRadius(12)
                }
                .disabled(resetEmail.isEmpty || firebaseAuth.isLoading)

                Spacer()
            }
            .padding()
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

    // MARK: - Helpers

    private var isFormValid: Bool {
        !email.isEmpty && !password.isEmpty && password.count >= 6
    }

    private func submitAuth() async {
        localError = nil
        do {
            if isSignUp {
                try await appState.signUp(email: email, password: password)
            } else {
                try await appState.signIn(email: email, password: password)
            }
        } catch {
            localError = error.localizedDescription
        }
    }

    private func signInWithMicrosoft() async {
        localError = nil
        do {
            try await appState.signInWithMicrosoft()
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
            // Error is shown in the sheet
        }
    }
}

#Preview {
    OnboardingAuthView()
        .environmentObject(AppState.shared)
        .environmentObject(FirebaseAuthManager.shared)
}

// MARK: - Email Verification View
// Added here to ensure availability in the current Xcode target

struct EmailVerificationView: View {
    @EnvironmentObject private var firebaseAuth: FirebaseAuthManager
    @EnvironmentObject private var appState: AppState
    @Environment(\.scenePhase) private var scenePhase

    @State private var isSending = false
    @State private var isChecking = false
    @State private var message: String?
    @State private var isError = false
    @State private var resendCooldown: Int = 0  // Seconds remaining before resend allowed

    var body: some View {
        VStack(spacing: AppSpacing.xl) {
            Spacer()

            // Icon
            Image(systemName: "envelope.badge.shield.half.filled")
                .font(.system(size: 80))
                .foregroundColor(.appPrimary)

            // Title
            Text("Verify Your Email")
                .appStyle(.titleLarge)

            // Description
            VStack(spacing: AppSpacing.sm) {
                Text("We've sent a verification link to:")
                    .appStyle(.body, color: .textSecondary)

                Text(firebaseAuth.userEmail ?? "your email")
                    .appStyle(.body)
                    .fontWeight(.semibold)

                Text("Please check your inbox (and spam folder) and click the link to verify your account.")
                    .appStyle(.body, color: .textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.top, AppSpacing.sm)
            }
            .padding(.horizontal)

            // Message area
            if let message = message {
                Text(message)
                    .appStyle(.caption, color: isError ? .red : .green)
                    .multilineTextAlignment(.center)
            }

            Spacer()

            // Actions
            VStack(spacing: AppSpacing.md) {
                // I have verified button
                Button {
                    Task { await checkVerification() }
                } label: {
                    if isChecking {
                        ProgressView()
                            .tint(.white)
                    } else {
                        Text("I've verified my email")
                    }
                }
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(Color.appPrimary)
                .cornerRadius(12)
                .disabled(isChecking)

                // Resend button with cooldown
                Button {
                    Task { await resendVerification() }
                } label: {
                    if isSending {
                        ProgressView()
                    } else if resendCooldown > 0 {
                        Text("Resend in \(resendCooldown)s")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.gray)
                    } else {
                        Text("Resend Verification Email")
                            .font(.system(size: 17, weight: .medium))
                            .foregroundColor(.appPrimary)
                    }
                }
                .disabled(isSending || resendCooldown > 0)

                // Sign Out
                Button {
                    try? appState.signOut()
                } label: {
                    Text("Sign Out")
                        .font(.system(size: 14))
                        .foregroundColor(.textSecondary)
                }
                .padding(.top, AppSpacing.sm)
            }
            .padding(.bottom, AppSpacing.xl)
        }
        .padding(.horizontal, AppSpacing.lg)
        .background(Color.appBackground)
        // Auto-check when app returns to foreground (user may have clicked link in email)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                Task { await checkVerification() }
            }
        }
    }

    private func checkVerification() async {
        isError = false
        isChecking = true
        message = "Checking verification status..."

        do {
            let verified = try await firebaseAuth.reloadUser()

            if verified {
                message = "Verified! Redirecting..."
                // IMPORTANT: Firebase auth listener does NOT fire on email verification
                // We must manually transition the state
                try await Task.sleep(nanoseconds: 500_000_000) // Brief delay for UX
                appState.markEmailVerified()
            } else {
                isError = true
                message = "Email not verified yet. Please click the link in your email."
            }
        } catch {
            isError = true
            message = error.localizedDescription
        }

        isChecking = false
    }

    private func resendVerification() async {
        isSending = true
        message = nil

        do {
            try await firebaseAuth.sendEmailVerification()
            isError = false
            message = "Verification email sent!"
            startResendCooldown()
        } catch {
            isError = true
            message = error.localizedDescription
        }

        isSending = false
    }

    /// Starts a 30-second cooldown before allowing another resend
    private func startResendCooldown() {
        resendCooldown = 30
        Task {
            while resendCooldown > 0 {
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                await MainActor.run {
                    resendCooldown -= 1
                }
            }
        }
    }
}
