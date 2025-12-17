import SwiftUI

/// DEPRECATED: Authentication view - replaced by LandingView
/// This view is kept for compatibility but should not be used
struct OnboardingAuthView: View {
    @EnvironmentObject private var appState: AppState
    @EnvironmentObject private var firebaseAuth: FirebaseAuthManager

    var body: some View {
        // Redirect to LandingView (this view should not be shown)
        LandingView()
    }
}

#Preview {
    OnboardingAuthView()
        .environmentObject(AppState.shared)
        .environmentObject(FirebaseAuthManager.shared)
}

// MARK: - Email Verification View
// This is still used in the auth flow

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
