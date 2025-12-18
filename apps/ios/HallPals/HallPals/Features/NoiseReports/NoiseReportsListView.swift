import SwiftUI

/// View for RAs to see and manage noise reports from residents
struct NoiseReportsListView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var noiseService = NoiseReportService.shared
    @StateObject private var userManager = UserManager.shared

    @State private var selectedReport: NoiseReportService.NoiseReport?
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

    private var filteredReports: [NoiseReportService.NoiseReport] {
        switch filterStatus {
        case .active:
            return noiseService.reports.filter { $0.status != .resolved }
        case .all:
            return noiseService.reports
        case .resolved:
            return noiseService.reports.filter { $0.status == .resolved }
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

                if noiseService.isLoading {
                    Spacer()
                    ProgressView("Loading...")
                    Spacer()
                } else if filteredReports.isEmpty {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "speaker.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.green)
                        Text("No \(filterStatus == .resolved ? "resolved" : "active") noise reports")
                            .font(.headline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                } else {
                    List {
                        ForEach(filteredReports) { report in
                            NoiseReportRowView(report: report)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    selectedReport = report
                                    showingDetail = true
                                }
                        }
                    }
                    .listStyle(.plain)
                }
            }
            .navigationTitle("Noise Reports")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .sheet(isPresented: $showingDetail) {
                if let report = selectedReport {
                    NoiseReportDetailView(report: report, hallId: hallId)
                }
            }
            .onAppear {
                if !hallId.isEmpty {
                    noiseService.startListening(hallId: hallId)
                }
            }
            .onDisappear {
                noiseService.stopListening()
            }
        }
    }
}

// MARK: - Noise Report Row View

struct NoiseReportRowView: View {
    let report: NoiseReportService.NoiseReport

    var body: some View {
        HStack(spacing: 12) {
            // Urgency Icon
            Circle()
                .fill(urgencyColor.opacity(0.15))
                .frame(width: 44, height: 44)
                .overlay(
                    Image(systemName: "speaker.wave.3.fill")
                        .font(.system(size: 18))
                        .foregroundColor(urgencyColor)
                )

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(report.location)
                        .font(.headline)

                    Spacer()

                    Text(report.timeAgo)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // Urgency badge
                HStack(spacing: 4) {
                    Text(report.urgency.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(urgencyColor)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(urgencyColor.opacity(0.15))
                        .cornerRadius(4)
                }

                if let description = report.description, !description.isEmpty {
                    Text(description)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                }

                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 8, height: 8)
                    Text(report.status.displayName)
                        .font(.caption)
                        .foregroundColor(statusColor)
                }
                .padding(.top, 2)
            }
        }
        .padding(.vertical, 4)
    }

    private var urgencyColor: Color {
        switch report.urgency {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var statusColor: Color {
        switch report.status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        }
    }
}

// MARK: - Noise Report Detail View

struct NoiseReportDetailView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var noiseService = NoiseReportService.shared

    let report: NoiseReportService.NoiseReport
    let hallId: String

    @State private var raNote = ""
    @State private var isUpdating = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // Location Info
                Section("Location") {
                    Text(report.location)
                        .font(.headline)

                    HStack {
                        Text("Urgency")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(report.urgency.displayName)
                            .foregroundColor(urgencyColor)
                            .fontWeight(.medium)
                    }

                    HStack {
                        Text("Reported")
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(report.createdAt, style: .relative)
                    }
                }

                // Description
                if let description = report.description, !description.isEmpty {
                    Section("Description") {
                        Text(description)
                            .font(.body)
                    }
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
                            Text(report.status.displayName)
                                .foregroundColor(statusColor)
                        }
                    }

                    if report.status != .resolved {
                        TextField("Add a note (optional)", text: $raNote)
                    }

                    if let note = report.raNote, !note.isEmpty {
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
                if report.status != .resolved {
                    Section {
                        if report.status == .pending {
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
            .navigationTitle("Report Details")
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

    private var urgencyColor: Color {
        switch report.urgency {
        case .low: return .green
        case .medium: return .orange
        case .high: return .red
        }
    }

    private var statusColor: Color {
        switch report.status {
        case .pending: return .orange
        case .inProgress: return .blue
        case .resolved: return .green
        }
    }

    private func updateStatus(_ newStatus: NoiseReportService.ReportStatus) {
        isUpdating = true
        errorMessage = nil

        Task {
            do {
                try await noiseService.updateStatus(
                    hallId: hallId,
                    reportId: report.id,
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
    NoiseReportsListView()
}
