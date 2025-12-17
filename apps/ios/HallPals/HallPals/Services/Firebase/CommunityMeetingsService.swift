import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Firebase service for Community Meetings functionality
/// Fetches meetings from /halls/{hallId}/community_meetings/{meetingId}
/// Schema matches web admin: title, description, scheduledDate, status, topics[], notes
@MainActor
final class CommunityMeetingsService: ObservableObject {

    // MARK: - Singleton

    static let shared = CommunityMeetingsService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var error: String?
    @Published private(set) var meetings: [CommunityMeeting] = []

    private var listenerRegistration: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Models (matches web schema)

    struct CommunityMeeting: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let scheduledDate: Date?
        let status: MeetingStatus
        var topics: [MeetingTopic]
        var notes: String
        let createdAt: Date

        enum MeetingStatus: String {
            case upcoming = "upcoming"
            case completed = "completed"
        }

        var completedTopicsCount: Int {
            topics.filter { $0.isCompleted }.count
        }

        var totalTopicsCount: Int {
            topics.count
        }

        var progressPercentage: Double {
            guard totalTopicsCount > 0 else { return 0 }
            return Double(completedTopicsCount) / Double(totalTopicsCount)
        }

        var isComplete: Bool {
            status == .completed
        }

        var isOverdue: Bool {
            guard let scheduledDate = scheduledDate, status == .upcoming else { return false }
            return Date() > scheduledDate
        }

