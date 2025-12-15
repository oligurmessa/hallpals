import SwiftUI

/// First step of onboarding: Role selection with code verification
/// Residents proceed directly; RA/Staff require access codes
struct OnboardingRoleView: View {
    @EnvironmentObject private var appState: AppState

    @State private var selectedRole: UserRole?
    @State private var codeInput: String = ""
    @State private var showCodeEntry: Bool = false
    @State private var showError: Bool = false
    @State private var isAnimating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            Spacer()

            // Logo and Title
            VStack(spacing: AppSpacing.md) {
                Image(systemName: "building.2.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.appPrimary)

                Text("HallPals")
                    .appStyle(.titleLarge)

                Text("University of St. Thomas Residence Life")
                    .appStyle(.caption, color: .textSecondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.bottom, AppSpacing.xl)

            if showCodeEntry, let role = selectedRole {
                codeEntryView(for: role)
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
            } else {
                roleSelectionView
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
            }

            Spacer()

            // Footer - only show for RA/Staff code entry
            if showCodeEntry && selectedRole != .resident {
                Text("Staff Access Code Required")
                    .appStyle(.label, color: .textSecondary)
                    .padding(.bottom, AppSpacing.lg)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.appBackground)
        .animation(.easeInOut(duration: 0.3), value: showCodeEntry)
    }

    // MARK: - Role Selection View

    private var roleSelectionView: some View {
        VStack(spacing: AppSpacing.sm) {
            Text("Select your role")
                .appStyle(.titleSmall, color: .textSecondary)
                .padding(.bottom, AppSpacing.sm)

            ForEach(UserRole.allCases) { role in
                OnboardingRoleCard(role: role, requiresCode: role != .resident) {
                    selectedRole = role
                    codeInput = ""
                    showError = false

                    // Residents proceed directly without access code
                    if role == .resident {
                        appState.submitResidentRole()
                    } else {
                        withAnimation {
                            showCodeEntry = true
                        }
                    }
                }
            }
        }
        .padding(.horizontal, AppSpacing.lg)
    }

    // MARK: - Code Entry View

    private func codeEntryView(for role: UserRole) -> some View {
        VStack(spacing: AppSpacing.lg) {
            // Back button
            HStack {
                Button {
                    withAnimation {
                        showCodeEntry = false
                        selectedRole = nil
                    }
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
            .padding(.horizontal, AppSpacing.lg)

            // Role indicator
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: role.icon)
                    .font(.system(size: 36))
                    .foregroundColor(.appPrimary)
                    .frame(width: 64, height: 64)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(16)

                Text(role.displayName)
                    .appStyle(.titleSmall)
            }

            // Code entry
            VStack(spacing: AppSpacing.sm) {
                Text("Enter access code")
                    .appStyle(.caption, color: .textSecondary)

                TextField("Access Code", text: $codeInput)
                    .font(.system(size: 20, weight: .semibold, design: .monospaced))
                    .multilineTextAlignment(.center)
                    .autocapitalization(.allCharacters)
                    .disableAutocorrection(true)
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(showError ? Color.red : Color.clear, lineWidth: 2)
                    )
                    .shake(isAnimating: isAnimating)

                if showError {
                    Text("Invalid code. Please try again.")
                        .font(.system(size: 14))
                        .foregroundColor(.red)
                }
            }
            .padding(.horizontal, AppSpacing.lg)

            // Continue button
            Button {
                if appState.submitRoleWithCode(role, code: codeInput) {
                    // Success - AppState will transition to needsAuth
                } else {
                    showError = true
                    triggerShake()
                }
            } label: {
                Text("Continue")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(codeInput.isEmpty ? Color.gray : Color.appPrimary)
                    .cornerRadius(12)
            }
            .disabled(codeInput.isEmpty)
            .padding(.horizontal, AppSpacing.lg)
        }
    }

    private func triggerShake() {
        isAnimating = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isAnimating = false
        }
    }
}

// MARK: - Role Card

struct OnboardingRoleCard: View {
    let role: UserRole
    var requiresCode: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            AppCard {
                HStack(spacing: AppSpacing.md) {
                    Image(systemName: role.icon)
                        .font(.system(size: 24))
                        .foregroundColor(.appPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(AppRadius.chip)

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        HStack(spacing: 6) {
                            Text(role.displayName)
                                .appStyle(.titleSmall)

                            if requiresCode {
                                Text("Code")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundColor(.orange)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.orange.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }

                        Text(role.description)
                            .appStyle(.caption, color: .textSecondary)
                            .lineLimit(2)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    OnboardingRoleView()
        .environmentObject(AppState.shared)
}
