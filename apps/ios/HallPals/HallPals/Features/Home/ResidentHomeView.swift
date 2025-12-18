import SwiftUI

// MARK: - ResidentHomeView

struct ResidentHomeView: View {
    @EnvironmentObject private var roleManager: RoleManager
    // OPTIMIZED: Observe UserManager directly for reactive updates
    // UserManager loads resident data (on-duty RA, assigned RA, events) in parallel on login
    @StateObject private var userManager = UserManager.shared

    // Backward compatibility alias for service methods (noise reports, room inspections)
    private var service: ResidentHomeService { ResidentHomeService.shared }

    @State private var showLockoutSheet = false
    @State private var showPoliciesSheet = false
    @State private var showNoiseReportSheet = false
    @State private var showReportConcernSheet = false
    @State private var showingLockedOut = false
    @State private var showingSettings = false
    @State private var navigateToAI = false
    @State private var resolvedHallId: String?
    @State private var isLoadingHallId = false
    /// Get the current hall ID - prefer resolved, then userManager, empty string if none
    private var hallId: String {
        resolvedHallId ?? userManager.hallId ?? ""
    }

    /// Whether user has a valid hall assigned
    private var hasHallAssigned: Bool {
        !hallId.isEmpty
    }

    private let currentTime = Date()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Greeting header
                    greetingSection
                        .padding(.horizontal, 20)

                    // My Room & RA Card (consolidated)
                    myRoomAndRACard
                        .padding(.horizontal, 20)

                    // AI Assistant Card
                    aiAssistantCard
                        .padding(.horizontal, 20)

