import SwiftUI

// MARK: - Community Meetings View

struct CommunityMeetingsView: View {
    @StateObject private var service = CommunityMeetingsService.shared
    @State private var expandedMeetingId: String?

    private var hallId: String? {
        UserManager.shared.hallId
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Loading state
                if service.isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, minHeight: 200)
                }
                // Error state
                else if let error = service.error {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 40))
                            .foregroundColor(.orange)
                        Text("Error loading meetings")
                            .font(.headline)
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                }
                // Empty state
                else if service.meetings.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3")
                            .font(.system(size: 40))
                            .foregroundColor(Color(UIColor.systemGray3))
                        Text("No Meetings Scheduled")
                            .font(.headline)
                        Text("Community meetings assigned by your admin will appear here.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity, minHeight: 200)
                    .padding()
                }
                // Content
                else {
                    // Header card
                    headerCard
                        .padding(.horizontal, 20)

                    // Meetings list
                    VStack(spacing: 12) {
                        ForEach(service.upcomingMeetings + service.completedMeetings) { meeting in
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
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Community Meetings")
        .navigationBarTitleDisplayMode(.large)
        .onAppear {
            if let hallId = hallId {
                service.startListening(hallId: hallId)
            }
        }
        .onDisappear {
            service.stopListening()
        }
    }

    private var headerCard: some View {
        VStack(spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Semester Meetings")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)

                    Text("\(service.completedMeetings.count) of \(service.meetings.count) completed")
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
                        .trim(from: 0, to: CGFloat(service.completedMeetings.count) / CGFloat(max(service.meetings.count, 1)))
                        .stroke(Color.indigo, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .frame(width: 44, height: 44)
                        .rotationEffect(.degrees(-90))
                }
            }

            if let nextMeeting = service.nextMeeting {
                HStack {
                    Image(systemName: "calendar")
                        .font(.system(size: 14))
                        .foregroundColor(.indigo)

                    Text("Next: \(nextMeeting.title)")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)

                    Spacer()

                    if let dateText = nextMeeting.scheduledDateText {
                        Text(dateText)
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
    let meeting: CommunityMeetingsService.CommunityMeeting
    let isExpanded: Bool
    let onToggleExpand: () -> Void

    @StateObject private var service = CommunityMeetingsService.shared

    private var hallId: String? {
        UserManager.shared.hallId
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header row
            Button(action: onToggleExpand) {
                HStack(spacing: 14) {
                    // Status indicator
                    ZStack {
                        Circle()
                            .fill(meeting.isComplete ? Color.green : (meeting.scheduledDate != nil ? Color.indigo : Color(UIColor.systemGray4)))
                            .frame(width: 32, height: 32)

                        Image(systemName: meeting.isComplete ? "checkmark" : "person.3.fill")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white)
                    }

                    VStack(alignment: .leading, spacing: 2) {
                        Text(meeting.title)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.primary)

                        if let dateText = meeting.scheduledDateText {
                            HStack(spacing: 4) {
                                Text(dateText)
                                    .font(.system(size: 13))
                                    .foregroundColor(meeting.isOverdue ? .red : .secondary)

                                if meeting.isOverdue {
                                    Text("Overdue")
                                        .font(.system(size: 10, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(Color.red)
                                        .cornerRadius(4)
                                }
                            }
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

                    // Progress indicator
                    HStack {
                        Text("\(meeting.completedTopicsCount) of \(meeting.totalTopicsCount) topics covered")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        Spacer()

                        // Mini progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(Color(UIColor.systemGray5))
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(meeting.isComplete ? Color.green : Color.indigo)
                                    .frame(width: geo.size.width * meeting.progressPercentage, height: 4)
                            }
                        }
                        .frame(width: 60, height: 4)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)
                    .background(Color(UIColor.tertiarySystemBackground))

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
                                guard let hallId = hallId else { return }
                                Task {
                                    try? await service.toggleTopicCompletion(
                                        hallId: hallId,
                                        meetingId: meeting.id,
                                        topicId: topic.id
                                    )
                                }
                            }
                        )
                    }

                    // Mark complete button
                    Button {
                        guard let hallId = hallId else { return }
                        Task {
                            if meeting.isComplete {
                                try? await service.reopenMeeting(hallId: hallId, meetingId: meeting.id)
                            } else {
                                try? await service.markMeetingComplete(hallId: hallId, meetingId: meeting.id)
                            }
                        }
                    } label: {
                        HStack {
                            Image(systemName: meeting.isComplete ? "arrow.uturn.backward" : "checkmark.circle.fill")
                                .font(.system(size: 16))
                            Text(meeting.isComplete ? "Mark Incomplete" : "Mark as Completed")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 44)
                        .background(meeting.isComplete ? Color.gray : Color.green)
                        .cornerRadius(10)
                    }
                    .padding(16)
                }
            }
        }
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

// MARK: - Topic Row

struct TopicRow: View {
    let topic: CommunityMeetingsService.MeetingTopic
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

                    Text(topic.name)
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

#Preview {
    NavigationStack {
        CommunityMeetingsView()
    }
}
