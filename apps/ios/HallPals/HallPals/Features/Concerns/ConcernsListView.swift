import SwiftUI

/// View for RAs to see and manage resident concerns
struct ConcernsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var concernService = ConcernService.shared
    @StateObject private var userManager = UserManager.shared

    @State private var selectedConcern: ConcernService.Concern?
    @State private var showingDetail = false
    @State private var filterStatus: FilterOption = .active

    enum FilterOption: String, CaseIterable {
        case active = "Active"
        case all = "All"
        case resolved = "Resolved"
    }

    private var hallId: String {
        userManager.hallId ?? ""
    }

    private var filteredConcerns: [ConcernService.Concern] {
        switch filterStatus {
        case .active:
            return concernService.concerns.filter { $0.status != .resolved }
        case .all:
            return concernService.concerns
        case .resolved:
            return concernService.concerns.filter { $0.status == .resolved }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Filter Picker
                Picker("Filter", selection: $filterStatus) {
                    ForEach(FilterOption.allCases, id: \.self) { option in
                        Text(option.rawValue).tag(option)
                    }
                }
                .pickerStyle(.segmented)
                .padding()

                if concernService.isLoading {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else if filteredConcerns.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "checkmark.circle")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No \(filterStatus == .resolved ? "resolved" : "active") concerns")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredConcerns) { concern in
                            ConcernRowView(concern: concern)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedConcern = concern
                                    showingDetail = true
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Concerns")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let concern = selectedConcern {
                    ConcernDetailView(concern: concern, hallId: hallId)
                }
            }
            .onAppear {
                if !hallId.isEmpty {
                    concernService.startListening(hallId: hallId)
                }
            }
            .onDisappear {
                concernService.stopListening()
            }
        }
    }
}

// MARK: - Concern Row View

struct ConcernRowView: View {
    let concern: ConcernService.Concern

    var body: some View {
        HStack(spacing: 12) {
            // Category Icon
            Circle()
                .fill(statusColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: concern.category.icon)
                        .font(.system(size: 18))
                        .foregroundColor(statusColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(concern.category.displayName)
                        .font(.headline)

                    Spacer()

                    Text(concern.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Text(concern.residentName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                if let room = concern.residentRoom, !room.isEmpty {
                    Text("Room \(room)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(concern.status.displayName)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var statusColor: Color {
        switch concern.status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        }
    }
}

// MARK: - Concern Detail View

struct ConcernDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var concernService = ConcernService.shared

    let concern: ConcernService.Concern
    let hallId: String

    @State private var raNote = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // Resident Info
                Section("From") {
                    HStack {
                        Text("Name")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(concern.residentName)
                    }

                    if let room = concern.residentRoom, !room.isEmpty {
                        HStack {
                            Text("Room")
                                .foregroundColor(.secondary)
                            Spacer()
                            Text(room)
                        }
                    }

                    HStack {
                        Text("Submitted")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(concern.createdAt, style: .relative)
                    }
                }

                // Concern Details
                Section("Concern") {
                    HStack {
                        Text("Category")
                            .foregroundColor(.secondary)
                        Spacer()
                        Label(concern.category.displayName, systemImage: concern.category.icon)
                    }

                    Text(concern.message)
                        .font(.body)
                }

                // Status
                Section("Status") {
                    HStack {
                        Text("Current Status")
                            .foregroundColor(.secondary)
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(statusColor)
                                .frame(width: 10, height: 10)
                            Text(concern.status.displayName)
                                .foregroundColor(statusColor)
                        }
                    }

                    if concern.status != .resolved {
                        TextField("Add a note (optional)", text: $raNote)
                    }

                    if let note = concern.raNote, !note.isEmpty {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("RA Note")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(note)
                        }
                    }
                }

                // Error
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }

                // Actions
                if concern.status != .resolved {
                    Section {
                        if concern.status == .pending {
                            Button {
                                updateStatus(.inProgress)
                            } label: {
                                Label("Mark In Progress", systemImage: "clock")
                            }
                            .disabled(isUpdating)
                        }

                        Button {
                            updateStatus(.resolved)
                        } label: {
                            Label("Mark Resolved", systemImage: "checkmark.circle")
                        }
                        .disabled(isUpdating)
                    }
                }
            }
            .navigationTitle("Concern Details")
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

    private var statusColor: Color {
        switch concern.status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        }
    }

    private func updateStatus(_ newStatus: ConcernService.ConcernStatus) {
        isUpdating = true
        errorMessage = nil

        Task {
            do {
                try await concernService.updateStatus(
                    hallId: hallId,
                    concernId: concern.id,
                    status: newStatus,
                    note: raNote.isEmpty ? nil : raNote
                )
                dismiss()
            } catch {
                errorMessage = error.localizedDescription
            }
            isUpdating = false
        }
    }
}

#Preview {
    ConcernsListView()
}
