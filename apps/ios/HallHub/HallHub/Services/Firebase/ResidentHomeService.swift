import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Firebase service for Resident Home features
/// Provides: On-Duty RA info, Noise Reports, Events preview, Room inspection status
@MainActor
final class ResidentHomeService: ObservableObject {

    // MARK: - Singleton

    static let shared = ResidentHomeService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // On-duty RA
    @Published private(set) var onDutyRA: OnDutyRA?
    @Published private(set) var isLoadingDutyRA = false

    // Events
    @Published private(set) var upcomingEvents: [HallEvent] = []
    @Published private(set) var isLoadingEvents = false

    // Room inspection
    @Published private(set) var myRoomInspection: ResidentRoomInspection?
    @Published private(set) var isLoadingInspection = false

    // Noise report
    @Published private(set) var isSubmittingReport = false
    @Published private(set) var lastReportSubmittedAt: Date?

    // Assigned RA (loaded from hall/resident manifest)
    @Published private(set) var assignedRA: AssignedRA?
    @Published private(set) var isLoadingAssignedRA = false

    private var dutyListener: Any?
    private var eventsListener: Any?
    private var assignedRAListener: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    #if canImport(FirebaseFunctions)
    private lazy var functions = Functions.functions()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Models

    struct OnDutyRA: Equatable {
        let odRAuid: String
        let displayName: String
        let room: String?
        let shiftStart: Date
        let shiftEnd: Date
        let dutyPhone: String?

        var isCurrentlyOnDuty: Bool {
            let now = Date()
            return now >= shiftStart && now <= shiftEnd
        }

