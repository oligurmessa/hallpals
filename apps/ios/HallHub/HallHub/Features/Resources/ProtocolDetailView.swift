import SwiftUI

struct ProtocolDetailView: View {
    let item: ProtocolItem
    let showStaffBadge: Bool

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Header card
                headerCard

                // Steps card
                stepsCard

                // Additional info card
                additionalInfoCard
            }
            .padding(AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle("Protocol")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Icon and badges
                HStack {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 28))
                        .foregroundColor(.appPrimary)
                        .frame(width: 44, height: 44)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(10)

                    Spacer()

                    if showStaffBadge && item.isStaffOnly {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                                .font(.system(size: 10))
                                .foregroundColor(.appPrimary)
                            Text("Staff Only")
                                .appStyle(.label, color: .appPrimary)
                        }
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(AppRadius.chip)
                    }
                }

                // Title
                Text(item.title)
                    .appStyle(.titleMedium)

                // Category pill
                ProtocolCategoryPill(category: item.category)

                Divider()

                // Description
                Text(item.shortDescription)
                    .appStyle(.body, color: .textSecondary)
            }
        }
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "list.number")
                        .foregroundColor(.appPrimary)
                    Text("Protocol Steps")
                        .appStyle(.titleSmall)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(Array(item.steps.enumerated()), id: \.offset) { index, step in
                        ProtocolStepRow(number: index + 1, text: step, isLast: index == item.steps.count - 1)
                    }
                }
            }
        }
    }

    // MARK: - Additional Info Card

    private var additionalInfoCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.appPrimary)
                    Text("Important Notes")
                        .appStyle(.titleSmall)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    InfoBullet(text: "Always prioritize safety of all individuals involved")
                    InfoBullet(text: "Document all incidents as soon as safely possible")
                    InfoBullet(text: "Contact your supervisor if you're unsure how to proceed")
                    InfoBullet(text: "Follow up with affected residents within 24-48 hours")
                }

                Divider()

                HStack {
                    Image(systemName: "clock")
                        .foregroundColor(.textSecondary)
                    Text("Last updated: September 2024")
                        .appStyle(.caption, color: .textSecondary)
                }
            }
        }
    }
}

// MARK: - Protocol Step Row

struct ProtocolStepRow: View {
    let number: Int
    let text: String
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            VStack(spacing: 0) {
                ZStack {
                    Circle()
                        .fill(Color.appPrimary)
                        .frame(width: 28, height: 28)

                    Text("\(number)")
                        .appStyle(.label, color: .white)
                }

                if !isLast {
                    Rectangle()
                        .fill(Color.appPrimary.opacity(0.3))
                        .frame(width: 2)
                        .frame(minHeight: 20)
                }
            }

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(text)
                    .appStyle(.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.bottom, isLast ? 0 : AppSpacing.sm)

            Spacer()
        }
    }
}

// MARK: - Info Bullet

struct InfoBullet: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.appSuccess)
                .font(.system(size: 14))

            Text(text)
                .appStyle(.body, color: .textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

// MARK: - Protocol Category Pill

struct ProtocolCategoryPill: View {
    let category: ProtocolCategory

    var body: some View {
        Text(category.rawValue)
            .appStyle(.label, color: .appPrimary)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color.appPrimary.opacity(0.1))
            .cornerRadius(AppRadius.chip)
    }
}

#Preview("RA Protocol") {
    NavigationStack {
        ProtocolDetailView(
            item: ProtocolItem(
                id: UUID(),
                title: "Noise Complaint Response",
                category: .noise,
                shortDescription: "How to handle noise complaints from residents on your floor.",
                steps: [
                    "Approach the room calmly and knock on the door",
                    "Introduce yourself and explain the complaint",
                    "Ask residents to lower noise level",
                    "Document the interaction in your log",
                    "If issue persists, follow up within 30 minutes",
                    "Escalate to HD on duty if unresolved after 2nd visit"
                ],
                isStaffOnly: false
            ),
            showStaffBadge: false
        )
    }
}

#Preview("Staff Only Protocol") {
    NavigationStack {
        ProtocolDetailView(
            item: ProtocolItem(
                id: UUID(),
                title: "Conduct Hearing Procedures",
                category: .communityStandard,
                shortDescription: "Staff-level conduct hearing process and documentation.",
                steps: [
                    "Review incident report and all documentation",
                    "Schedule hearing with 48-hour notice to student",
                    "Prepare hearing materials and previous records",
                    "Conduct hearing following due process guidelines",
                    "Issue written decision within 5 business days",
                    "File all documentation in student conduct system"
                ],
                isStaffOnly: true
            ),
            showStaffBadge: true
        )
    }
}
