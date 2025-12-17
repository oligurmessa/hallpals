import SwiftUI

struct OneOnOneMeetingsView: View {
    @StateObject private var residentService = ResidentService.shared
    @State private var completedMeetings: Set<String> = []
    @State private var searchText = ""

    // Load completed meetings from UserDefaults
    private let completedMeetingsKey = "hallpals_completed_1on1_meetings"

    var filteredResidents: [HallResident] {
        if searchText.isEmpty {
            return residentService.sortedResidents
        }
        return residentService.search(searchText)
    }

    var completedCount: Int {
        completedMeetings.count
    }

    var totalCount: Int {
        residentService.residentCount
    }

    var progressPercentage: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Content based on resident data availability
                if residentService.isLoading {
                    loadingView
                } else if residentService.myResidents.isEmpty {
                    emptyStateView
                        .padding(.horizontal, 20)
                } else {
                    // Progress card
                    progressCard
                        .padding(.horizontal, 20)

                    // Search bar
                    searchBar
                        .padding(.horizontal, 20)

                    // Residents checklist
                    residentsChecklist
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("1:1 Meetings")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        residentService.fetchMyResidents()
                    } label: {
                        Label("Refresh Residents", systemImage: "arrow.clockwise")
                    }

                    if !completedMeetings.isEmpty {
                        Button(role: .destructive) {
                            resetAllMeetings()
                        } label: {
                            Label("Reset All", systemImage: "arrow.counterclockwise")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                }
            }
        }
        .onAppear {
            loadCompletedMeetings()
            if residentService.myResidents.isEmpty {
                residentService.fetchMyResidents()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("1:1 Meetings")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text("Track your resident check-ins")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading residents...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 44))
                .foregroundColor(.orange)

            Text("No Residents Found")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            if let errorMessage = residentService.errorMessage {
                Text(errorMessage)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            } else {
                Text("Your resident list hasn't been loaded yet. Make sure you have residents assigned to your section.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                residentService.fetchMyResidents()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.orange)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Progress")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text("\(completedCount) of \(totalCount)")
                        .font(.system(size: 28, weight: .bold))
                        .foregroundColor(.primary)
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.orange.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: progressPercentage)
                        .stroke(Color.orange, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.3), value: progressPercentage)

                    Text("\(Int(progressPercentage * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.orange)
                }
            }

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange.opacity(0.2))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.orange)
                        .frame(width: geometry.size.width * progressPercentage, height: 8)
                        .animation(.easeInOut(duration: 0.3), value: progressPercentage)
                }
            }
            .frame(height: 8)

            if completedCount == totalCount && totalCount > 0 {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("All meetings completed!")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.green)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search residents...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Residents Checklist

    private var residentsChecklist: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !searchText.isEmpty {
                Text("\(filteredResidents.count) results")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 20)
            }

            if filteredResidents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("No residents found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Group by completion status
                let incomplete = filteredResidents.filter { !isCompleted($0) }
                let completed = filteredResidents.filter { isCompleted($0) }

                // Incomplete section
                if !incomplete.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Pending (\(incomplete.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ForEach(Array(incomplete.enumerated()), id: \.element.id) { index, resident in
                                MeetingResidentRow(
                                    resident: resident,
                                    isCompleted: false,
                                    isLast: index == incomplete.count - 1
                                ) {
                                    toggleMeeting(for: resident)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }

                // Completed section
                if !completed.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Completed (\(completed.count))")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)
                            .padding(.top, incomplete.isEmpty ? 0 : 8)

                        VStack(spacing: 0) {
                            ForEach(Array(completed.enumerated()), id: \.element.id) { index, resident in
                                MeetingResidentRow(
                                    resident: resident,
                                    isCompleted: true,
                                    isLast: index == completed.count - 1
                                ) {
                                    toggleMeeting(for: resident)
                                }
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Helper Functions

    private func isCompleted(_ resident: HallResident) -> Bool {
        completedMeetings.contains(resident.id)
    }

    private func toggleMeeting(for resident: HallResident) {
        withAnimation(.easeInOut(duration: 0.2)) {
            if completedMeetings.contains(resident.id) {
                completedMeetings.remove(resident.id)
            } else {
                completedMeetings.insert(resident.id)
            }
        }

        saveCompletedMeetings()
    }

    private func loadCompletedMeetings() {
        if let data = UserDefaults.standard.data(forKey: completedMeetingsKey),
           let decoded = try? JSONDecoder().decode(Set<String>.self, from: data) {
            completedMeetings = decoded
        }
    }

    private func saveCompletedMeetings() {
        if let encoded = try? JSONEncoder().encode(completedMeetings) {
            UserDefaults.standard.set(encoded, forKey: completedMeetingsKey)
        }
    }

    private func resetAllMeetings() {
        withAnimation {
            completedMeetings.removeAll()
        }
        saveCompletedMeetings()
    }
}

// MARK: - Meeting Resident Row

struct MeetingResidentRow: View {
    let resident: HallResident
    let isCompleted: Bool
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 12) {
                    // Checkbox
                    ZStack {
                        Circle()
                            .stroke(isCompleted ? Color.green : Color.gray.opacity(0.4), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // Avatar
                    Circle()
                        .fill(avatarColor)
                        .frame(width: 36, height: 36)
                        .overlay(
                            Text(resident.initials)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundColor(.white)
                        )
                        .opacity(isCompleted ? 0.6 : 1.0)

                    // Info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(resident.fullName)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(isCompleted ? .secondary : .primary)
                            .strikethrough(isCompleted, color: .secondary)

                        Text("Room \(resident.roomNumber)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if !isLast {
                Divider()
                    .padding(.leading, 68)
            }
        }
    }

    private var avatarColor: Color {
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        let hash = abs(resident.fullName.hashValue)
        return colors[hash % colors.count]
    }
}

#Preview {
    NavigationStack {
        OneOnOneMeetingsView()
    }
}
