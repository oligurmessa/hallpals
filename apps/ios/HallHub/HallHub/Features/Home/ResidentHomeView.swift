import SwiftUI

// MARK: - ResidentHomeView

struct ResidentHomeView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @StateObject private var service = ResidentHomeService.shared

    @State private var showLockoutSheet = false
    @State private var showPoliciesSheet = false
    @State private var showNoiseReportSheet = false
    @State private var navigateToEmergency = false
    @State private var showingSettings = false
    @State private var navigateToAI = false

    private let hallId = FirestoreService.devHallId

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // AI Assistant Card
                    aiAssistantCard

                    // On-Duty RA Card
                    onDutyRACard

                    // Your RA Section
                    yourRASection

                    // Noise Report Section
                    noiseReportSection

                    // Upcoming Events
                    upcomingEventsSection

                    // Quick Help
                    quickHelpSection
                }
                .padding(AppSpacing.md)
            }
            .background(Color.appBackground)
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        showingSettings = true
                    } label: {
                        Image(systemName: "gearshape.fill")
                            .foregroundColor(.appPrimary)
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    notificationsButton
                }
            }
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }
            .navigationDestination(isPresented: $navigateToEmergency) {
                ResidentEmergencyView()
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
                startListeners()
            }
            .onDisappear {
                service.stopAllListeners()
            }
        }
    }

    private func startListeners() {
        service.startListeningForDutyRA(hallId: hallId)
        service.startListeningForEvents(hallId: hallId)
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

    // MARK: - On-Duty RA Card

    private var onDutyRACard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "person.badge.shield.checkmark.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.appPrimary)
                    Text("On-Duty RA")
                        .appStyle(.titleSmall)
                    Spacer()

                    if service.isLoadingDutyRA {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }

                if let ra = service.onDutyRA {
                    HStack(spacing: AppSpacing.md) {
                        // Avatar
                        Circle()
                            .fill(Color.appPrimary.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(ra.displayName.prefix(1))
                                    .appStyle(.titleMedium, color: .appPrimary)
                            )

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(ra.displayName)
                                .appStyle(.body)

                            if let room = ra.room {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "door.left.hand.closed")
                                        .foregroundColor(.textSecondary)
                                    Text(room)
                                        .appStyle(.caption, color: .textSecondary)
                                }
                            }

                            HStack(spacing: AppSpacing.sm) {
                                Image(systemName: "clock")
                                    .foregroundColor(.textSecondary)
                                Text(ra.shiftTimeText)
                                    .appStyle(.caption, color: .textSecondary)
                            }
                        }

                        Spacer()

                        // Status indicator
                        VStack {
                            Circle()
                                .fill(ra.isCurrentlyOnDuty ? Color.green : Color.orange)
                                .frame(width: 10, height: 10)
                            Text(ra.isCurrentlyOnDuty ? "On Duty" : "Ending Soon")
                                .font(.system(size: 10))
                                .foregroundColor(ra.isCurrentlyOnDuty ? .green : .orange)
                        }
                    }

                    // Contact buttons
                    HStack(spacing: AppSpacing.sm) {
                        if let phone = ra.dutyPhone {
                            Button {
                                callPhone(phone)
                            } label: {
                                HStack {
                                    Image(systemName: "phone.fill")
                                    Text("Call")
                                }
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.appPrimary)
                                .cornerRadius(AppRadius.button)
                            }
                        }

                        Button {
                            // TODO: Implement DM functionality - requires hall/resident/RA manifest
                        } label: {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("DM")
                            }
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.appPrimary)
                            .frame(maxWidth: .infinity)
                            .frame(height: 44)
                            .background(Color.clear)
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.button)
                                    .stroke(Color.appPrimary, lineWidth: 1)
                            )
                        }

                        Button {
                            navigateToEmergency = true
                        } label: {
                            Text("Emergency")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(.appError)
                                .frame(maxWidth: .infinity)
                                .frame(height: 44)
                                .background(Color.clear)
                                .overlay(
                                    RoundedRectangle(cornerRadius: AppRadius.button)
                                        .stroke(Color.appError, lineWidth: 1)
                                )
                        }
                    }
                } else {
                    // No RA on duty
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "moon.zzz.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.textSecondary)
                        Text("No RA currently on duty")
                            .appStyle(.body, color: .textSecondary)
                        Text("For emergencies, call campus security")
                            .appStyle(.caption, color: .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Your RA Section

    private var yourRASection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "person.crop.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.appSecondary)
                    Text("Your RA")
                        .appStyle(.titleSmall)
                    Spacer()
                }

                // TODO: Load assigned RA from hall/resident/RA manifest
                // For now, show placeholder
                if let assignedRA = service.assignedRA {
                    HStack(spacing: AppSpacing.md) {
                        // Avatar
                        Circle()
                            .fill(Color.appSecondary.opacity(0.2))
                            .frame(width: 56, height: 56)
                            .overlay(
                                Text(assignedRA.displayName.prefix(1))
                                    .appStyle(.titleMedium, color: .appSecondary)
                            )

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text(assignedRA.displayName)
                                .appStyle(.body)

                            if let room = assignedRA.room {
                                HStack(spacing: AppSpacing.sm) {
                                    Image(systemName: "door.left.hand.closed")
                                        .foregroundColor(.textSecondary)
                                    Text("Room \(room)")
                                        .appStyle(.caption, color: .textSecondary)
                                }
                            }
                        }

                        Spacer()
                    }

                    // DM Button
                    Button {
                        // TODO: Implement DM functionality - requires hall/resident/RA manifest
                    } label: {
                        HStack {
                            Image(systemName: "message.fill")
                            Text("Send Message")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(Color.appSecondary)
                        .cornerRadius(AppRadius.button)
                    }
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "person.crop.circle.badge.questionmark")
                            .font(.system(size: 32))
                            .foregroundColor(.textSecondary)
                        Text("RA not assigned yet")
                            .appStyle(.body, color: .textSecondary)
                        Text("Your RA will appear here once assigned")
                            .appStyle(.caption, color: .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Noise Report Section

    private var noiseReportSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.orange)
                    Text("Anonymous Noise Complaints")
                        .appStyle(.titleSmall)
                }

                Text("Report excessive noise anonymously to the on-duty RA")
                    .appStyle(.caption, color: .textSecondary)

                Button {
                    showNoiseReportSheet = true
                } label: {
                    HStack {
                        Image(systemName: "exclamationmark.bubble.fill")
                        Text("Report Noise")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 44)
                    .background(Color.orange)
                    .cornerRadius(AppRadius.button)
                }

                if let lastReport = service.lastReportSubmittedAt {
                    Text("Last report: \(lastReport.formatted(date: .abbreviated, time: .shortened))")
                        .font(.system(size: 11))
                        .foregroundColor(.textSecondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    // MARK: - Upcoming Events Section

    private var upcomingEventsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Text("Upcoming Events")
                    .appStyle(.titleSmall)
                Spacer()

                if service.isLoadingEvents {
                    ProgressView()
                        .scaleEffect(0.7)
                }
            }
            .padding(.horizontal, AppSpacing.xs)

            AppCard {
                if service.upcomingEvents.isEmpty && !service.isLoadingEvents {
                    VStack(spacing: AppSpacing.sm) {
                        Image(systemName: "calendar.badge.clock")
                            .font(.system(size: 28))
                            .foregroundColor(.textSecondary)
                        Text("No upcoming events")
                            .appStyle(.body, color: .textSecondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, AppSpacing.md)
                } else {
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(Array(service.upcomingEvents.prefix(3).enumerated()), id: \.element.id) { index, event in
                            FirebaseEventRow(event: event)

                            if index < min(service.upcomingEvents.count, 3) - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Quick Help Section

    private var quickHelpSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Quick Help")
                .appStyle(.titleSmall)
                .padding(.horizontal, AppSpacing.xs)

            AppCard {
                VStack(spacing: 0) {
                    QuickHelpRow(title: "What to do in a lockout", icon: "key.fill") {
                        showLockoutSheet = true
                    }

                    Divider()

                    QuickHelpRow(title: "Quiet hours & policies", icon: "moon.fill") {
                        showPoliciesSheet = true
                    }
                }
            }
        }
    }

    // MARK: - Notifications Button

    private var notificationsButton: some View {
        Button {
            // TODO: Navigate to notifications view
        } label: {
            Image(systemName: "bell.fill")
                .font(.system(size: 18))
                .foregroundColor(.appPrimary)
        }
    }

    // MARK: - Helpers

    private func callPhone(_ number: String) {
        let cleaned = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
        if let url = URL(string: "tel://\(cleaned)") {
            UIApplication.shared.open(url)
        }
    }
}

// MARK: - Firebase Event Row

struct FirebaseEventRow: View {
    let event: ResidentHomeService.HallEvent

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(event.title)
                    .appStyle(.body)

                HStack(spacing: AppSpacing.sm) {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                        Text(event.timeText)
                    }
                    if let location = event.location {
                        HStack(spacing: 4) {
                            Image(systemName: "mappin")
                            Text(location)
                        }
                    }
                }
                .appFont(.caption)
                .foregroundColor(.textSecondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(.textSecondary)
        }
    }
}

