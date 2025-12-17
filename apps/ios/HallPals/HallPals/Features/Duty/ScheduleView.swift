import SwiftUI

struct ScheduleView: View {
    // OPTIMIZED: Observe UserManager directly for reactive updates
    // UserManager loads shifts in parallel with residents on RA login
    @StateObject private var userManager = UserManager.shared

    // Backward compatibility alias
    private var scheduleService: DutyScheduleService { DutyScheduleService.shared }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Status card
                statusCard
                    .padding(.horizontal, 20)

                // Schedule content
                if userManager.myShifts.isEmpty {
                    emptyCard
                        .padding(.horizontal, 20)
                } else {
                    // This week section
                    if !userManager.thisWeekShifts.isEmpty {
                        thisWeekSection
                    }
                    // Upcoming section
                    if !userManager.upcomingShifts.isEmpty {
                        upcomingSection
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    userManager.refreshRAData()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17))
                }
                .disabled(userManager.isLoadingRAData)
            }
        }
        .onAppear {
            // Data is already loaded by UserManager on RA login
            // Only refresh if explicitly empty and not loading
            if userManager.myShifts.isEmpty && !userManager.isLoadingRAData && userManager.shiftsLoaded {
                userManager.refreshRAData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schedule")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            if let nextShift = userManager.nextShift {
                Text("Next shift: \(nextShift.formattedDate)")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            } else {
                Text("View your duty schedule")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 16) {
            // Current status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(userManager.isOnDuty ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(userManager.isOnDuty ? "On Duty" : "Off Duty")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(userManager.isOnDuty ? .green : .orange)
                }

                if let active = userManager.activeShift {
                    Text("Until \(active.formattedEndTime)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else if let next = userManager.nextShift {
                    Text(next.isToday ? "Today at \(next.formattedStartTime)" :
                         next.isTomorrow ? "Tomorrow at \(next.formattedStartTime)" :
                         next.formattedDate)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(userManager.thisWeekShifts.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                    Text("This Week")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(userManager.upcomingShifts.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Total")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Empty Card

    private var emptyCard: some View {
        VStack(spacing: 16) {
            if userManager.isLoadingRAData && !userManager.shiftsLoaded {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading shifts...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            } else {
                Image(systemName: "calendar.badge.clock")
                    .font(.system(size: 44))
                    .foregroundColor(.blue)

                Text("No Shifts Found")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                if let error = userManager.shiftsError {
                    Text(error)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                } else {
                    Text("Your duty shifts will appear here once assigned by your staff.")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    userManager.refreshRAData()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.clockwise")
                        Text("Refresh")
                    }
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
                    .background(Color.blue)
                    .cornerRadius(12)
                }
            }
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - This Week Section

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if userManager.isLoadingRAData {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(userManager.thisWeekShifts.enumerated()), id: \.element.id) { index, shift in
                    DutyShiftRow(
                        shift: shift,
                        isLast: index == userManager.thisWeekShifts.count - 1
                    )
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Upcoming")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if userManager.shiftsLoaded {
                    Text("Updated just now")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(userManager.upcomingShifts.prefix(10).enumerated()), id: \.element.id) { index, shift in
                    DutyShiftRow(
                        shift: shift,
                        isLast: index == min(9, userManager.upcomingShifts.count - 1)
                    )
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)

            if userManager.upcomingShifts.count > 10 {
                Text("+ \(userManager.upcomingShifts.count - 10) more shifts")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Duty Shift Row

struct DutyShiftRow: View {
    let shift: DutyShift
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Date circle
                VStack(spacing: 2) {
                    Text(dayOfWeek)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(dayNumber)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(shift.isToday ? .blue : .primary)
                }
                .frame(width: 44, height: 44)
                .background(shift.isToday ? Color.blue.opacity(0.12) : Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Shift details
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(shift.formattedDate)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        if shift.isToday {
                            Text("Today")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(4)
                        } else if shift.isTomorrow {
                            Text("Tomorrow")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }

                    Text("\(shift.formattedStartTime) - \(shift.formattedEndTime)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Duration
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1fh", shift.durationHours))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 74)
            }
        }
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: shift.start).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: shift.start)
    }
}

#Preview {
    NavigationStack {
        ScheduleView()
    }
}
