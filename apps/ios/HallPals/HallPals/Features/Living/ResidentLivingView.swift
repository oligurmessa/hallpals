import SwiftUI

/// Resident Living View - Replaces Duty tab for residents
/// Features: Maintenance Requests, Move-Out Checklist, FAQs, AI Chat
struct ResidentLivingView: View {
    @StateObject private var livingService = ResidentLivingService.shared
    @StateObject private var userManager = UserManager.shared
    @ObservedObject private var moveOutService = MoveOutChecklistService.shared
    @EnvironmentObject private var roleManager: RoleManager
    @State private var navigateToAI = false
    @State private var showingMoveOutChecklist = false
    @State private var showingFAQs = false
    @State private var showingReportConcern = false
    @State private var selectedWebLink: LivingWebLink?

    private var hallId: String {
        userManager.hallId ?? ""
    }

    // Web links for maintenance/services
    enum LivingWebLink: String, Identifiable {
        case housingPortal = "https://rmsstudent.stthomas.edu/page/HousingPortal"
        case techAssist = "https://services.stthomas.edu/TDClient/1898/ClientPortal/Requests/ServiceDet?ID=54174"
        case roommateAgreements = "https://roompact.com/roommateAgreements"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .housingPortal: return "Housing Portal"
            case .techAssist: return "Tech Assist"
            case .roommateAgreements: return "Roommate Agreements"
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

                    // Move-Out Checklist Section (only show if published)
                    if moveOutService.currentTemplate != nil {
                        moveOutSection
                            .padding(.horizontal, 20)
                    }

                    // FAQs Section
                    faqsSection
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
                moveOutService.stopListening()
            }
            .fullScreenCover(isPresented: $navigateToAI) {
                AIChatView()
            }
            .navigationDestination(item: $selectedWebLink) { link in
                if let url = URL(string: link.rawValue) {
                    InAppBrowserView(url: url, title: link.title)
                } else {
                    Text("Unable to load \(link.title)")
                        .foregroundColor(.secondary)
                }
            }
            .sheet(isPresented: $showingMoveOutChecklist) {
                ResidentMoveOutChecklistView()
            }
            .fullScreenCover(isPresented: $showingFAQs) {
                FAQsFullScreenView(hallId: hallId)
            }
            .sheet(isPresented: $showingReportConcern) {
                ReportConcernSheet(hallId: hallId)
            }
        }
    }

    // MARK: - Load Data

    private func loadData() {
        guard !hallId.isEmpty else { return }

        // Start move-out checklist listener (uses new Firebase service)
        moveOutService.startListening(hallId: hallId)

        // Load FAQs
        Task {
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

                Divider()
                    .padding(.leading, 62)

                // Report a Concern
                Button {
                    showingReportConcern = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.bubble.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                            .frame(width: 32, height: 32)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report a Concern")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Anonymous option available")
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

                // Roommate Agreements - Roompact
                Button {
                    selectedWebLink = .roommateAgreements
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "person.2.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.purple)
                            .frame(width: 32, height: 32)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Roommate Agreements")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Roompact")
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

    
    // MARK: - Mail & Packages Section

    private var mailAndPackagesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mail & Packages")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                if livingService.isLoadingMail {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                    .padding(.vertical, 20)
                } else if livingService.mailItems.isEmpty {
                    // No mail state
                    HStack(spacing: 14) {
                        Image(systemName: "tray.fill")
                            .font(.system(size: 20))
                            .foregroundColor(.secondary)
                            .frame(width: 32, height: 32)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("No mail waiting")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("You'll be notified when something arrives")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                } else {
                    // Mail items list
                    ForEach(Array(livingService.mailItems.prefix(3).enumerated()), id: \.element.id) { index, item in
                        mailItemRow(item, isLast: index == min(2, livingService.mailItems.count - 1))
                    }

                    // Show more indicator if there are more items
                    if livingService.mailItems.count > 3 {
                        Divider()
                            .padding(.leading, 62)

                        HStack {
                            Spacer()
                            Text("+\(livingService.mailItems.count - 3) more")
                                .font(.system(size: 13))
                                .foregroundColor(.blue)
                            Spacer()
                        }
                        .padding(.vertical, 10)
                    }
                }

                // Mailroom info
                Divider()

                HStack {
                    Image(systemName: "clock")
                        .font(.system(size: 12))
                        .foregroundColor(.secondary)
                    Text("Mailroom: Mon-Fri 9AM-5PM, Sat 10AM-2PM")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func mailItemRow(_ item: ResidentLivingService.MailItem, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: item.type.icon)
                    .font(.system(size: 18))
                    .foregroundColor(mailItemColor(item.type))
                    .frame(width: 32, height: 32)
                    .background(mailItemColor(item.type).opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(item.type.displayName)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text("From: \(item.sender)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)

                        if let carrier = item.carrier {
                            Text("•")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                            Text(carrier)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                Text(item.timeAgoText)
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 62)
            }
        }
    }

    private func mailItemColor(_ type: ResidentLivingService.MailItem.MailType) -> Color {
        switch type {
        case .letter: return .blue
        case .package: return .orange
        case .largePackage: return .purple
        case .certified: return .green
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

                        if let template = moveOutService.currentTemplate {
                            HStack(spacing: 6) {
                                Text(template.title)
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)

                                // Progress indicator
                                if moveOutService.residentChecklist?.isComplete == true {
                                    HStack(spacing: 4) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundColor(.green)
                                            .font(.system(size: 12))
                                        Text("Complete!")
                                            .font(.system(size: 12, weight: .medium))
                                            .foregroundColor(.green)
                                    }
                                } else {
                                    ProgressView(value: moveOutService.completionProgress)
                                        .frame(width: 50)
                                        .tint(.purple)
                                }
                            }
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

    // MARK: - FAQs Section

    private var faqsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Information")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
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

// MARK: - FAQs Full Screen View

struct FAQsFullScreenView: View {
    let hallId: String
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var livingService = ResidentLivingService.shared
    @State private var expandedFAQId: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    if livingService.isLoadingFAQs {
                        VStack(spacing: 12) {
                            ProgressView()
                            Text("Loading FAQs...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity, minHeight: 300)
                    } else if livingService.faqs.isEmpty {
                        emptyStateView
                            .padding(.top, 60)
                    } else {
                        faqListView
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Frequently Asked Questions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)
                    }
                }
            }
            .onAppear {
                loadFAQs()
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 56))
                .foregroundColor(.secondary)

            Text("No FAQs Available")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Text("Your hall staff hasn't posted any FAQs yet. Check back later for helpful information!")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
        }
    }

    // MARK: - FAQ List

    private var faqListView: some View {
        VStack(spacing: 12) {
            // Group by category
            let faqsByCategory = Dictionary(grouping: livingService.faqs, by: { $0.category })
            let sortedCategories = faqsByCategory.keys.sorted()

            ForEach(sortedCategories, id: \.self) { category in
                if let faqs = faqsByCategory[category] {
                    categorySection(category: category, faqs: faqs)
                }
            }
        }
    }

    private func categorySection(category: String, faqs: [ResidentLivingService.FAQ]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(faqs.enumerated()), id: \.element.id) { index, faq in
                    faqRow(faq: faq, isLast: index == faqs.count - 1)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    private func faqRow(faq: ResidentLivingService.FAQ, isLast: Bool) -> some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3)) {
                    if expandedFAQId == faq.id {
                        expandedFAQId = nil
                    } else {
                        expandedFAQId = faq.id
                    }
                }
            } label: {
                HStack(alignment: .top, spacing: 12) {
                    Image(systemName: "questionmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundColor(.blue)

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text(faq.question)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)
                                .multilineTextAlignment(.leading)

                            Spacer()

                            Image(systemName: expandedFAQId == faq.id ? "chevron.up" : "chevron.down")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.secondary)
                        }

                        if expandedFAQId == faq.id {
                            Text(faq.answer)
                                .font(.system(size: 15))
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.leading)
                                .padding(.top, 4)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .buttonStyle(.plain)

            if !isLast {
                Divider()
                    .padding(.leading, 48)
            }
        }
    }

    // MARK: - Load FAQs

    private func loadFAQs() {
        guard !hallId.isEmpty else {
            #if DEBUG
            print("📚 FAQsView: No hall ID provided")
            #endif
            return
        }

        #if DEBUG
        print("📚 FAQsView: Loading FAQs for hall \(hallId)")
        #endif

        Task {
            await livingService.loadFAQs(hallId: hallId)
        }
    }
}