        var shiftTimeText: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a"
            return "\(formatter.string(from: shiftStart)) - \(formatter.string(from: shiftEnd))"
        }
    }

    struct HallEvent: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String?
        let location: String?
        let startTime: Date
        let endTime: Date?
        let createdBy: String

        var timeText: String {
            let formatter = DateFormatter()
            let calendar = Calendar.current

            if calendar.isDateInToday(startTime) {
                formatter.dateFormat = "'Today at' h:mm a"
            } else if calendar.isDateInTomorrow(startTime) {
                formatter.dateFormat = "'Tomorrow at' h:mm a"
            } else if calendar.isDate(startTime, equalTo: Date(), toGranularity: .weekOfYear) {
                formatter.dateFormat = "EEEE 'at' h:mm a"
            } else {
                formatter.dateFormat = "MMM d 'at' h:mm a"
            }

            return formatter.string(from: startTime)
        }
    }

    struct ResidentRoomInspection: Equatable {
        let id: String
        let roomNumber: String
        let isComplete: Bool
        let inspectedAt: Date?
        let checklist: [ChecklistItem]
        let notes: String?

        var passedCount: Int {
            checklist.filter { $0.isChecked }.count
        }

        var totalCount: Int {
            checklist.count
        }

        var statusText: String {
            if !isComplete {
                return "Pending"
            }
            if passedCount == totalCount {
                return "Passed"
            }
            return "Needs attention"
        }

        var statusColor: String {
            if !isComplete { return "gray" }
            if passedCount == totalCount { return "green" }
            return "orange"
        }

        struct ChecklistItem: Equatable {
            let name: String
            let isChecked: Bool
        }
    }

    struct NoiseReport {
        let location: String
        let description: String?
        let urgency: Urgency

        enum Urgency: String {
            case low = "low"
            case medium = "medium"
            case high = "high"
        }
    }

    struct AssignedRA: Equatable {
        let odRAuid: String
        let displayName: String
        let room: String?
        let email: String?
    }

    // MARK: - Load On-Duty RA

    /// Start listening for current on-duty RA
    func startListeningForDutyRA(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForDutyRA()

        isLoadingDutyRA = true

        #if DEBUG
        print("🏠 RESIDENT: Starting duty RA listener for hall \(hallId)")
        #endif

        // Query for current shift (where now is between start and end)
        let now = Date()
        let query = db.collection("halls")
            .document(hallId)
            .collection("duty_shifts")
            .whereField("start", isLessThanOrEqualTo: Timestamp(date: now))
            .whereField("end", isGreaterThan: Timestamp(date: now))
            .limit(to: 1)

        dutyListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingDutyRA = false

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENT: Duty RA listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let doc = snapshot?.documents.first,
                  let data = doc.data() as? [String: Any] else {
                #if DEBUG
                print("🏠 RESIDENT: No current duty shift found")
                #endif
                self.onDutyRA = nil
                return
            }

            self.onDutyRA = self.parseDutyShift(data)

            #if DEBUG
            if let ra = self.onDutyRA {
                print("🏠 RESIDENT: On-duty RA: \(ra.displayName)")
            }
            #endif
        }
        #endif
    }

    func stopListeningForDutyRA() {
        #if canImport(FirebaseFirestore)
        if let listener = dutyListener as? ListenerRegistration {
            listener.remove()
            dutyListener = nil
        }
        #endif
    }

    // MARK: - Load Upcoming Events

    /// Start listening for upcoming events
    func startListeningForEvents(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForEvents()

        isLoadingEvents = true

        #if DEBUG
        print("🏠 RESIDENT: Starting events listener for hall \(hallId)")
        #endif

        let now = Date()
        let query = db.collection("halls")
            .document(hallId)
            .collection("events")
            .whereField("startTime", isGreaterThan: Timestamp(date: now))
            .order(by: "startTime", descending: false)
            .limit(to: 5)

        eventsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingEvents = false

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENT: Events listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.upcomingEvents = []
                return
            }

            self.upcomingEvents = documents.compactMap { doc -> HallEvent? in
                self.parseEvent(doc)
            }

            #if DEBUG
            print("🏠 RESIDENT: Loaded \(self.upcomingEvents.count) upcoming events")
            #endif
        }
        #endif
    }

    func stopListeningForEvents() {
        #if canImport(FirebaseFirestore)
        if let listener = eventsListener as? ListenerRegistration {
            listener.remove()
            eventsListener = nil
        }
        #endif
    }

    // MARK: - Load My Room Inspection

    /// Fetch the resident's room inspection status
    func loadMyRoomInspection(hallId: String, roomNumber: String) async {
        #if canImport(FirebaseFirestore)
        isLoadingInspection = true
        defer { isLoadingInspection = false }

        #if DEBUG
        print("🏠 RESIDENT: Loading room inspection for room \(roomNumber)")
        #endif

        do {
            let snapshot = try await db.collection("halls")
                .document(hallId)
                .collection("room_inspections")
                .whereField("roomNumber", isEqualTo: roomNumber)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else {
                #if DEBUG
                print("🏠 RESIDENT: No inspection found for room \(roomNumber)")
                #endif
                myRoomInspection = nil
                return
            }

            myRoomInspection = parseRoomInspection(doc)

            #if DEBUG
            if let inspection = myRoomInspection {
                print("🏠 RESIDENT: Room inspection status: \(inspection.statusText)")
            }
            #endif
        } catch {
            #if DEBUG
            print("🏠 RESIDENT: Error loading room inspection: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
        }
        #endif
    }

    // MARK: - Submit Noise Report

    /// Submit a noise report to the on-duty RA
    func submitNoiseReport(
        hallId: String,
        location: String,
        description: String?,
        urgency: NoiseReport.Urgency = .medium
    ) async throws {
        #if canImport(FirebaseFunctions)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw ResidentHomeError.notAuthenticated
        }

        // Rate limiting: max 1 report per 5 minutes
        if let lastReport = lastReportSubmittedAt {
            let timeSince = Date().timeIntervalSince(lastReport)
            if timeSince < 300 { // 5 minutes
                throw ResidentHomeError.rateLimited
            }
        }

        isSubmittingReport = true
        defer { isSubmittingReport = false }

        #if DEBUG
        print("🏠 RESIDENT: Submitting noise report for \(location)")
        #endif

        var params: [String: Any] = [
            "hallId": hallId,
            "location": location,
            "urgency": urgency.rawValue
        ]

        if let description = description, !description.isEmpty {
            params["description"] = description
        }

        do {
            _ = try await functions.httpsCallable("submitNoiseReport").call(params)
            lastReportSubmittedAt = Date()

            #if DEBUG
            print("🏠 RESIDENT: Noise report submitted successfully")
            #endif
        } catch {
            #if DEBUG
            print("🏠 RESIDENT: Noise report error: \(error.localizedDescription)")
            #endif
            throw ResidentHomeError.functionFailed(error.localizedDescription)
        }
        #else
        throw ResidentHomeError.notConfigured
        #endif
    }

    // MARK: - Stop All Listeners

    func stopAllListeners() {
        stopListeningForDutyRA()
        stopListeningForEvents()
        stopListeningForAssignedRA()
    }

    func stopListeningForAssignedRA() {
        #if canImport(FirebaseFirestore)
        if let listener = assignedRAListener as? ListenerRegistration {
            listener.remove()
            assignedRAListener = nil
        }
        #endif
    }

    // MARK: - Load Assigned RA

    /// Start listening for resident's assigned RA from hall manifest
    /// Note: This requires the hall/resident/RA manifest to be created by staff via web client
    func startListeningForAssignedRA(hallId: String, residentUid: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForAssignedRA()

        isLoadingAssignedRA = true

        #if DEBUG
        print("🏠 RESIDENT: Starting assigned RA listener for resident \(residentUid)")
        #endif

        // Query the residents collection to get the assigned RA
        let docRef = db.collection("halls")
            .document(hallId)
            .collection("residents")
            .document(residentUid)

        assignedRAListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingAssignedRA = false

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENT: Assigned RA listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let data = snapshot?.data(),
                  let assignedRAUid = data["assignedRAUid"] as? String else {
                #if DEBUG
                print("🏠 RESIDENT: No assigned RA found for resident")
                #endif
                self.assignedRA = nil
                return
            }

            // Fetch RA details
            Task {
                await self.loadRADetails(hallId: hallId, raUid: assignedRAUid)
            }
        }
        #endif
    }

    private func loadRADetails(hallId: String, raUid: String) async {
        #if canImport(FirebaseFirestore)
        do {
            let doc = try await db.collection("halls")
                .document(hallId)
                .collection("staff")
                .document(raUid)
                .getDocument()

            guard let data = doc.data(),
                  let displayName = data["displayName"] as? String else {
                #if DEBUG
                print("🏠 RESIDENT: Could not load RA details for \(raUid)")
                #endif
                return
            }

            await MainActor.run {
                self.assignedRA = AssignedRA(
                    odRAuid: raUid,
                    displayName: displayName,
                    room: data["room"] as? String,
                    email: data["email"] as? String
                )
            }

            #if DEBUG
            print("🏠 RESIDENT: Assigned RA loaded: \(displayName)")
            #endif
        } catch {
            #if DEBUG
            print("🏠 RESIDENT: Error loading RA details: \(error.localizedDescription)")
            #endif
        }
        #endif
    }

    // MARK: - Parsing Helpers

    #if canImport(FirebaseFirestore)
    private func parseDutyShift(_ data: [String: Any]) -> OnDutyRA? {
        guard let odRAuid = data["odRAuid"] as? String ?? data["userId"] as? String,
              let displayName = data["displayName"] as? String ?? data["raName"] as? String,
              let start = (data["start"] as? Timestamp)?.dateValue(),
              let end = (data["end"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return OnDutyRA(
            odRAuid: odRAuid,
            displayName: displayName,
            room: data["room"] as? String,
            shiftStart: start,
            shiftEnd: end,
            dutyPhone: data["dutyPhone"] as? String
        )
    }

    private func parseEvent(_ doc: DocumentSnapshot) -> HallEvent? {
        guard let data = doc.data(),
              let title = data["title"] as? String,
              let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
              let createdBy = data["createdBy"] as? String else {
            return nil
        }

        return HallEvent(
            id: doc.documentID,
            title: title,
            description: data["description"] as? String,
            location: data["location"] as? String,
            startTime: startTime,
            endTime: (data["endTime"] as? Timestamp)?.dateValue(),
            createdBy: createdBy
        )
    }

    private func parseRoomInspection(_ doc: DocumentSnapshot) -> ResidentRoomInspection? {
        guard let data = doc.data(),
              let roomNumber = data["roomNumber"] as? String else {
            return nil
        }

        let checklistData = data["checklist"] as? [[String: Any]] ?? []
        let checklist = checklistData.compactMap { item -> ResidentRoomInspection.ChecklistItem? in
            guard let name = item["name"] as? String else { return nil }
            return ResidentRoomInspection.ChecklistItem(
                name: name,
                isChecked: item["isChecked"] as? Bool ?? false
            )
        }

        return ResidentRoomInspection(
            id: doc.documentID,
            roomNumber: roomNumber,
            isComplete: data["isComplete"] as? Bool ?? false,
            inspectedAt: (data["inspectedAt"] as? Timestamp)?.dateValue(),
            checklist: checklist,
            notes: data["notes"] as? String
        )
    }
    #endif
}

// MARK: - Errors

enum ResidentHomeError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case rateLimited
    case functionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Service not configured"
        case .notAuthenticated:
            return "Please sign in first"
        case .rateLimited:
            return "Please wait before submitting another report"
        case .functionFailed(let message):
            return message
        }
    }
}
