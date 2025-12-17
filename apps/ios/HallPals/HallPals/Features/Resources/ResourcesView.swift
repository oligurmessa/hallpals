import SwiftUI

struct ResourcesView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @EnvironmentObject private var resourceStore: ResourceStore

    var body: some View {
        Group {
            switch roleManager.selectedRole {
            case .ra:
                RAResourcesView()
            case .resident:
                ResidentResourcesView()
            case .none:
                // Brief loading while role syncs from AppState
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Reusable Components

struct ResourceQuickCard: View {
    let icon: String
    let title: String
    let color: Color

    var body: some View {
        AppCard {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)
                Text(title)
                    .appStyle(.label)
            }
            .frame(width: 80)
        }
    }
}

struct ResourceRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(.appPrimary)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appStyle(.body)
                    Text(subtitle)
                        .appStyle(.caption, color: .textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - Previews

#Preview("RA Resources") {
    ResourcesView()
        .environmentObject({
            let rm = RoleManager()
            rm.selectRole(.ra)
            return rm
        }())
}

#Preview("Resident Resources") {
    ResourcesView()
        .environmentObject({
            let rm = RoleManager()
            rm.selectRole(.resident)
            return rm
        }())
}
