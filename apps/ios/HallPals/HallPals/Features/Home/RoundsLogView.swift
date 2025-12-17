import SwiftUI

// MARK: - Mock Data

struct RoundEntry: Identifiable {
    let id = UUID()
    let time: String
    let status: RoundStatus
    let notes: String?

    enum RoundStatus: String {
        case completed = "Completed"
        case inProgress = "In Progress"
        case scheduled = "Scheduled"

        var color: Color {
            switch self {
            case .completed: return .appSuccess
            case .inProgress: return .appWarning
            case .scheduled: return .textSecondary
            }
        }

        var icon: String {
            switch self {
            case .completed: return "checkmark.circle.fill"
            case .inProgress: return "arrow.triangle.2.circlepath"
            case .scheduled: return "clock"
            }
        }
    }
}

// MARK: - RoundsLogView

struct RoundsLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showStartRoundSheet = false

    private let mockRounds: [RoundEntry] = [
        RoundEntry(time: "8:00 PM", status: .completed, notes: "All quiet"),
        RoundEntry(time: "10:00 PM", status: .completed, notes: "Noise complaint - resolved"),
        RoundEntry(time: "12:00 AM", status: .scheduled, notes: nil)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Summary Card
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {
                        Text("Tonight's Rounds")
                            .appStyle(.titleSmall)

                        HStack(spacing: AppSpacing.lg) {
                            VStack {
                                Text("2")
                                    .appStyle(.titleLarge, color: .appSuccess)
                                Text("Completed")
                                    .appStyle(.caption, color: .textSecondary)
                            }

                            VStack {
                                Text("1")
                                    .appStyle(.titleLarge, color: .textSecondary)
                                Text("Remaining")
                                    .appStyle(.caption, color: .textSecondary)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Rounds List
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Round Log")
                        .appStyle(.titleSmall)
                        .padding(.horizontal, AppSpacing.xs)

                    AppCard {
                        VStack(spacing: 0) {
                            ForEach(Array(mockRounds.enumerated()), id: \.element.id) { index, round in
                                RoundRow(round: round)

                                if index < mockRounds.count - 1 {
                                    Divider()
                                        .padding(.vertical, AppSpacing.sm)
                                }
                            }
                        }
                    }
                }

                // Start Round Button
                PrimaryButton(title: "Start Next Round") {
                    showStartRoundSheet = true
                }
            }
            .padding(AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle("Rounds")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showStartRoundSheet) {
            StartRoundSheet()
        }
    }
}

struct RoundRow: View {
    let round: RoundEntry

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: round.status.icon)
                .font(.system(size: 20))
                .foregroundColor(round.status.color)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                HStack {
                    Text(round.time)
                        .appStyle(.body)

                    Spacer()

                    Text(round.status.rawValue)
                        .appStyle(.label, color: round.status.color)
                }

                if let notes = round.notes {
                    Text(notes)
                        .appStyle(.caption, color: .textSecondary)
                }
            }
        }
    }
}

struct StartRoundSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.lg) {
                Spacer()

                Image(systemName: "figure.walk")
                    .font(.system(size: 60))
                    .foregroundColor(.appPrimary)

                Text("Start Round")
                    .appStyle(.titleMedium)

                Text("In the full version, this would track your round progress and allow you to log observations.")
                    .appStyle(.body, color: .textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer()

                VStack(spacing: AppSpacing.sm) {
                    PrimaryButton(title: "Begin Round (Mock)") {
                        dismiss()
                    }

                    SecondaryButton(title: "Cancel") {
                        dismiss()
                    }
                }
                .padding(.horizontal, AppSpacing.lg)
            }
            .padding(AppSpacing.lg)
            .background(Color.appBackground)
            .navigationTitle("Start Round")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.appPrimary)
                }
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoundsLogView()
    }
}
