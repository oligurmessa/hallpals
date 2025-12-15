import SwiftUI

struct RAHomeView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @State private var showingSettings = false
    @State private var showingRounds = false
    @State private var navigateToAI = false

    // Mock data
    private let userName = "Alex"
    private let currentTime = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Greeting header
                    greetingSection
                        .padding(.horizontal, 20)

                    // AI Assistant Card
                    aiAssistantCard
                        .padding(.horizontal, 20)

                    // Status card
                    statusCard
                        .padding(.horizontal, 20)

                    // Quick actions grid
                    quickActionsGrid
                        .padding(.horizontal, 20)

                    // Upcoming section
                    upcomingSection
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        // Notifications
                    } label: {
                        Image(systemName: "bell")
                            .font(.system(size: 17))
                            .foregroundColor(.primary)
                    }
                }
            }
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }
            .fullScreenCover(isPresented: $showingRounds) {
                RoundsTrackerView()
            }
            .fullScreenCover(isPresented: $navigateToAI) {
                AIChatView()
            }
        }
    }

    // MARK: - Greeting Section

    private var greetingSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(greetingText)
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text(formattedDate)
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        if hour < 12 {
            return "Good morning, \(userName)"
        } else if hour < 17 {
            return "Good afternoon, \(userName)"
        } else {
            return "Good evening, \(userName)"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentTime)
    }

    // MARK: - AI Assistant Card

    private var aiAssistantCard: some View {
        Button {
            navigateToAI = true
        } label: {
            HStack(spacing: 16) {
                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                }

                // Text
                VStack(alignment: .leading, spacing: 4) {
                    Text("Ask AI Assistant")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text("Get instant answers about policies & procedures")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(16)
        }
    }

    // MARK: - Status Card

    private var statusCard: some View {
        VStack(spacing: 16) {
            // Duty status row
            HStack {
                HStack(spacing: 8) {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 8, height: 8)
                    Text("On Duty")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }

                Spacer()

                Text("Until 12:00 AM")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            // Stats row
            HStack(spacing: 0) {
                statItem(value: "2", label: "Rounds", icon: "figure.walk")
                statItem(value: "0", label: "Incidents", icon: "exclamationmark.triangle")
                statItem(value: "3", label: "Events", icon: "calendar")
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func statItem(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 18))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 22, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Actions Grid

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 12),
                GridItem(.flexible(), spacing: 12)
            ], spacing: 12) {
                // Start Rounds - Primary action
                quickActionButton(
                    title: "Start Rounds",
                    icon: "checkmark.circle",
                    isPrimary: true
                ) {
                    showingRounds = true
                }

                // Log Incident
                quickActionButton(
                    title: "Log Incident",
                    icon: "exclamationmark.triangle",
                    isPrimary: false
                ) {
                    // Action
                }

                // Create Event
                quickActionButton(
                    title: "Create Event",
                    icon: "calendar.badge.plus",
                    isPrimary: false
                ) {
                    // Action
                }

                // Quick Contact
                quickActionButton(
                    title: "Quick Contact",
                    icon: "phone",
                    isPrimary: false
                ) {
                    // Action
                }
            }
        }
    }

    private func quickActionButton(title: String, icon: String, isPrimary: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(isPrimary ? .white : .primary)

                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(isPrimary ? .white : .primary)

                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(isPrimary ? Color.blue : Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Button("See All") {
                    // Navigate to events
                }
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.blue)
            }

            VStack(spacing: 0) {
                upcomingEventRow(
                    title: "Floor Meeting",
                    time: "7:00 PM",
                    location: "2nd Floor Lounge",
                    isFirst: true
                )

                Divider()
                    .padding(.leading, 52)

                upcomingEventRow(
                    title: "Evening Rounds",
                    time: "9:00 PM",
                    location: "All Floors",
                    isFirst: false
                )

                Divider()
                    .padding(.leading, 52)

                upcomingEventRow(
                    title: "Midnight Rounds",
                    time: "12:00 AM",
                    location: "All Floors",
                    isFirst: false
                )
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func upcomingEventRow(title: String, time: String, location: String, isFirst: Bool) -> some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(spacing: 2) {
                Text(time.components(separatedBy: " ").first ?? time)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(time.components(separatedBy: " ").last ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                Text(location)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(UIColor.systemGray3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

#Preview {
    RAHomeView()
        .environmentObject(RoleManager())
        .environmentObject(ResourceStore())
}
