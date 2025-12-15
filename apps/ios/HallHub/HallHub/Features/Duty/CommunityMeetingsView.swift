import SwiftUI

// MARK: - Community Meeting Models

struct MeetingTopic: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, description: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
    }
}

struct CommunityMeeting: Identifiable, Codable, Equatable {
    let id: UUID
    var title: String
    var scheduledDate: Date?
    var topics: [MeetingTopic]
    var notes: String
    var isCompleted: Bool

    init(id: UUID = UUID(), title: String, scheduledDate: Date? = nil, topics: [MeetingTopic] = [], notes: String = "", isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.scheduledDate = scheduledDate
        self.topics = topics
        self.notes = notes
        self.isCompleted = isCompleted
    }
}

// MARK: - Community Meetings Store

class CommunityMeetingsStore: ObservableObject {
    static let shared = CommunityMeetingsStore()

    @Published var meetings: [CommunityMeeting] = []

    private let storageKey = "hallpals_community_meetings"

    private init() {
        loadFromStorage()
        if meetings.isEmpty {
            createDefaultMeetings()
        }
    }

    var statusText: String {
        let scheduled = meetings.filter { $0.scheduledDate != nil && !$0.isCompleted }.count
        let completed = meetings.filter { $0.isCompleted }.count
        if scheduled > 0 {
            return "\(scheduled) scheduled"
        } else if completed == meetings.count {
            return "All complete"
        }
        return "\(meetings.count) meetings"
    }

    var nextMeeting: CommunityMeeting? {
        meetings
            .filter { $0.scheduledDate != nil && !$0.isCompleted && $0.scheduledDate! > Date() }
            .sorted { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
            .first
    }

    private func createDefaultMeetings() {
        meetings = [
            CommunityMeeting(
                title: "Welcome Meeting",
                topics: [
                    MeetingTopic(title: "Introductions", description: "Have residents introduce themselves and share something fun"),
                    MeetingTopic(title: "Community Standards", description: "Review hall policies, quiet hours, and guest policies"),
                    MeetingTopic(title: "Emergency Procedures", description: "Fire safety, evacuation routes, and emergency contacts"),
                    MeetingTopic(title: "Resources Available", description: "Campus resources, mental health, academic support"),
                    MeetingTopic(title: "Q&A", description: "Open floor for questions and concerns")
                ]
            ),
            CommunityMeeting(
                title: "Safety & Wellness",
                topics: [
                    MeetingTopic(title: "Personal Safety", description: "Tips for staying safe on and off campus"),
                    MeetingTopic(title: "Mental Health Resources", description: "Counseling services and wellness programs"),
                    MeetingTopic(title: "Substance Abuse Awareness", description: "Alcohol and drug policies, support resources"),
                    MeetingTopic(title: "Healthy Relationships", description: "Consent, boundaries, and Title IX resources"),
                    MeetingTopic(title: "Self-Care Strategies", description: "Stress management and work-life balance")
                ]
            ),
            CommunityMeeting(
                title: "Academic Success",
                topics: [
                    MeetingTopic(title: "Study Tips", description: "Effective study strategies and time management"),
                    MeetingTopic(title: "Academic Resources", description: "Tutoring, writing center, library services"),
                    MeetingTopic(title: "Exam Preparation", description: "How to prepare for midterms and finals"),
                    MeetingTopic(title: "Faculty Office Hours", description: "Building relationships with professors"),
                    MeetingTopic(title: "Academic Integrity", description: "Understanding plagiarism and academic honesty")
                ]
            ),
            CommunityMeeting(
                title: "Diversity & Inclusion",
                topics: [
                    MeetingTopic(title: "Cultural Awareness", description: "Celebrating diversity in our community"),
                    MeetingTopic(title: "Inclusive Language", description: "Respectful communication and pronouns"),
                    MeetingTopic(title: "Bias & Microaggressions", description: "Recognizing and addressing bias"),
                    MeetingTopic(title: "Campus Resources", description: "Multicultural centers and affinity groups"),
                    MeetingTopic(title: "Being an Ally", description: "Supporting marginalized communities")
                ]
            ),
            CommunityMeeting(
                title: "End of Semester",
                topics: [
                    MeetingTopic(title: "Move-Out Procedures", description: "Checkout process and timeline"),
                    MeetingTopic(title: "Room Condition", description: "Cleaning expectations and damage charges"),
                    MeetingTopic(title: "Finals Week Support", description: "Quiet hours and study resources"),
                    MeetingTopic(title: "Semester Reflection", description: "Community highlights and feedback"),
                    MeetingTopic(title: "Next Semester Info", description: "Housing selection and important dates")
                ]
            )
        ]
        saveToStorage()
    }

    func updateMeeting(_ meeting: CommunityMeeting) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index] = meeting
            saveToStorage()
        }
    }

    func setMeetingDate(_ meeting: CommunityMeeting, date: Date?) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index].scheduledDate = date
            saveToStorage()
        }
    }

    func toggleTopicCompleted(meetingId: UUID, topicId: UUID) {
        if let meetingIndex = meetings.firstIndex(where: { $0.id == meetingId }),
           let topicIndex = meetings[meetingIndex].topics.firstIndex(where: { $0.id == topicId }) {
            meetings[meetingIndex].topics[topicIndex].isCompleted.toggle()
            saveToStorage()
        }
    }

    func markMeetingCompleted(_ meeting: CommunityMeeting, completed: Bool) {
        if let index = meetings.firstIndex(where: { $0.id == meeting.id }) {
            meetings[index].isCompleted = completed
            saveToStorage()
        }
    }

    private func saveToStorage() {
        if let data = try? JSONEncoder().encode(meetings) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: storageKey),
           let decoded = try? JSONDecoder().decode([CommunityMeeting].self, from: data) {
            meetings = decoded
        }
    }
}

