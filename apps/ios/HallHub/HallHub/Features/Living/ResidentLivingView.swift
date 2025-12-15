import SwiftUI

/// Resident Living View - Replaces Duty tab for residents
/// Features: Maintenance Requests, Move-Out Checklist, Announcements, Floor Rules, FAQs, AI Chat
struct ResidentLivingView: View {
    @StateObject private var livingService = ResidentLivingService.shared
    @EnvironmentObject private var roleManager: RoleManager
    @State private var navigateToAI = false
    @State private var showingMoveOutChecklist = false
    @State private var showingFloorRules = false
    @State private var showingFAQs = false
    @State private var expandedAnnouncementId: String?
    @State private var selectedWebLink: LivingWebLink?

    private let hallId = "hall-001" // TODO: Get from user context

    // Web links for maintenance/services
    enum LivingWebLink: String, Identifiable {
        case housingPortal = "https://rmsstudent.stthomas.edu/page/HousingPortal"
        case techAssist = "https://services.stthomas.edu/TDClient/1898/ClientPortal/Requests/ServiceDet?ID=54174"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .housingPortal: return "Housing Portal"
            case .techAssist: return "Tech Assist"
            }
        }
    }

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

                    // Maintenance Requests Section
                    maintenanceSection
                        .padding(.horizontal, 20)

                    // Move-Out Checklist Section
                    moveOutSection
                        .padding(.horizontal, 20)

                    // Announcements Section
                    announcementsSection
                        .padding(.horizontal, 20)

                    // Floor Rules & FAQs Section
                    rulesAndFAQsSection
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                loadData()
            }
            .onDisappear {
                livingService.stopAllListeners()
            }
            .fullScreenCover(isPresented: $navigateToAI) {
                AIChatView()
            }
            .navigationDestination(item: $selectedWebLink) { link in
                InAppBrowserView(url: URL(string: link.rawValue)!, title: link.title)
            }
            .sheet(isPresented: $showingMoveOutChecklist) {
                MoveOutChecklistDetailView(hallId: hallId)
            }
            .sheet(isPresented: $showingFloorRules) {
                FloorRulesSheetView(hallId: hallId)
            }
            .sheet(isPresented: $showingFAQs) {
                FAQsSheetView(hallId: hallId)
            }
        }
    }

    // MARK: - Load Data

    private func loadData() {
        livingService.startListeningForMaintenanceRequests(hallId: hallId)
        livingService.startListeningForAnnouncements(hallId: hallId)
        Task {
            await livingService.loadMoveOutChecklist(hallId: hallId, roomNumber: "101") // TODO: Get from user
            await livingService.loadFloorRules(hallId: hallId)
            await livingService.loadFAQs(hallId: hallId)
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Living")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text("Your hall life at a glance")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    // MARK: - Services Section (Maintenance & Tech)

    private var maintenanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Services")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                // Submit Maintenance Request - Housing Portal
                Button {
                    selectedWebLink = .housingPortal
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "wrench.and.screwdriver.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                            .frame(width: 32, height: 32)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Submit Maintenance Request")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Housing Portal")
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

                // Tech Assist
                Button {
                    selectedWebLink = .techAssist
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "desktopcomputer")
                            .font(.system(size: 18))
                            .foregroundColor(.blue)
                            .frame(width: 32, height: 32)
                            .background(Color.blue.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Tech Assist")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("IT support & help desk")
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

    // MARK: - Move-Out Section

    private var moveOutSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Move-Out")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            Button {
                showingMoveOutChecklist = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "checklist")
                        .font(.system(size: 18))
                        .foregroundColor(.purple)
                        .frame(width: 32, height: 32)
                        .background(Color.purple.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Move-Out Checklist")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)

                        if let checklist = livingService.moveOutChecklist {
                            HStack(spacing: 6) {
                                Text("\(checklist.completedCount)/\(checklist.totalCount) completed")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)

                                // Progress indicator
                                ProgressView(value: checklist.progressPercentage)
                                    .frame(width: 50)
                                    .tint(checklist.progressPercentage == 1 ? .green : .purple)
                            }
                        } else {
                            Text("No checklist available yet")
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
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Announcements Section

    private var announcementsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Announcements")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if livingService.announcements.count > 3 {
                    Button("See All") {
                        // Show all announcements
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            }

            if livingService.isLoadingAnnouncements {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
                .padding(.vertical, 20)
            } else if livingService.announcements.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "megaphone")
                            .font(.system(size: 24))
                            .foregroundColor(.secondary)
                        Text("No announcements")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                }
                .padding(.vertical, 20)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(livingService.announcements.prefix(3).enumerated()), id: \.element.id) { index, announcement in
                        announcementRow(announcement, isLast: index == min(2, livingService.announcements.count - 1))
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }
        }
    }

    private func announcementRow(_ announcement: ResidentLivingService.Announcement, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation {
                    if expandedAnnouncementId == announcement.id {
                        expandedAnnouncementId = nil
                    } else {
                        expandedAnnouncementId = announcement.id
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: announcement.category.icon)
                        .font(.system(size: 16))
                        .foregroundColor(categoryColor(announcement.category))
                        .frame(width: 28, height: 28)
                        .background(categoryColor(announcement.category).opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 6))

                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            if announcement.isPinned {
                                Image(systemName: "pin.fill")
                                    .font(.system(size: 10))
                                    .foregroundColor(.red)
                            }
                            Text(announcement.title)
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.primary)
                                .lineLimit(expandedAnnouncementId == announcement.id ? nil : 1)
                        }

                        if expandedAnnouncementId == announcement.id {
                            Text(announcement.body)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                                .padding(.top, 4)
                        }

                        Text(announcement.createdAt.formatted(date: .abbreviated, time: .shortened))
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Image(systemName: expandedAnnouncementId == announcement.id ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
            }

            if !isLast {
                Divider()
                    .padding(.leading, 56)
            }
        }
    }

    private func categoryColor(_ category: ResidentLivingService.Announcement.Category) -> Color {
        switch category {
        case .general: return .blue
        case .safety: return .red
        case .event: return .purple
        case .maintenance: return .orange
        case .policy: return .gray
        }
    }

    // MARK: - Rules & FAQs Section

    private var rulesAndFAQsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                // Floor Rules
                Button {
                    showingFloorRules = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "list.bullet.clipboard.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.green)
                            .frame(width: 32, height: 32)
                            .background(Color.green.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Floor Rules & Expectations")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("\(livingService.floorRules.count) rules")
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

                // FAQs
                Button {
                    showingFAQs = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "questionmark.circle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.cyan)
                            .frame(width: 32, height: 32)
                            .background(Color.cyan.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hall FAQs")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("\(livingService.faqs.count) questions answered")
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
}

// MARK: - Move-Out Checklist Detail View

struct MoveOutChecklistDetailView: View {
    let hallId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var livingService = ResidentLivingService.shared

    var body: some View {
        NavigationStack {
            Group {
                if let checklist = livingService.moveOutChecklist {
                    List {
                        Section {
                            ForEach(checklist.items) { item in
                                HStack {
                                    Button {
                                        toggleItem(checklistId: checklist.id, item: item)
                                    } label: {
                                        Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                                            .font(.system(size: 22))
                                            .foregroundColor(item.isChecked ? .green : .gray)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.name)
                                            .font(.system(size: 16))
                                            .foregroundColor(item.isChecked ? .secondary : .primary)
                                            .strikethrough(item.isChecked)

                                        if let description = item.description {
                                            Text(description)
                                                .font(.system(size: 13))
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 4)
                            }
                        } header: {
                            HStack {
                                Text("Tasks")
                                Spacer()
                                Text("\(checklist.completedCount)/\(checklist.totalCount)")
                                    .foregroundColor(.secondary)
                            }
                        }

                        if let moveOutDate = checklist.moveOutDate {
                            Section {
                                HStack {
                                    Text("Move-Out Date")
                                    Spacer()
                                    Text(moveOutDate.formatted(date: .long, time: .omitted))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                } else {
                    VStack(spacing: 16) {
                        Image(systemName: "checklist")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Checklist Available")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Your move-out checklist will appear here when it's created by your RA.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                }
            }
            .navigationTitle("Move-Out Checklist")
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

    private func toggleItem(checklistId: String, item: ResidentLivingService.MoveOutChecklist.ChecklistItem) {
        Task {
            try? await livingService.toggleMoveOutItem(
                hallId: hallId,
                checklistId: checklistId,
                itemId: item.id,
                isChecked: !item.isChecked
            )
        }
    }
}

// MARK: - Floor Rules Sheet

struct FloorRulesSheetView: View {
    let hallId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var livingService = ResidentLivingService.shared

    var body: some View {
        NavigationStack {
            Group {
                if livingService.isLoadingRules {
                    ProgressView()
                } else if livingService.floorRules.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "list.bullet.clipboard")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No Rules Posted")
                            .font(.system(size: 17, weight: .semibold))
                        Text("Floor rules will appear here when posted by your RA.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(livingService.floorRules) { rule in
                            VStack(alignment: .leading, spacing: 8) {
                                Text(rule.title)
                                    .font(.system(size: 16, weight: .semibold))
                                Text(rule.description)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
            .navigationTitle("Floor Rules")
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
}

// MARK: - FAQs Sheet

struct FAQsSheetView: View {
    let hallId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var livingService = ResidentLivingService.shared
    @State private var expandedFAQId: String?

    var body: some View {
        NavigationStack {
            Group {
                if livingService.isLoadingFAQs {
                    ProgressView()
                } else if livingService.faqs.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "questionmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)
                        Text("No FAQs Available")
                            .font(.system(size: 17, weight: .semibold))
                        Text("FAQs will appear here when posted by your RA.")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 32)
                    }
                } else {
                    List {
                        ForEach(livingService.faqs) { faq in
                            DisclosureGroup(
                                isExpanded: Binding(
                                    get: { expandedFAQId == faq.id },
                                    set: { expandedFAQId = $0 ? faq.id : nil }
                                )
                            ) {
                                Text(faq.answer)
                                    .font(.system(size: 14))
                                    .foregroundColor(.secondary)
                                    .padding(.vertical, 8)
                            } label: {
                                Text(faq.question)
                                    .font(.system(size: 15, weight: .medium))
                            }
                        }
                    }
                }
            }
            .navigationTitle("FAQs")
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
}

#Preview {
    ResidentLivingView()
        .environmentObject(RoleManager())
}
