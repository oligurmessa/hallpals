import SwiftUI

/// RA Home View - Duty dashboard for Resident Assistants
/// Features: Duty status from Firebase, quick actions, AI assistant
struct RAHomeView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @StateObject private var userManager = UserManager.shared
    @StateObject private var scheduleService = DutyScheduleService.shared
    @State private var showingSettings = false
    @State private var showingRounds = false
    @State private var navigateToAI = false
    @State private var showingAdvocate = false
    @State private var showingCampusSafety = false
    @State private var showingConcerns = false
    @StateObject private var concernService = ConcernService.shared

    private let advocateURL = "https://stthomas-advocate.symplicity.com"

    private let currentTime = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .padding(.horizontal, 20)

                    // AI Assistant Card
                    aiAssistantCard
                        .padding(.horizontal, 20)

                    // Duty Status Section
                    dutyStatusSection
                        .padding(.horizontal, 20)

                    // Quick Actions Section
                    quickActionsSection
                        .padding(.horizontal, 20)

                    // Resources Section
                    resourcesSection
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
            .fullScreenCover(isPresented: $showingAdvocate) {
                NavigationStack {
                    InAppBrowserView(url: URL(string: advocateURL)!, title: "Report Incident")
                }
            }
            .sheet(isPresented: $showingCampusSafety) {
                CampusSafetySheet()
            }
            .sheet(isPresented: $showingConcerns) {
                ConcernsListView()
            }
            .onAppear {
                // Start listening for concerns when RA views home
                if let hallId = userManager.hallId, !hallId.isEmpty {
                    concernService.startListening(hallId: hallId)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(greetingText)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundColor(.primary)

                Text(formattedDate)
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }

            // RA Assignment Info
            raAssignmentInfo
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - RA Assignment Info

    private var raAssignmentInfo: some View {
        VStack(alignment: .leading, spacing: 8) {
            // First row: Hall, Floor/Wing, Room
            HStack(spacing: 12) {
                // Hall - use hall name if available
                if let hall = userManager.currentHall {
                    assignmentBadge(
                        icon: "building.2.fill",
                        text: hall.name,
                        color: .blue
                    )
                } else if let hallId = userManager.currentUser?.hallId, !hallId.isEmpty {
                    assignmentBadge(
                        icon: "building.2.fill",
                        text: formatHallName(hallId),
                        color: .blue
                    )
                } else {
                    assignmentBadge(
                        icon: "building.2.fill",
                        text: "Not assigned",
                        color: .gray
                    )
                }

                // Floor / Wing
                if let floor = userManager.currentUser?.floor {
                    let wingText = userManager.currentUser?.wing
                    let floorText = wingText != nil ? "Floor \(floor) \(wingText!)" : "Floor \(floor)"
                    assignmentBadge(
                        icon: "stairs",
                        text: floorText,
                        color: .purple
                    )
                } else if let wing = userManager.currentUser?.wing {
                    assignmentBadge(
                        icon: "rectangle.split.3x1.fill",
                        text: wing,
                        color: .purple
                    )
                }

                // Room Number
                if let room = userManager.currentUser?.roomNumber {
                    assignmentBadge(
                        icon: "door.left.hand.closed",
                        text: "Room \(room)",
                        color: .green
                    )
                }

                Spacer()
            }

            // Second row: Hall Director
            if let director = userManager.currentHall?.hallDirector {
                HStack(spacing: 6) {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.orange)

                    Text("HD: \(director.name)")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.leading, 2)
            }
        }
    }

    private func assignmentBadge(icon: String, text: String, color: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(color)

            Text(text)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.primary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func formatHallName(_ hallId: String) -> String {
        // Convert hallId to display name (e.g., "hall-001" -> "Hall 001" or use actual name if available)
        if hallId.hasPrefix("hall-") {
            let suffix = hallId.replacingOccurrences(of: "hall-", with: "")
            return "Hall \(suffix)"
        }
        // Capitalize first letter of each word
        return hallId.split(separator: "-").map { $0.capitalized }.joined(separator: " ")
    }

    private var greetingText: String {
        let hour = Calendar.current.component(.hour, from: currentTime)
        let firstName = userManager.currentUser?.displayName?.components(separatedBy: " ").first ?? "RA"

        if hour < 12 {
            return "Good morning, \(firstName)"
        } else if hour < 17 {
            return "Good afternoon, \(firstName)"
        } else {
            return "Good evening, \(firstName)"
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
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "sparkles")
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.blue)
                }

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

    // MARK: - Duty Status Section

    private var dutyStatusSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Duty Status")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 16) {
                // Current status row
                HStack {
                    HStack(spacing: 8) {
                        Circle()
                            .fill(scheduleService.isOnDuty ? Color.green : Color.orange)
                            .frame(width: 10, height: 10)
                        Text(scheduleService.isOnDuty ? "On Duty" : "Off Duty")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(scheduleService.isOnDuty ? .green : .orange)
                    }

                    Spacer()

                    // Next shift or end time
                    if let active = scheduleService.activeShift {
                        Text("Until \(active.formattedEndTime)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else if let next = scheduleService.nextShift {
                        Text(nextShiftText(next))
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else {
                        Text("No shifts scheduled")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Divider()

                // Schedule summary
                HStack(spacing: 0) {
                    scheduleStat(
                        value: "\(scheduleService.thisWeekShifts.count)",
                        label: "This Week",
                        color: .blue
                    )

                    scheduleStat(
                        value: "\(scheduleService.upcomingShifts.count)",
                        label: "Upcoming",
                        color: .purple
                    )

                    scheduleStat(
                        value: "\(scheduleService.shiftCount)",
                        label: "Total",
                        color: .green
                    )
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func nextShiftText(_ shift: DutyShift) -> String {
        if shift.isToday {
            return "Today at \(shift.formattedStartTime)"
        } else if shift.isTomorrow {
            return "Tomorrow at \(shift.formattedStartTime)"
        } else {
            return shift.formattedDate
        }
    }

    private func scheduleStat(value: String, label: String, color: Color, isText: Bool = false) -> some View {
        VStack(spacing: 4) {
            if isText {
                Text(value)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(color)
            } else {
                Text(value)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(color)
            }
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                // Start Rounds
                Button {
                    showingRounds = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Rounds")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Track your duty rounds")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 62)

                // Log Incident (via Advocate)
                Button {
                    showingAdvocate = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                            .frame(width: 32, height: 32)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Log Incident")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Report via Advocate system")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 62)

                // Resident Concerns
                Button {
                    showingConcerns = true
                } label: {
                    HStack(spacing: 14) {
                        ZStack {
                            Image(systemName: "exclamationmark.bubble.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.purple)
                                .frame(width: 32, height: 32)
                                .background(Color.purple.opacity(0.12))
                                .clipShape(RoundedRectangle(cornerRadius: 8))

                            // Badge for pending concerns
                            if concernService.pendingCount > 0 {
                                Text("\(concernService.pendingCount)")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.white)
                                    .frame(width: 16, height: 16)
                                    .background(Color.red)
                                    .clipShape(Circle())
                                    .offset(x: 12, y: -12)
                            }
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Resident Concerns")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text(concernService.pendingCount > 0 ? "\(concernService.pendingCount) pending" : "View reported issues")
                                .font(.system(size: 13))
                                .foregroundColor(concernService.pendingCount > 0 ? .orange : .secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 62)

                // Campus Safety
                Button {
                    showingCampusSafety = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Campus Safety")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Emergency/Non-Emergency & CD")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Resources Section

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resources")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                // Protocols & Procedures - navigates to Resources tab
                NavigationLink {
                    RAResourcesView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.purple)
                            .frame(width: 32, height: 32)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Protocols & Procedures")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("SLED, policies, rosters")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 62)

                // Schedule - navigates to Schedule tab
                NavigationLink {
                    ScheduleView()
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "calendar")
                            .font(.system(size: 18))
                            .foregroundColor(.cyan)
                            .frame(width: 32, height: 32)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("View Full Schedule")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            if let lastUpdated = scheduleService.lastUpdated {
                                Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            } else {
                                Text("Tap to view schedule")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - RA Emergency Contacts Sheet

struct RAEmergencyContactsSheet: View {
    @Environment(\.dismiss) private var dismiss

    // These would ideally come from hall configuration in Firestore
    private let contacts: [(name: String, number: String, icon: String, color: Color)] = [
        ("Campus Security", "651-962-5555", "shield.fill", .blue),
        ("RD On-Call", "651-962-6000", "person.badge.shield.checkmark.fill", .purple),
        ("Facilities Emergency", "651-962-6500", "wrench.and.screwdriver.fill", .orange),
        ("Counseling Center", "651-962-6780", "heart.text.square.fill", .pink),
        ("Health Services", "651-962-6750", "cross.case.fill", .red)
    ]

    var body: some View {
        NavigationStack {
            List {
                Section {
                    ForEach(contacts, id: \.number) { contact in
                        Button {
                            callNumber(contact.number)
                        } label: {
                            HStack(spacing: 14) {
                                Image(systemName: contact.icon)
                                    .font(.system(size: 18))
                                    .foregroundColor(contact.color)
                                    .frame(width: 32, height: 32)
                                    .background(contact.color.opacity(0.12))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(contact.name)
                                        .font(.system(size: 16))
                                        .foregroundColor(.primary)
                                    Text(contact.number)
                                        .font(.system(size: 13))
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                            }
                        }
                    }
                } header: {
                    Text("Tap to call")
                } footer: {
                    Text("These numbers are available 24/7 for emergencies and urgent situations.")
                }

                Section {
                    Button {
                        callNumber("911")
                    } label: {
                        HStack {
                            Image(systemName: "staroflife.fill")
                                .foregroundColor(.red)
                            Text("Call 911")
                                .fontWeight(.semibold)
                                .foregroundColor(.red)
                            Spacer()
                            Image(systemName: "phone.fill")
                                .foregroundColor(.red)
                        }
                    }
                } footer: {
                    Text("For life-threatening emergencies, always call 911 first.")
                }
            }
            .navigationTitle("Emergency Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func callNumber(_ number: String) {
        let cleanedNumber = number.replacingOccurrences(of: "-", with: "")
        if let url = URL(string: "tel://\(cleanedNumber)") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    RAHomeView()
        .environmentObject(RoleManager())
        .environmentObject(ResourceStore())
}