// MARK: - Community Meetings View

struct CommunityMeetingsView: View {
    @StateObject private var store = CommunityMeetingsStore.shared
    @State private var expandedMeetingId: UUID?

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Header card
                headerCard
                    .padding(.horizontal, 20)

                // Meetings list
                VStack(spacing: 12) {
                    ForEach(store.meetings) { meeting in
                        MeetingCard(
                            meeting: meeting,
                            isExpanded: expandedMeetingId == meeting.id,
                            onToggleExpand: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                                    if expandedMeetingId == meeting.id {
                                        expandedMeetingId = nil
                                    } else {
                                        expandedMeetingId = meeting.id
                                    }
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Community Meetings")
        .navigationBarTitleDisplayMode(.large)
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Semester Meetings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("\(store.meetings.filter { $0.isCompleted }.count) of \(store.meetings.count) completed")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Progress ring
                ZStack {
                    Circle()
                        .stroke(Color(UIColor.systemGray5), lineWidth: 4)
                        .frame(width: 44, height: 44)

                    Circle()
                        .trim(from: 0, to: CGFloat(store.meetings.filter { $0.isCompleted }.count) / CGFloat(max(store.meetings.count, 1)))
                        .stroke(Color.indigo, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                }
            }

            if let nextMeeting = store.nextMeeting {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.indigo)

                    Text("Next: \(nextMeeting.title)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    if let date = nextMeeting.scheduledDate {
                        Text(date, style: .date)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(10)
                .background(Color.indigo.opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Meeting Card

struct MeetingCard: View {
    let meeting: CommunityMeeting
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @StateObject private var store = CommunityMeetingsStore.shared
    @State private var showingDatePicker = false
    @State private var selectedDate = Date()

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onToggleExpand) {
                HStack(spacing: 14) {
                    // Status indicator
                    ZStack {
                        Circle()
                            .fill(meeting.isCompleted ? Color.green : (meeting.scheduledDate != nil ? Color.indigo : Color(UIColor.systemGray4)))
                            .frame(width: 32, height: 32)

                        Image(systemName: meeting.isCompleted ? "checkmark" : "person.3.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(meeting.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        if let date = meeting.scheduledDate {
                            Text(date, style: .date)
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Not scheduled")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()

                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding(16)
            }

            // Expanded content
            if isExpanded {
                VStack(spacing: 0) {
                    Divider()

                    // Schedule button
                    Button {
                        selectedDate = meeting.scheduledDate ?? Date()
                        showingDatePicker = true
                    } label: {
                        HStack {
                            Image(systemName: "calendar.badge.plus")
                                .font(.system(size: 16))
                                .foregroundColor(.indigo)

                            Text(meeting.scheduledDate != nil ? "Change Date" : "Schedule Meeting")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.indigo)

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.indigo.opacity(0.08))
                    }

                    // Topics header
                    HStack {
                        Text("TOPICS TO COVER")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundColor(.secondary)
                            .tracking(0.5)
                        Spacer()
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 8)

                    // Topics list
                    ForEach(meeting.topics) { topic in
                        TopicRow(
                            topic: topic,
                            onToggle: {
                                store.toggleTopicCompleted(meetingId: meeting.id, topicId: topic.id)
                            }
                        )
                    }

                    // Mark complete button
                    Button {
                        store.markMeetingCompleted(meeting, completed: !meeting.isCompleted)
                    } label: {
                        HStack {
                            Image(systemName: meeting.isCompleted ? "arrow.uturn.backward" : "checkmark.circle.fill")
                                .font(.system(size: 16))
                            Text(meeting.isCompleted ? "Mark Incomplete" : "Mark as Completed")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(meeting.isCompleted ? Color.gray : Color.green)
                        .cornerRadius(10)
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        .sheet(isPresented: $showingDatePicker) {
            DatePickerSheet(
                selectedDate: $selectedDate,
                meeting: meeting,
                onSave: { date in
                    store.setMeetingDate(meeting, date: date)
                }
            )
        }
    }
}

// MARK: - Topic Row

struct TopicRow: View {
    let topic: MeetingTopic
    let onToggle: () -> Void
    @State private var isShowingDescription = false

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    isShowingDescription.toggle()
                }
            } label: {
                HStack(spacing: 12) {
                    Button(action: onToggle) {
                        Image(systemName: topic.isCompleted ? "checkmark.circle.fill" : "circle")
                            .font(.system(size: 20))
                            .foregroundColor(topic.isCompleted ? .green : Color(UIColor.systemGray3))
                    }

                    Text(topic.title)
                        .font(.system(size: 15))
                        .foregroundColor(topic.isCompleted ? .secondary : .primary)
                        .strikethrough(topic.isCompleted)

                    Spacer()

                    if !topic.description.isEmpty {
                        Image(systemName: "info.circle")
                            .font(.system(size: 14))
                            .foregroundColor(Color(UIColor.systemGray3))
                            .rotationEffect(.degrees(isShowingDescription ? 180 : 0))
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
            }

            if isShowingDescription && !topic.description.isEmpty {
                Text(topic.description)
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 48)
                    .padding(.bottom, 10)
            }

            Divider()
                .padding(.leading, 48)
        }
    }
}

// MARK: - Date Picker Sheet

struct DatePickerSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Binding var selectedDate: Date
    let meeting: CommunityMeeting
    let onSave: (Date) -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text(meeting.title)
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)

                    Text("Select a date for this meeting")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .padding(.top, 20)

                DatePicker(
                    "Meeting Date",
                    selection: $selectedDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .datePickerStyle(.graphical)
                .padding(.horizontal)

                Spacer()

                VStack(spacing: 12) {
                    Button {
                        onSave(selectedDate)
                        dismiss()
                    } label: {
                        Text("Save Date")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .frame(height: 52)
                            .background(Color.indigo)
                            .cornerRadius(14)
                    }

                    if meeting.scheduledDate != nil {
                        Button {
                            onSave(selectedDate)
                            CommunityMeetingsStore.shared.setMeetingDate(meeting, date: nil)
                            dismiss()
                        } label: {
                            Text("Remove Date")
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.red)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
    }
}

#Preview {
    NavigationStack {
        CommunityMeetingsView()
    }
}
