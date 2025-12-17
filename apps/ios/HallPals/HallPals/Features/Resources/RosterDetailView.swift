import SwiftUI

struct RosterDetailView: View {
    let entry: RosterEntry

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Profile header
                profileHeader

                // Status card
                statusCard

                // Notes card (if any)
                // Notes card (if any)
                if !entry.notes.isEmpty {
                    notesCard(notes: entry.notes)
                }

                // Quick actions
                quickActionsCard
            }
            .padding(AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle("Resident Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Profile Header

    private var profileHeader: some View {
        AppCard {
            VStack(spacing: AppSpacing.md) {
                // Avatar
                Circle()
                    .fill(Color.appPrimary.opacity(0.2))
                    .frame(width: 80, height: 80)
                    .overlay(
                        Text(String(entry.name.prefix(1)))
                            .font(.system(size: 32, weight: .semibold))
                            .foregroundColor(.appPrimary)
                    )

                // Name and flag
                HStack(spacing: AppSpacing.sm) {
                    Text(entry.name)
                        .appStyle(.titleMedium)

                    if entry.isFlagged {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.appWarning)
                    }
                }

                // Room info
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "door.left.hand.closed")
                        .foregroundColor(.textSecondary)
                    Text("Room \(entry.room)")
                        .appStyle(.body, color: .textSecondary)
                }

                // RA assignment
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundColor(.appPrimary)
                    Text("RA: \(entry.raName)")
                        .appStyle(.caption, color: .textSecondary)
                }
            }
            .frame(maxWidth: .infinity)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "person.text.rectangle")
                        .foregroundColor(.appPrimary)
                    Text("Status")
                        .appStyle(.titleSmall)
                }

                HStack {
                    Circle()
                        .fill(entry.status.color)
                        .frame(width: 10, height: 10)

                    Text(entry.status.rawValue)
                        .appStyle(.body)

                    Spacer()

                    Text(statusDescription)
                        .appStyle(.caption, color: .textSecondary)
                }
                .padding(AppSpacing.md)
                .background(entry.status.color.opacity(0.1))
                .cornerRadius(AppRadius.card)

                if entry.isFlagged {
                    Divider()

                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundColor(.appWarning)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Flagged for Follow-up")
                                .appStyle(.body, color: .appWarning)
                            Text("This resident requires additional attention")
                                .appStyle(.caption, color: .textSecondary)
                        }
                    }
                    .padding(AppSpacing.md)
                    .background(Color.appWarning.opacity(0.1))
                    .cornerRadius(AppRadius.card)
                }
            }
        }
    }

    private var statusDescription: String {
        switch entry.status {
        case .onCampus:
            return "Currently living on floor"
        case .abroad:
            return "Studying abroad this semester"
        case .commuter:
            return "Lives off-campus"
        case .quietConcern:
            return "Requires check-in"
        case .awayThisWeek:
            return "Expected back soon"
        }
    }

    // MARK: - Notes Card

    private func notesCard(notes: String) -> some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "note.text")
                        .foregroundColor(.appPrimary)
                    Text("Notes")
                        .appStyle(.titleSmall)
                    Spacer()
                    Text("(mock data)")
                        .appStyle(.label, color: .textSecondary)
                }

                Text(notes)
                    .appStyle(.body, color: .textSecondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    // MARK: - Quick Actions Card

    private var quickActionsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "bolt.fill")
                        .foregroundColor(.appPrimary)
                    Text("Quick Actions")
                        .appStyle(.titleSmall)
                }

                VStack(spacing: AppSpacing.sm) {
                    QuickActionButton(
                        icon: "message.fill",
                        title: "Send Message",
                        subtitle: "Open chat (mock)"
                    ) {
                        print("Would open message")
                    }

                    QuickActionButton(
                        icon: "note.text.badge.plus",
                        title: "Add Note",
                        subtitle: "Document interaction"
                    ) {
                        print("Would add note")
                    }

                    QuickActionButton(
                        icon: entry.isFlagged ? "flag.slash.fill" : "flag.fill",
                        title: entry.isFlagged ? "Remove Flag" : "Flag for Follow-up",
                        subtitle: entry.isFlagged ? "Clear attention flag" : "Mark for attention"
                    ) {
                        print("Would toggle flag")
                    }

                    QuickActionButton(
                        icon: "clock.arrow.circlepath",
                        title: "View History",
                        subtitle: "Past interactions (mock)"
                    ) {
                        print("Would view history")
                    }
                }
            }
        }
    }
}

// MARK: - Quick Action Button

struct QuickActionButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.appPrimary)
                    .frame(width: 32, height: 32)
                    .background(Color.appPrimary.opacity(0.1))
                    .cornerRadius(6)

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
            .padding(AppSpacing.sm)
            .background(Color.appSurface)
            .cornerRadius(AppRadius.card)
        }
        .buttonStyle(.plain)
    }
}

#Preview("Active Resident") {
    NavigationStack {
        RosterDetailView(entry: RosterEntry(
            id: UUID(),
            name: "Jordan Smith",
            room: "215",
            status: .onCampus,
            notes: "First-year student. Has expressed interest in RA position for next year. Good rapport with floormates.",
            isFlagged: false,
            raName: "Alex Martinez"
        ))
    }
}

#Preview("Flagged Resident") {
    NavigationStack {
        RosterDetailView(entry: RosterEntry(
            id: UUID(),
            name: "Taylor Chen",
            room: "203",
            status: .quietConcern,
            notes: "Had roommate conflict last month. Follow up on resolution progress.",
            isFlagged: true,
            raName: "Alex Martinez"
        ))
    }
}