                    // Noise Report Section
                    noiseReportSection
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
            .sheet(isPresented: $showingLockedOut) {
                LockedOutSheet()
            }
            .sheet(isPresented: $showLockoutSheet) {
                LockoutInfoSheet()
            }
            .sheet(isPresented: $showPoliciesSheet) {
                PoliciesInfoSheet()
            }
            .sheet(isPresented: $showNoiseReportSheet) {
                NoiseReportSheet(hallId: hallId)
            }
            .fullScreenCover(isPresented: $navigateToAI) {
                AIChatView()
            }
            .onAppear {
                loadHallIdAndStartListeners()
            }
            .onDisappear {
                // Data is managed by UserManager - no need to stop listeners here
                // UserManager keeps listeners active for the session
            }
        }
    }

    /// Load hall ID (with fallback to members collection group) then start listeners
    private func loadHallIdAndStartListeners() {
        // If we already have a hall ID, start listeners immediately
        if hasHallAssigned {
            startListeners()
            return
        }

        // Try to resolve hall ID via members collection group
        isLoadingHallId = true
        Task {
            do {
                let fetchedHallId = try await userManager.fetchHallIdWithFallback()
                await MainActor.run {
                    self.resolvedHallId = fetchedHallId
                    self.isLoadingHallId = false
                    if fetchedHallId != nil {
                        startListeners()
                    }
                }
            } catch {
                await MainActor.run {
                    self.isLoadingHallId = false
                    #if DEBUG
                    print("🏠 RESIDENT: Failed to fetch hall ID: \(error.localizedDescription)")
                    #endif
                }
            }
        }
    }

    private func startListeners() {
        guard hasHallAssigned else {
            #if DEBUG
            print("🏠 RESIDENT: Cannot start listeners - no hall assigned")
            #endif
            return
        }

        // OPTIMIZED: Data is already loaded by UserManager on resident login
        // Only refresh if explicitly empty and not loading
        if !userManager.isLoadingResidentData {
            let needsRefresh = (userManager.onDutyRA == nil && userManager.onDutyRALoaded) ||
                               (userManager.upcomingEvents.isEmpty && userManager.eventsLoaded)
            if needsRefresh {
                userManager.refreshResidentData()
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
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }

    private var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: currentTime)
    }

    // MARK: - My Room & RA Card (Consolidated)

    private var myRoomAndRACard: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Header
            HStack {
                Image(systemName: "house.fill")
                    .font(.system(size: 20))
                    .foregroundColor(.blue)
                Text("My Room & RA")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
                Spacer()
            }

            // Room Info Row - Compact layout
            HStack(spacing: 12) {
                // Room number
                Text(userManager.roomNumber ?? "---")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.primary)

                // Separator dot
                Circle()
                    .fill(Color.secondary.opacity(0.4))
                    .frame(width: 4, height: 4)

                // Hall, Floor, Wing in one line
                HStack(spacing: 6) {
                    if let hall = userManager.currentHall {
                        Text(hall.name)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.primary)
                    }

                    if let floor = userManager.floor {
                        Text("• Floor \(floor)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    if let wing = userManager.wing, !wing.isEmpty {
                        Text("• \(wing)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color.blue.opacity(0.08))
            .cornerRadius(10)

            Divider()

            // Your RA Section
            if let assignedRA = userManager.assignedRA {
                VStack(alignment: .leading, spacing: 12) {
                    Text("YOUR RA")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    HStack(spacing: 12) {
                        // Avatar
                        Circle()
                            .fill(Color.purple.opacity(0.15))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(assignedRA.displayName.prefix(1)))
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundColor(.purple)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text(assignedRA.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)

                            if let room = assignedRA.room {
                                Text("Room \(room)")
                                    .font(.system(size: 12))
                                    .foregroundColor(.secondary)
                            }
                        }

                        Spacer()

                        // DM Button (disabled)
                        HStack(spacing: 4) {
                            Image(systemName: "message.fill")
                            Text("DM")
                        }
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.gray)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(Color.gray.opacity(0.1))
                        .cornerRadius(8)
                    }
                }
            } else if userManager.isLoadingAssignedRA {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Loading your RA...")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.questionmark")
                        .font(.system(size: 16))
                        .foregroundColor(.secondary)
                    Text("RA not assigned yet")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }

            Divider()

            // On-Duty RA Section
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("ON DUTY NOW")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.secondary)
                        .tracking(0.5)

                    Spacer()

                    if userManager.isLoadingOnDutyRA {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }

                if let ra = userManager.onDutyRA {
                    HStack(spacing: 12) {
                        // Avatar with status indicator
                        ZStack(alignment: .bottomTrailing) {
                            Circle()
                                .fill(Color.green.opacity(0.15))
                                .frame(width: 44, height: 44)
                                .overlay(
                                    Text(String(ra.displayName.prefix(1)))
                                        .font(.system(size: 16, weight: .semibold))
                                        .foregroundColor(.green)
                                )

                            Circle()
                                .fill(ra.isCurrentlyOnDuty ? Color.green : Color.orange)
                                .frame(width: 12, height: 12)
                                .overlay(
                                    Circle()
                                        .stroke(Color(UIColor.secondarySystemBackground), lineWidth: 2)
                                )
                        }

                        VStack(alignment: .leading, spacing: 2) {
                            Text(ra.displayName)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)

                            HStack(spacing: 4) {
                                Image(systemName: "clock")
                                    .font(.system(size: 10))
                                Text(ra.shiftTimeText)
                                    .font(.system(size: 12))
                            }
                            .foregroundColor(.secondary)
                        }

                        Spacer()

                        // Call button only
                        if let phone = ra.dutyPhone {
                            Button {
                                callPhone(phone)
                            } label: {
                                Image(systemName: "phone.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.green)
                                    .frame(width: 36, height: 36)
                                    .background(Color.green.opacity(0.1))
                                    .cornerRadius(8)
                            }
                        }
                    }
                } else {
                    HStack(spacing: 8) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 16))
                            .foregroundColor(.secondary)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("No RA currently on duty")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text("For emergencies, call campus security")
                                .font(.system(size: 11))
                                .foregroundColor(Color(UIColor.tertiaryLabel))
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 4)
                }
            }

            // Report Concern Button (only if RA is on duty)
            if let ra = userManager.onDutyRA {
                Button {
                    showReportConcernSheet = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill")
                        Text("Report a Concern")
                    }
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                    .frame(maxWidth: .infinity)
                    .frame(height: 40)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                }
                .sheet(isPresented: $showReportConcernSheet) {
                    ReportConcernView(
                        hallId: hallId,
                        onDutyRAUid: ra.odRAuid,
                        onDutyRAName: ra.displayName
                    )
                }
            }

            // Locked Out Button
            Button {
                showingLockedOut = true
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Locked Out?")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.orange)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
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
                    Text("Get instant answers about hall life & policies")
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

    // MARK: - Noise Report Section

    private var noiseReportSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "speaker.wave.3.fill")
                    .font(.system(size: 18))
                    .foregroundColor(.orange)
                Text("Anonymous Noise Complaints")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)
            }

            Text("Report excessive noise anonymously to the on-duty RA")
                .font(.system(size: 13))
                .foregroundColor(.secondary)

            Button {
                showNoiseReportSheet = true
            } label: {
                HStack {
                    Image(systemName: "exclamationmark.bubble.fill")
                    Text("Report Noise")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 40)
                .background(Color.orange)
                .cornerRadius(10)
            }

            if let lastReport = service.lastReportSubmittedAt {
                Text("Last report: \(lastReport.formatted(date: .abbreviated, time: .shortened))")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Upcoming Events Section

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Upcoming")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if userManager.isLoadingEvents {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Button("See All") {
                        // Navigate to events
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            }

            if userManager.upcomingEvents.isEmpty && !userManager.isLoadingEvents {
                VStack(spacing: 8) {
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 28))
                        .foregroundColor(.secondary)
                    Text("No upcoming events")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(userManager.upcomingEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                        upcomingEventRow(event: event)

                        if index < min(userManager.upcomingEvents.count, 3) - 1 {
                            Divider()
                                .padding(.leading, 52)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    private func upcomingEventRow(event: HallEvent) -> some View {
        HStack(spacing: 12) {
            // Time indicator
            VStack(spacing: 2) {
                Text(event.timeText.components(separatedBy: " ").first ?? event.timeText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.primary)
                Text(event.timeText.components(separatedBy: " ").last ?? "")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
            .frame(width: 40)

            // Content
            VStack(alignment: .leading, spacing: 2) {
                Text(event.title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)

                if let location = event.location {
                    Text(location)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(Color(UIColor.systemGray3))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    // MARK: - Quick Help Section

    private var quickHelpSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Help")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                quickHelpRow(title: "What to do in a lockout", icon: "key.fill") {
                    showLockoutSheet = true
                }

                Divider()
                    .padding(.leading, 44)

                quickHelpRow(title: "Quiet hours & policies", icon: "moon.fill") {
                    showPoliciesSheet = true
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func quickHelpRow(title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.blue)
                    .frame(width: 24)

                Text(title)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Helpers

    private func callPhone(_ number: String) {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Noise Report Sheet

struct NoiseReportSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = ResidentHomeService.shared

    let hallId: String

    @State private var location = ""
    @State private var description = ""
    @State private var urgency: ResidentHomeService.NoiseReport.Urgency = .medium
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showSuccess = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Location (e.g., Room 203, 2nd Floor Lounge)", text: $location)
                } header: {
                    Text("Where is the noise coming from?")
                }

                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 80)
                } header: {
                    Text("Description (optional)")
                }

                Section {
                    Picker("Urgency", selection: $urgency) {
                        Text("Low - Minor disturbance").tag(ResidentHomeService.NoiseReport.Urgency.low)
                        Text("Medium - Ongoing issue").tag(ResidentHomeService.NoiseReport.Urgency.medium)
                        Text("High - Immediate attention").tag(ResidentHomeService.NoiseReport.Urgency.high)
                    }
                    .pickerStyle(.inline)
                } header: {
                    Text("Urgency Level")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                    }
                }

                Section {
                    Button {
                        submitReport()
                    } label: {
                        HStack {
                            Spacer()
                            if isSubmitting {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                                Text("Submit Report")
                            }
                            Spacer()
                        }
                    }
                    .disabled(location.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                    .listRowBackground(
                        location.trimmingCharacters(in: .whitespaces).isEmpty ?
                        Color.gray : Color.orange
                    )
                    .foregroundColor(.white)
                    .font(.system(size: 17, weight: .semibold))
                }
            }
            .navigationTitle("Report Noise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .alert("Report Submitted", isPresented: $showSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your noise report has been sent to the on-duty RA.")
            }
        }
        .presentationDetents([.large])
    }

    private func submitReport() {
        let trimmedLocation = location.trimmingCharacters(in: .whitespaces)
        guard !trimmedLocation.isEmpty else { return }

        isSubmitting = true
        errorMessage = nil

        Task {
            do {
                try await service.submitNoiseReport(
                    hallId: hallId,
                    location: trimmedLocation,
                    description: description.isEmpty ? nil : description,
                    urgency: urgency
                )
                await MainActor.run {
                    isSubmitting = false
                    showSuccess = true
                }
            } catch {
                await MainActor.run {
                    isSubmitting = false
                    errorMessage = error.localizedDescription
                }
            }
        }
    }
}

