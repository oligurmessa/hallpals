import SwiftUI

struct RoundsSummaryView: View {
    let summary: RoundsSummary
    let onDismiss: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 32) {
                    Spacer()
                        .frame(height: 20)

                    // Success header
                    successHeader

                    // Main stats card
                    mainStatsCard
                        .padding(.horizontal, 20)

                    // Details card
                    detailsCard
                        .padding(.horizontal, 20)

                    Spacer()
                }
            }
            .background(Color(UIColor.systemBackground))
            .safeAreaInset(edge: .bottom) {
                doneButton
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color(UIColor.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("Round Complete")
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }

    // MARK: - Success Header

    private var successHeader: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 88, height: 88)

                Image(systemName: "checkmark")
                    .font(.system(size: 40, weight: .semibold))
                    .foregroundColor(.green)
            }

            VStack(spacing: 4) {
                Text("Rounds Completed")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.primary)

                Text(formatDate(summary.session.startTime))
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Main Stats Card

    private var mainStatsCard: some View {
        HStack(spacing: 0) {
            mainStatItem(
                value: summary.totalDuration,
                label: "Duration",
                icon: "clock"
            )

            Divider()
                .frame(height: 50)

            mainStatItem(
                value: "\(summary.totalSteps)",
                label: "Steps",
                icon: "figure.walk"
            )

            Divider()
                .frame(height: 50)

            mainStatItem(
                value: "\(summary.session.floorsVisited.count)",
                label: "Floors",
                icon: "building.2"
            )
        }
        .padding(.vertical, 20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func mainStatItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Details Card

    private var detailsCard: some View {
        VStack(spacing: 0) {
            detailRow(
                icon: "checkmark.circle.fill",
                iconColor: .green,
                label: "Floors Completed",
                value: "\(floorsWithSufficientSteps) of \(summary.session.floorsVisited.count)",
                isLast: false
            )

            detailRow(
                icon: "shoeprints.fill",
                iconColor: .blue,
                label: "Avg Steps per Floor",
                value: "\(averageStepsPerFloor)",
                isLast: false
            )

            detailRow(
                icon: "clock",
                iconColor: .orange,
                label: "Started At",
                value: formatTime(summary.session.startTime),
                isLast: false
            )

            detailRow(
                icon: "clock.badge.checkmark",
                iconColor: .green,
                label: "Ended At",
                value: formatTime(summary.session.endTime ?? Date()),
                isLast: true
            )
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func detailRow(icon: String, iconColor: Color, label: String, value: String, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 16))
                    .foregroundColor(iconColor)
                    .frame(width: 24)

                Text(label)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                Spacer()

                Text(value)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 54)
            }
        }
    }

    // MARK: - Done Button

    private var doneButton: some View {
        Button {
            onDismiss()
        } label: {
            Text("Done")
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.blue)
                .cornerRadius(14)
        }
    }

    // MARK: - Helpers

    private var floorsWithSufficientSteps: Int {
        summary.floorCoverageDetails.filter { $0.steps >= FloorTransitionConfig.stepsPerFloorCompletion }.count
    }

    private var averageStepsPerFloor: Int {
        guard summary.session.floorsVisited.count > 0 else { return 0 }
        return summary.totalSteps / max(1, summary.session.floorsVisited.count)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }
}

// MARK: - Preview

#Preview {
    let mockSession = RoundsSession(
        startTime: Date().addingTimeInterval(-1800),
        endTime: Date(),
        status: .completed,
        segments: [],
        floorVisits: [
            FloorVisit(floorNumber: 1, entryTime: Date().addingTimeInterval(-1800), exitTime: Date().addingTimeInterval(-1200), segments: [], estimatedCoverage: 0.8),
            FloorVisit(floorNumber: 2, entryTime: Date().addingTimeInterval(-1200), exitTime: Date().addingTimeInterval(-600), segments: [], estimatedCoverage: 0.6),
            FloorVisit(floorNumber: 3, entryTime: Date().addingTimeInterval(-600), exitTime: Date(), segments: [], estimatedCoverage: 0.9)
        ],
        currentFloor: 3,
        startingFloor: 1,
        totalSteps: 1847
    )

    RoundsSummaryView(summary: RoundsSummary(session: mockSession)) {
        print("Dismissed")
    }
}