        var scheduledDateText: String? {
            guard let scheduledDate = scheduledDate else { return nil }

            let formatter = DateFormatter()
            let calendar = Calendar.current

            if calendar.isDateInToday(scheduledDate) {
                formatter.dateFormat = "'Today at' h:mm a"
            } else if calendar.isDateInTomorrow(scheduledDate) {
                formatter.dateFormat = "'Tomorrow at' h:mm a"
            } else if calendar.isDate(scheduledDate, equalTo: Date(), toGranularity: .weekOfYear) {
                formatter.dateFormat = "EEEE 'at' h:mm a"
            } else {
                formatter.dateFormat = "MMM d 'at' h:mm a"
            }

            return formatter.string(from: scheduledDate)
        }
    }

    struct MeetingTopic: Identifiable, Equatable {
        let id: String
        var name: String
        var description: String
        var isCompleted: Bool
    }

    // MARK: - Listen to Meetings

    func startListening(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListening()
        isLoading = true
        error = nil

        #if DEBUG
        print("📅 MEETINGS: Starting listener for hall \(hallId)")
        #endif

        let query = db.collection("halls")
            .document(hallId)
            .collection("community_meetings")
            .order(by: "createdAt", descending: true)

        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, err in
            guard let self = self else { return }
            self.isLoading = false

            if let err = err {
                #if DEBUG
                print("📅 MEETINGS: Listener error: \(err.localizedDescription)")
                #endif
                self.error = err.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.meetings = []
                return
            }

            #if DEBUG
            print("📅 MEETINGS: Received \(documents.count) meetings")
            #endif

            self.meetings = documents.compactMap { doc -> CommunityMeeting? in
                self.parseMeeting(doc)
            }

            #if DEBUG
            print("📅 MEETINGS: Parsed \(self.meetings.count) meetings successfully")
            #endif
        }
        #endif
    }

    func stopListening() {
        #if canImport(FirebaseFirestore)
        if let registration = listenerRegistration as? ListenerRegistration {
            registration.remove()
            listenerRegistration = nil
        }
        #endif
    }

    // MARK: - Update Topic Completion

    func toggleTopicCompletion(
        hallId: String,
        meetingId: String,
        topicId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let meetingRef = db.collection("halls")
            .document(hallId)
            .collection("community_meetings")
            .document(meetingId)

        let snapshot = try await meetingRef.getDocument()
        guard let data = snapshot.data(),
              var topicsArray = data["topics"] as? [[String: Any]] else {
            throw MeetingsError.notFound
        }

        // Find and toggle the topic
        if let topicIndex = topicsArray.firstIndex(where: { ($0["id"] as? String) == topicId }) {
            let currentValue = topicsArray[topicIndex]["isCompleted"] as? Bool ?? false
            topicsArray[topicIndex]["isCompleted"] = !currentValue
        }

        try await meetingRef.updateData([
            "topics": topicsArray,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("📅 MEETINGS: Toggled topic \(topicId) in meeting \(meetingId)")
        #endif
        #endif
    }

    // MARK: - Update Meeting Notes

    func updateMeetingNotes(
        hallId: String,
        meetingId: String,
        notes: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        try await db.collection("halls")
            .document(hallId)
            .collection("community_meetings")
            .document(meetingId)
            .updateData([
                "notes": notes,
                "updatedAt": FieldValue.serverTimestamp()
            ])

        #if DEBUG
        print("📅 MEETINGS: Updated notes for meeting \(meetingId)")
        #endif
        #endif
    }

    // MARK: - Mark Meeting Complete

    func markMeetingComplete(
        hallId: String,
        meetingId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        try await db.collection("halls")
            .document(hallId)
            .collection("community_meetings")
            .document(meetingId)
            .updateData([
                "status": "completed",
                "updatedAt": FieldValue.serverTimestamp()
            ])

        #if DEBUG
        print("📅 MEETINGS: Marked meeting \(meetingId) as complete")
        #endif
        #endif
    }

    // MARK: - Reopen Meeting

    func reopenMeeting(
        hallId: String,
        meetingId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        try await db.collection("halls")
            .document(hallId)
            .collection("community_meetings")
            .document(meetingId)
            .updateData([
                "status": "upcoming",
                "updatedAt": FieldValue.serverTimestamp()
            ])

        #if DEBUG
        print("📅 MEETINGS: Reopened meeting \(meetingId)")
        #endif
        #endif
    }

    // MARK: - Computed Properties

    var upcomingMeetings: [CommunityMeeting] {
        meetings.filter { $0.status == .upcoming }
            .sorted { ($0.scheduledDate ?? .distantFuture) < ($1.scheduledDate ?? .distantFuture) }
    }

    var completedMeetings: [CommunityMeeting] {
        meetings.filter { $0.status == .completed }
    }

    var nextMeeting: CommunityMeeting? {
        upcomingMeetings
            .filter { $0.scheduledDate != nil && $0.scheduledDate! > Date() }
            .first
    }

    var hasUpcomingMeetings: Bool {
        !upcomingMeetings.isEmpty
    }

    var statusText: String {
        let upcoming = upcomingMeetings.count
        let completed = completedMeetings.count

        if upcoming == 0 && completed == 0 {
            return "No meetings scheduled"
        } else if upcoming > 0 {
            return "\(upcoming) scheduled"
        } else {
            return "All complete"
        }
    }

    // MARK: - Helpers

    #if canImport(FirebaseFirestore)
    private func parseMeeting(_ doc: DocumentSnapshot) -> CommunityMeeting? {
        guard let data = doc.data() else {
            #if DEBUG
            print("📅 MEETINGS: No data for doc \(doc.documentID)")
            #endif
            return nil
        }

        guard let title = data["title"] as? String else {
            #if DEBUG
            print("📅 MEETINGS: Missing title for doc \(doc.documentID)")
            #endif
            return nil
        }

        // Parse scheduledDate - ISO string from web
        var scheduledDate: Date? = nil
        if let dateStr = data["scheduledDate"] as? String, !dateStr.isEmpty {
            let formatter = ISO8601DateFormatter()
            formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
            scheduledDate = formatter.date(from: dateStr)

            // Try without fractional seconds
            if scheduledDate == nil {
                formatter.formatOptions = [.withInternetDateTime]
                scheduledDate = formatter.date(from: dateStr)
            }

            // Try simple datetime format
            if scheduledDate == nil {
                let simpleFormatter = DateFormatter()
                simpleFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm"
                scheduledDate = simpleFormatter.date(from: dateStr)
            }
        }

        // Parse status
        let statusStr = data["status"] as? String ?? "upcoming"
        let status = CommunityMeeting.MeetingStatus(rawValue: statusStr) ?? .upcoming

        // Parse createdAt
        var createdAt = Date()
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        }

        // Parse topics
        let topicsData = data["topics"] as? [[String: Any]] ?? []
        let topics = topicsData.compactMap { parseTopic($0) }

        return CommunityMeeting(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String ?? "",
            scheduledDate: scheduledDate,
            status: status,
            topics: topics,
            notes: data["notes"] as? String ?? "",
            createdAt: createdAt
        )
    }

    private func parseTopic(_ data: [String: Any]) -> MeetingTopic? {
        guard let id = data["id"] as? String,
              let name = data["name"] as? String else { return nil }

        return MeetingTopic(
            id: id,
            name: name,
            description: data["description"] as? String ?? "",
            isCompleted: data["isCompleted"] as? Bool ?? false
        )
    }
    #endif
}

// MARK: - Errors

enum MeetingsError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case notFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Meetings service is not configured"
        case .notAuthenticated:
            return "User is not authenticated"
        case .notFound:
            return "Meeting not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