// MARK: - Supporting Views

struct LockoutInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "key.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.purple)
                            Text("Lockout Procedure")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "Contact your RA first if available")
                            BulletPoint(text: "If after hours, call the Duty Phone: (651) 555-0199")
                            BulletPoint(text: "Have your student ID ready")
                            BulletPoint(text: "First 2 lockouts per semester are free")
                            BulletPoint(text: "Additional lockouts: $25 fee")
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 12) {
                        Text("Duty Phone")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        HStack {
                            Image(systemName: "phone.fill")
                                .foregroundColor(.blue)
                            Text("(651) 555-0199")
                                .font(.system(size: 15))
                                .foregroundColor(.primary)
                        }

                        Text("Available 8 PM – 8 AM")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding(20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Lockout Help")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct PoliciesInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "moon.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("Quiet Hours")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "Sunday – Thursday: 10 PM – 8 AM")
                            BulletPoint(text: "Friday – Saturday: 12 AM – 10 AM")
                            BulletPoint(text: "24-hour quiet hours during finals")
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Image(systemName: "person.2.fill")
                                .font(.system(size: 20))
                                .foregroundColor(.blue)
                            Text("Guest Policy")
                                .font(.system(size: 17, weight: .semibold))
                                .foregroundColor(.primary)
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            BulletPoint(text: "Guests must be escorted at all times")
                            BulletPoint(text: "Sign in at the front desk")
                            BulletPoint(text: "Overnight guests: 3 nights max per week")
                        }
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Questions?")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Talk to your RA or visit the Residence Life office in Murray Hall.")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .padding(16)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(16)
                }
                .padding(20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Policies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }
}

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text("•")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
            Text(text)
                .font(.system(size: 15))
                .foregroundColor(.primary)
        }
    }
}

// MARK: - Preview

#Preview {
    ResidentHomeView()
        .environmentObject(RoleManager())
}
