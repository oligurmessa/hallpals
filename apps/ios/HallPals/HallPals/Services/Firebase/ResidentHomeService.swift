import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Firebase service for Resident Home features
/// OPTIMIZED: Now proxies data from UserManager's centralized batch loading
/// UserManager loads resident data (on-duty RA, assigned RA, events) in parallel on login
/// This service provides backward compatibility for views still referencing it
@MainActor
final class ResidentHomeService: ObservableObject {

    // MARK: - Singleton

    static let shared = ResidentHomeService()

    // MARK: - Proxied State (from UserManager)
    // These computed properties proxy data from UserManager for backward compatibility

    /// On-duty RA - proxied from UserManager
    var onDutyRA: OnDutyRA? {
        // Convert from UserManager's model if available
        if let ra = UserManager.shared.onDutyRA {
            return OnDutyRA(
                odRAuid: ra.odRAuid,
                displayName: ra.displayName,
                room: ra.room,
                shiftStart: ra.shiftStart,
                shiftEnd: ra.shiftEnd,
                dutyPhone: ra.dutyPhone
            )
        }
        return _legacyOnDutyRA
    }

    var isLoadingDutyRA: Bool {
        if _legacyIsLoadingDutyRA { return true }
        return UserManager.shared.isLoadingOnDutyRA
    }

    /// Events - proxied from UserManager
    var upcomingEvents: [HallEvent] {
        // Convert from UserManager's models if available
        if UserManager.shared.eventsLoaded && !UserManager.shared.upcomingEvents.isEmpty {
            return UserManager.shared.upcomingEvents.map { event in
                HallEvent(
                    id: event.id,
                    title: event.title,
                    description: event.description,
                    location: event.location,
                    startTime: event.startTime,
                    endTime: event.endTime,
                    createdBy: event.createdBy
                )
            }
        }
        return _legacyUpcomingEvents
    }

    var isLoadingEvents: Bool {
        if _legacyIsLoadingEvents { return true }
        return UserManager.shared.isLoadingEvents
    }

    /// Assigned RA - proxied from UserManager
    var assignedRA: AssignedRA? {
        if let ra = UserManager.shared.assignedRA {
            return AssignedRA(
                odRAuid: ra.odRAuid,
                displayName: ra.displayName,
                room: ra.room,
                email: ra.email,
                floor: ra.floor,
                wing: ra.wing
            )
        }
        return _legacyAssignedRA
    }

    var isLoadingAssignedRA: Bool {
        if _legacyIsLoadingAssignedRA { return true }
        return UserManager.shared.isLoadingAssignedRA
    }

    // MARK: - Published State (Non-proxied)

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // Room inspection (not proxied - on-demand load)
    @Published private(set) var myRoomInspection: ResidentRoomInspection?
    @Published private(set) var isLoadingInspection = false

    // Noise report (not proxied - action-based)
    @Published private(set) var isSubmittingReport = false
    @Published private(set) var lastReportSubmittedAt: Date?

    // Hall info - proxied from UserManager's currentHall
    var hallInfo: HallInfo? {
        if let hall = UserManager.shared.currentHall {
            return HallInfo(
                id: hall.hallId,
                name: hall.name,
                shortName: hall.shortName,
                address: hall.address
            )
        }
        return _legacyHallInfo
    }

    var isLoadingHallInfo: Bool {
        _legacyIsLoadingHallInfo
    }

    // MARK: - Legacy State (for direct fetch methods)

    @Published private var _legacyOnDutyRA: OnDutyRA?
    @Published private var _legacyIsLoadingDutyRA = false

    @Published private var _legacyUpcomingEvents: [HallEvent] = []
    @Published private var _legacyIsLoadingEvents = false

    @Published private var _legacyAssignedRA: AssignedRA?
    @Published private var _legacyIsLoadingAssignedRA = false

    @Published private var _legacyHallInfo: HallInfo?
    @Published private var _legacyIsLoadingHallInfo = false

