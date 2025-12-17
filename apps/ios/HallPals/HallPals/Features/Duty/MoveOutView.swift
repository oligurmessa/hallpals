import SwiftUI

struct MoveOutView: View {
    @StateObject private var viewModel = MoveOutViewModel()
    @State private var showingNewRequest = false
    @State private var selectedResident: Resident?
    @State private var searchText = ""

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Auth Status / Setup Required
                if !MSGraphConfig.isConfigured {
                    setupRequiredCard
                        .padding(.horizontal, 20)
                } else if !viewModel.isAuthenticated {
                    signInCard
                        .padding(.horizontal, 20)
                } else {
                    // Search
                    searchBar
                        .padding(.horizontal, 20)

                    // Stats summary
                    statsSection
                        .padding(.horizontal, 20)

                    // Residents list
                    residentsSection
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Move Out")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingNewRequest) {
            if let resident = selectedResident {
                NewMoveOutRequestSheet(resident: resident, viewModel: viewModel)
            }
        }
        .task {
            if MSGraphConfig.isConfigured && viewModel.isAuthenticated {
                await viewModel.loadResidents()
            }
        }
        .refreshable {
            await viewModel.loadResidents()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Move Out")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text("Manage resident move out requests")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Setup Required Card

    private var setupRequiredCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "arrow.uturn.left.circle")
                .font(.system(size: 44))
                .foregroundColor(.secondary)

            Text("Not Available Yet")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text("Move out tracking hasn't been set up for your hall yet. Please check with your staff or hall director for more information.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Sign In Card

    private var signInCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.badge.key")
                .font(.system(size: 40))
                .foregroundColor(.blue)

            Text("Sign In Required")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text("Sign in with your university account to access the residents Excel file.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                Task {
                    await viewModel.signIn()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "person.crop.circle.badge.checkmark")
                    Text("Sign In with Microsoft")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }

            if let error = viewModel.errorMessage {
                Text(error)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            TextField("Search residents...", text: $searchText)
                .font(.system(size: 16))

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Stats Section

    private var statsSection: some View {
        HStack(spacing: 12) {
            statCard(
                value: "\(viewModel.residents.count)",
                label: "Total",
                color: .blue
            )

            statCard(
                value: "\(viewModel.pendingCount)",
                label: "Pending",
                color: .orange
            )

            statCard(
                value: "\(viewModel.scheduledCount)",
                label: "Scheduled",
                color: .purple
            )
        }
    }

    private func statCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)

            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Residents Section

    private var residentsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Residents")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if viewModel.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)

            if viewModel.isLoading && viewModel.residents.isEmpty {
                loadingView
            } else if filteredResidents.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(filteredResidents.enumerated()), id: \.element.id) { index, resident in
                        ResidentRow(
                            resident: resident,
                            isLast: index == filteredResidents.count - 1
                        ) {
                            selectedResident = resident
                            showingNewRequest = true
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
    }

    private var filteredResidents: [Resident] {
        if searchText.isEmpty {
            return viewModel.residents
        }
        return viewModel.residents.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.room.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading residents...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }

    private var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: "person.3")
                .font(.system(size: 40))
                .foregroundColor(Color(UIColor.systemGray3))

            Text(searchText.isEmpty ? "No residents found" : "No matching residents")
                .font(.system(size: 16))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 200)
    }
}

// MARK: - Resident Row

struct ResidentRow: View {
    let resident: Resident
    let isLast: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Avatar
                    ZStack {
                        Circle()
                            .fill(statusColor.opacity(0.15))
                            .frame(width: 44, height: 44)

                        Text(resident.initials)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(statusColor)
                    }

                    // Info
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text(resident.name)
                                .font(.system(size: 16, weight: .medium))
                                .foregroundColor(.primary)

                            Spacer()

                            statusPill
                        }

                        HStack(spacing: 12) {
                            Label(resident.room, systemImage: "door.left.hand.closed")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)

                            if let date = resident.moveOutDate {
                                Label(date, systemImage: "calendar")
                                    .font(.system(size: 13))
                                    .foregroundColor(.secondary)
                            }
                        }
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)

                if !isLast {
                    Divider()
                        .padding(.leading, 74)
                }
            }
        }
    }

    private var statusColor: Color {
        switch resident.moveOutStatus {
        case .none: return .green
        case .requested: return .orange
        case .approved: return .blue
        case .scheduled: return .purple
        case .completed: return .gray
        case .cancelled: return .red
        }
    }

    private var statusPill: some View {
        Text(resident.moveOutStatus.displayName)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(statusColor)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(statusColor.opacity(0.12))
            .cornerRadius(6)
    }
}

// MARK: - New Move Out Request Sheet