// MARK: - Report Concern Sheet

struct ReportConcernSheet: View {
    let hallId: String
    @Environment(\.dismiss) private var dismiss
    @StateObject private var livingService = ResidentLivingService.shared

    @State private var selectedCategory: ResidentLivingService.Concern.Category = .other
    @State private var description = ""
    @State private var location = ""
    @State private var isAnonymous = false
    @State private var showingConfirmation = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ResidentLivingService.Concern.Category.allCases, id: \.self) { category in
                            HStack {
                                Image(systemName: category.icon)
                                Text(category.displayName)
                            }
                            .tag(category)
                        }
                    }
                } header: {
                    Text("What type of concern?")
                }

                Section {
                    TextEditor(text: $description)
                        .frame(minHeight: 100)
                } header: {
                    Text("Describe the concern")
                } footer: {
                    Text("Be specific about what happened and when")
                }

                Section {
                    TextField("Location (optional)", text: $location)
                } header: {
                    Text("Location")
                } footer: {
                    Text("e.g., Room 305, 3rd floor lounge, laundry room")
                }

                Section {
                    Toggle(isOn: $isAnonymous) {
                        HStack {
                            Image(systemName: "eye.slash.fill")
                                .foregroundColor(.orange)
                            Text("Submit Anonymously")
                        }
                    }
                } footer: {
                    Text(isAnonymous
                        ? "Your identity will not be shared with anyone reviewing this concern."
                        : "Your contact info may be used for follow-up if needed.")
                }

                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                }
            }
            .navigationTitle("Report a Concern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Submit") {
                        submitConcern()
                    }
                    .fontWeight(.semibold)
                    .disabled(description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || livingService.isSubmittingConcern)
                }
            }
            .alert("Concern Submitted", isPresented: $showingConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Thank you for reporting this concern. Staff will review it and take appropriate action.")
            }
        }
    }

    private func submitConcern() {
        errorMessage = nil

        Task {
            do {
                _ = try await livingService.submitConcern(
                    hallId: hallId,
                    category: selectedCategory,
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    location: location.isEmpty ? nil : location.trimmingCharacters(in: .whitespacesAndNewlines),
                    isAnonymous: isAnonymous
                )
                showingConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ResidentLivingView()
        .environmentObject(RoleManager())
}