// MARK: - Quick Help Row

struct QuickHelpRow: View {
    let title: String
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(.appPrimary)
                    .frame(width: 24)

                Text(title)
                    .appStyle(.body)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
            .padding(.vertical, AppSpacing.sm)
        }
        .buttonStyle(.plain)
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
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Image(systemName: "key.fill")
                                    .foregroundColor(.appSecondary)
                                Text("Lockout Procedure")
                                    .appStyle(.titleSmall)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                BulletPoint(text: "Contact your RA first if available")
                                BulletPoint(text: "If after hours, call the Duty Phone: (651) 555-0199")
                                BulletPoint(text: "Have your student ID ready")
                                BulletPoint(text: "First 2 lockouts per semester are free")
                                BulletPoint(text: "Additional lockouts: $25 fee")
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Duty Phone")
                                .appStyle(.titleSmall)

                            HStack {
                                Image(systemName: "phone.fill")
                                    .foregroundColor(.appPrimary)
                                Text("(651) 555-0199")
                                    .appStyle(.body)
                            }

                            Text("Available 8 PM – 8 AM")
                                .appStyle(.caption, color: .textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.appBackground)
            .navigationTitle("Lockout Help")
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

struct PoliciesInfoSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: AppSpacing.lg) {
                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Image(systemName: "moon.fill")
                                    .foregroundColor(.appPrimary)
                                Text("Quiet Hours")
                                    .appStyle(.titleSmall)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                BulletPoint(text: "Sunday – Thursday: 10 PM – 8 AM")
                                BulletPoint(text: "Friday – Saturday: 12 AM – 10 AM")
                                BulletPoint(text: "24-hour quiet hours during finals")
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.md) {
                            HStack {
                                Image(systemName: "person.2.fill")
                                    .foregroundColor(.appPrimary)
                                Text("Guest Policy")
                                    .appStyle(.titleSmall)
                            }

                            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                                BulletPoint(text: "Guests must be escorted at all times")
                                BulletPoint(text: "Sign in at the front desk")
                                BulletPoint(text: "Overnight guests: 3 nights max per week")
                            }
                        }
                    }

                    AppCard {
                        VStack(alignment: .leading, spacing: AppSpacing.sm) {
                            Text("Questions?")
                                .appStyle(.titleSmall)

                            Text("Talk to your RA or visit the Residence Life office in Murray Hall.")
                                .appStyle(.body, color: .textSecondary)
                        }
                    }
                }
                .padding(AppSpacing.md)
            }
            .background(Color.appBackground)
            .navigationTitle("Policies")
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

struct BulletPoint: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.sm) {
            Text("•")
                .appStyle(.body, color: .textSecondary)
            Text(text)
                .appStyle(.body)
        }
    }
}

// MARK: - Preview

#Preview {
    ResidentHomeView()
        .environmentObject(RoleManager())
}