    private var dutyListener: Any?
    private var eventsListener: Any?
    private var assignedRAListener: Any?
    private var hallInfoListener: Any?

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
        let floor: Int?
        let wing: String?
    }

    struct HallInfo: Equatable {
        let id: String
        let name: String
        let shortName: String?
        let address: String?
    }

    // MARK: - Load On-Duty RA

    /// Start listening for current on-duty RA
    /// OPTIMIZED: Now delegates to UserManager - data is loaded in parallel on login
    /// This method triggers a refresh if needed
    func startListeningForDutyRA(hallId: String) {
        #if DEBUG
        print("🏠 RESIDENT: startListeningForDutyRA() - delegating to UserManager")
        #endif

        // Data is already loaded by UserManager on resident login
        // Only refresh if explicitly empty and not loading
        if UserManager.shared.onDutyRA == nil && !UserManager.shared.isLoadingOnDutyRA && UserManager.shared.onDutyRALoaded {
            UserManager.shared.refreshResidentData()
        }
    }

    /// Legacy: Direct listener for duty RA (bypasses UserManager)
    func startListeningForDutyRADirectly(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForDutyRA()

        _legacyIsLoadingDutyRA = true

        #if DEBUG
        print("🏠 RESIDENT: Starting direct duty RA listener for hall \(hallId)")
        #endif

        // V1 FIX: Query shifts where start <= now, ordered by start desc, limit 10
        // Then filter in-memory for end > now
        let now = Date()
        let query = db.collection("halls")
            .document(hallId)
            .collection("duty_shifts")
            .whereField("start", isLessThanOrEqualTo: Timestamp(date: now))
            .order(by: "start", descending: true)
            .limit(to: 10)

        dutyListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self._legacyIsLoadingDutyRA = false

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENT: Duty RA listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                #if DEBUG
                print("🏠 RESIDENT: No duty shifts found")
                #endif
                self._legacyOnDutyRA = nil
                return
            }

            // V1 FIX: In-memory filter for end > now
            let nowDate = Date()
            for doc in documents {
                let data = doc.data()
                if let endTimestamp = data["end"] as? Timestamp {
                    if endTimestamp.dateValue() > nowDate {
                        // Found an active shift
                        self._legacyOnDutyRA = self.parseDutyShift(data)
                        #if DEBUG
                        if let ra = self._legacyOnDutyRA {
                            print("🏠 RESIDENT: On-duty RA: \(ra.displayName)")
                        }
                        #endif
                        return
                    }
                }
            }

            // No active shift found
            #if DEBUG
            print("🏠 RESIDENT: No current duty shift found (all shifts ended)")
            #endif
            self._legacyOnDutyRA = nil
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
    /// OPTIMIZED: Now delegates to UserManager - data is loaded in parallel on login
    func startListeningForEvents(hallId: String) {
        #if DEBUG
        print("🏠 RESIDENT: startListeningForEvents() - delegating to UserManager")
        #endif

        // Data is already loaded by UserManager on resident login
        // Only refresh if explicitly empty and not loading
        if UserManager.shared.upcomingEvents.isEmpty && !UserManager.shared.isLoadingEvents && UserManager.shared.eventsLoaded {
            UserManager.shared.refreshResidentData()
        }
    }

    /// Legacy: Direct listener for events (bypasses UserManager)
    func startListeningForEventsDirectly(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForEvents()

        _legacyIsLoadingEvents = true

        #if DEBUG
        print("🏠 RESIDENT: Starting direct events listener for hall \(hallId)")
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
            self._legacyIsLoadingEvents = false

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENT: Events listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self._legacyUpcomingEvents = []
                return
            }

            self._legacyUpcomingEvents = documents.compactMap { doc -> HallEvent? in
                self.parseEvent(doc)
            }

            #if DEBUG
            print("🏠 RESIDENT: Loaded \(self._legacyUpcomingEvents.count) upcoming events")
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
        stopListeningForHallInfo()
    }

    func stopListeningForAssignedRA() {
        #if canImport(FirebaseFirestore)
        if let listener = assignedRAListener as? ListenerRegistration {
            listener.remove()
            assignedRAListener = nil
        }
        #endif
    }

    func stopListeningForHallInfo() {
        #if canImport(FirebaseFirestore)
        if let listener = hallInfoListener as? ListenerRegistration {
            listener.remove()
            hallInfoListener = nil
        }
        #endif
    }

    // MARK: - Load Hall Info

    /// Start listening for hall information
    /// OPTIMIZED: Now proxies from UserManager.currentHall - loaded on login
    func startListeningForHallInfo(hallId: String) {
        #if DEBUG
        print("🏠 RESIDENT: startListeningForHallInfo() - proxied from UserManager.currentHall")
        #endif

        // Hall info is automatically loaded by UserManager when user logs in
        // No action needed - hallInfo computed property proxies from UserManager
    }

    /// Legacy: Direct listener for hall info (bypasses UserManager)
    func startListeningForHallInfoDirectly(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForHallInfo()

        _legacyIsLoadingHallInfo = true

        #if DEBUG
        print("🏠 RESIDENT: Starting direct hall info listener for hall \(hallId)")
        #endif

        let docRef = db.collection("halls").document(hallId)

        hallInfoListener = docRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self._legacyIsLoadingHallInfo = false

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENT: Hall info listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let data = snapshot?.data(),
                  let name = data["name"] as? String else {
                #if DEBUG
                print("🏠 RESIDENT: No hall info found")
                #endif
                self._legacyHallInfo = nil
                return
            }

            self._legacyHallInfo = HallInfo(
                id: hallId,
                name: name,
                shortName: data["shortName"] as? String,
                address: data["address"] as? String
            )

            #if DEBUG
            print("🏠 RESIDENT: Hall info loaded: \(name)")
            #endif
        }
        #endif
    }

    // MARK: - Load Assigned RA by UID

    /// Load assigned RA directly by UID (for when assignedRAUid is stored on user doc)
    /// OPTIMIZED: Now delegates to UserManager - data is loaded in parallel on login
    func loadAssignedRA(hallId: String, raUid: String) {
        #if DEBUG
        print("🏠 RESIDENT: loadAssignedRA() - delegating to UserManager")
        #endif

        // Data is already loaded by UserManager on resident login
        // Only refresh if explicitly empty and not loading
        if UserManager.shared.assignedRA == nil && !UserManager.shared.isLoadingAssignedRA && UserManager.shared.assignedRALoaded {
            UserManager.shared.refreshResidentData()
        }
    }

    /// Legacy: Direct load for assigned RA (bypasses UserManager)
    func loadAssignedRADirectly(hallId: String, raUid: String) {
        #if canImport(FirebaseFirestore)
        _legacyIsLoadingAssignedRA = true

        #if DEBUG
        print("🏠 RESIDENT: Loading assigned RA directly by UID: \(raUid)")
        #endif

        Task {
            await self.loadRADetails(hallId: hallId, raUid: raUid)
            await MainActor.run {
                self._legacyIsLoadingAssignedRA = false
            }
        }
        #endif
    }

    // MARK: - Load Assigned RA

    /// Start listening for resident's assigned RA from hall manifest
    /// Note: This requires the hall/resident/RA manifest to be created by staff via web client
    /// Legacy: Direct listener (bypasses UserManager)
    func startListeningForAssignedRA(hallId: String, residentUid: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForAssignedRA()

        _legacyIsLoadingAssignedRA = true

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
            self._legacyIsLoadingAssignedRA = false

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
                self._legacyAssignedRA = nil
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
                self._legacyAssignedRA = AssignedRA(
                    odRAuid: raUid,
                    displayName: displayName,
                    room: data["room"] as? String,
                    email: data["email"] as? String,
                    floor: data["floor"] as? Int,
                    wing: data["wing"] as? String
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