struct NewMoveOutRequestSheet: View {
    let resident: Resident
    @ObservedObject var viewModel: MoveOutViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedDate = Date()
    @State private var reason = ""
    @State private var notes = ""
    @State private var isSubmitting = false

    private let reasons = [
        "End of semester",
        "Transfer",
        "Personal reasons",
        "Medical",
        "Early graduation",
        "Other"
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Resident info
                    residentInfoCard

                    // Request form
                    formSection
                }
                .padding(20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Move Out Request")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("Submit") {
                        submitRequest()
                    }
                    .disabled(reason.isEmpty || isSubmitting)
                }
            }
        }
    }

    private var residentInfoCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 56, height: 56)

                Text(resident.initials)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(resident.name)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.primary)

                HStack(spacing: 16) {
                    Label(resident.room, systemImage: "door.left.hand.closed")
                    Label(resident.email, systemImage: "envelope")
                }
                .font(.system(size: 13))
                .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    private var formSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            // Date picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Requested Move Out Date")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                DatePicker(
                    "Date",
                    selection: $selectedDate,
                    in: Date()...,
                    displayedComponents: .date
                )
                .datePickerStyle(.graphical)
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

            // Reason picker
            VStack(alignment: .leading, spacing: 8) {
                Text("Reason")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                VStack(spacing: 0) {
                    ForEach(reasons, id: \.self) { reasonOption in
                        Button {
                            reason = reasonOption
                        } label: {
                            HStack {
                                Text(reasonOption)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)

                                Spacer()

                                if reason == reasonOption {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 14, weight: .semibold))
                                        .foregroundColor(.blue)
                                }
                            }
                            .padding(.horizontal, 16)
                            .padding(.vertical, 14)
                        }

                        if reasonOption != reasons.last {
                            Divider()
                                .padding(.leading, 16)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
            }

            // Notes
            VStack(alignment: .leading, spacing: 8) {
                Text("Additional Notes")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                TextEditor(text: $notes)
                    .font(.system(size: 16))
                    .frame(minHeight: 100)
                    .padding(12)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            }
        }
    }

    private func submitRequest() {
        isSubmitting = true

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let request = MoveOutRequest(
            resident: resident,
            date: dateFormatter.string(from: selectedDate),
            reason: reason,
            notes: notes.isEmpty ? nil : notes
        )

        Task {
            do {
                try await viewModel.submitMoveOutRequest(request)
                dismiss()
            } catch {
                // Error handled by viewModel
            }
            isSubmitting = false
        }
    }
}

// MARK: - View Model

@MainActor
class MoveOutViewModel: ObservableObject {
    @Published var residents: [Resident] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var isAuthenticated = false

    private let authManager = MSALAuthManager.shared
    private let workbookService = GraphWorkbookService.shared

    // For v1 testing, use mock data if not configured
    private var useMockData: Bool {
        !MSGraphConfig.isConfigured
    }

    init() {
        isAuthenticated = authManager.isAuthenticated

        // Use mock data for testing when not configured
        if useMockData {
            residents = Resident.mockResidents
        }
    }

    var pendingCount: Int {
        residents.filter { $0.moveOutStatus == .requested || $0.moveOutStatus == .approved }.count
    }

    var scheduledCount: Int {
        residents.filter { $0.moveOutStatus == .scheduled }.count
    }

    func signIn() async {
        do {
            try await authManager.signIn()
            isAuthenticated = true
            await loadResidents()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loadResidents() async {
        // Use mock data for testing
        if useMockData {
            residents = Resident.mockResidents
            return
        }

        isLoading = true
        errorMessage = nil

        do {
            try await workbookService.initializeWorkbookAccess()
            residents = try await workbookService.fetchResidents()
        } catch {
            errorMessage = error.localizedDescription
            // Fall back to mock data on error
            residents = Resident.mockResidents
        }

        isLoading = false
    }

    func submitMoveOutRequest(_ request: MoveOutRequest) async throws {
        // For v1 testing, just simulate success
        if useMockData {
            // Update local state
            if let index = residents.firstIndex(where: { $0.room == request.room }) {
                residents[index].moveOutStatus = .requested
                residents[index].moveOutDate = request.requestedDate
            }
            return
        }

        isLoading = true

        do {
            try await workbookService.addMoveOutRequest(request)

            // Also update the resident's status
            if let resident = residents.first(where: { $0.room == request.room }) {
                try await workbookService.updateResidentStatus(
                    rowIndex: resident.rowIndex,
                    status: .requested,
                    date: request.requestedDate
                )
            }

            // Reload data
            await loadResidents()
        } catch {
            errorMessage = error.localizedDescription
            throw error
        }

        isLoading = false
    }
}

#Preview {
    NavigationStack {
        MoveOutView()
    }
}
