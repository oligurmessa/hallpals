import SwiftUI

/// DEPRECATED: This view is no longer used - replaced by LandingView
/// Role selection is now automatic based on roster lookup
struct OnboardingRoleView: View {
    @EnvironmentObject private var appState: AppState

    var body: some View {
        // Redirect to LandingView (this view should not be shown)
        LandingView()
    }
}

// MARK: - Role Card

struct OnboardingRoleCard: View {
    let role: UserRole
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
                        Text(role.displayName)
                            .appStyle(.titleSmall)

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
