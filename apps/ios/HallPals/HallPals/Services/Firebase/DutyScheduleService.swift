import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Duty Shift Model (Firebase)

/// Duty shift from /halls/{hallId}/duty_shifts or /halls/{hallId}/shifts
struct DutyShift: Identifiable, Equatable {
    let id: String
    let odRAuid: String
    let raName: String?
    let start: Date
    let end: Date
    let syncedAt: Date?

    var durationHours: Double {
        end.timeIntervalSince(start) / 3600
    }

    var isActive: Bool {
        let now = Date()
        return now >= start && now <= end
    }

    var isUpcoming: Bool {
        start > Date()
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(start)
    }

    var isTomorrow: Bool {
        Calendar.current.isDateInTomorrow(start)
    }

    var formattedStartTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: start)
    }

    var formattedEndTime: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: end)
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE, MMM d"
        return formatter.string(from: start)
    }

    var formattedRange: String {
        "\(formattedDate) - \(formattedStartTime) - \(formattedEndTime)"
    }
}

// MARK: - Duty Schedule Service

/// Service for fetching RA's duty schedules from Firebase
/// OPTIMIZED: Now proxies data from UserManager's centralized batch loading
/// UserManager loads shifts in parallel with other RA data on login
/// This service provides backward compatibility for views still referencing it
@MainActor
class DutyScheduleService: ObservableObject {

    // MARK: - Singleton

    static let shared = DutyScheduleService()

    // MARK: - Published State (proxied from UserManager)

    /// Shifts are now loaded centrally by UserManager
    /// These computed properties proxy the data for backward compatibility
    var myShifts: [DutyShift] {
        // If legacy local data exists, use it; otherwise use UserManager
        if !_legacyShifts.isEmpty { return _legacyShifts }
        return UserManager.shared.myShifts
    }

    var isLoading: Bool {
        if _legacyIsLoading { return true }
        return UserManager.shared.isLoadingRAData && !UserManager.shared.shiftsLoaded
    }

    var errorMessage: String? {
        if _legacyErrorMessage != nil { return _legacyErrorMessage }
        return UserManager.shared.shiftsError
    }

    @Published var lastUpdated: Date?

    // MARK: - Legacy State (for direct fetch methods)

    /// Used by legacy fetchMyShiftsDirectly() for backward compatibility
    @Published private var _legacyShifts: [DutyShift] = []
    @Published private var _legacyIsLoading = false
    @Published private var _legacyErrorMessage: String?

    // MARK: - Cached Values

    private var cachedHallId: String?

    // MARK: - Computed Properties (proxied from UserManager)

    var activeShift: DutyShift? {
        UserManager.shared.activeShift
    }

    var nextShift: DutyShift? {
        UserManager.shared.nextShift
    }

    var upcomingShifts: [DutyShift] {
        UserManager.shared.upcomingShifts
    }

    var thisWeekShifts: [DutyShift] {
        UserManager.shared.thisWeekShifts
    }

    var isOnDuty: Bool {
        UserManager.shared.isOnDuty
    }

    var hasSyncedSchedule: Bool {
        UserManager.shared.shiftsLoaded && !UserManager.shared.myShifts.isEmpty
    }

    var shiftCount: Int {
        UserManager.shared.shiftCount
    }

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    // MARK: - Init

    private init() {}

    deinit {
        listener?.remove()
        listener = nil
    }

    // MARK: - Fetch My Shifts

    /// Fetches duty shifts for the current RA
    /// OPTIMIZED: Now triggers refresh via UserManager's centralized batch loading
    /// UserManager loads shifts in parallel with residents for better performance
    func fetchMyShifts() {
        #if DEBUG
        print("📅 SCHEDULE: fetchMyShifts() called - delegating to UserManager.refreshRAData()")
        #endif

        // Trigger refresh via UserManager (loads shifts + residents in parallel)
        UserManager.shared.refreshRAData()
        lastUpdated = Date()
    }

    // MARK: - Legacy Fetch Methods (kept for fallback scenarios)

    /// Legacy: Fetches duty shifts directly (bypasses UserManager)
    /// Only used if UserManager fails or for specific edge cases
    func fetchMyShiftsDirectly() {
        stopListening()

        guard let userEmail = Auth.auth().currentUser?.email else {
            #if DEBUG
            print("📅 SCHEDULE: No active user email - cannot fetch shifts")
            #endif
            return
        }

        #if DEBUG
        print("📅 SCHEDULE: Direct fetch for email: \(userEmail)")
        #endif

        // Get hallId from UserManager (already set from user profile)
        let hallId = UserManager.shared.currentUser?.hallId ?? ""

        if hallId.isEmpty {
            #if DEBUG
            print("📅 SCHEDULE: No hallId found in UserManager, trying collection group query")
            #endif
            // Fallback: Try collection group query on members
            fetchHallIdFromMembers(userEmail: userEmail)
        } else {
            #if DEBUG
            print("📅 SCHEDULE: Using hallId from UserManager: \(hallId)")
            #endif
            self.cachedHallId = hallId
            self.fetchShiftsInHall(hallId: hallId, userEmail: userEmail)
        }
    }

    /// Fallback: Find hall via members collection group query using email
    private func fetchHallIdFromMembers(userEmail: String) {
        // Try to find by email first
        db.collectionGroup("members")
            .whereField("email", isEqualTo: userEmail)
            .getDocuments { [weak self] snapshot, error in
                Task { @MainActor [weak self] in
                    guard let self = self else { return }

                    if let error = error {
                        self._legacyIsLoading = false
                        self._legacyErrorMessage = "Failed to find hall: \(error.localizedDescription)"
                        #if DEBUG
                        print("📅 SCHEDULE: Collection group query error - \(error.localizedDescription)")
                        #endif
                        return
                    }

                    #if DEBUG
                    print("📅 SCHEDULE: Members query returned \(snapshot?.documents.count ?? 0) documents")
                    for doc in snapshot?.documents ?? [] {
                        let data = doc.data()
                        print("📅 SCHEDULE: Member doc - path: \(doc.reference.path), role: \(data["role"] ?? "nil"), email: \(data["email"] ?? "nil")")
                    }
                    #endif

                    guard let memberDoc = snapshot?.documents.first else {
                        self._legacyIsLoading = false
                        self._legacyShifts = []
                        self._legacyErrorMessage = "No hall assignment found."
                        #if DEBUG
                        print("📅 SCHEDULE: No member document found for email \(userEmail)")
                        #endif
                        return
                    }

                    // Extract hallId from document path: halls/{hallId}/members/{memberId}
                    guard let hallId = memberDoc.reference.parent.parent?.documentID else {
                        self._legacyIsLoading = false
                        self._legacyErrorMessage = "Could not determine hall."
                        #if DEBUG
                        print("📅 SCHEDULE: Could not extract hallId from member doc path")
                        #endif
                        return
                    }

                    #if DEBUG
                    print("📅 SCHEDULE: Found hall \(hallId) from members query")
                    #endif

                    self.cachedHallId = hallId
                    self.fetchShiftsInHall(hallId: hallId, userEmail: userEmail)
                }
            }
    }

    /// Fetches shifts from /halls/{hallId}/shifts where email matches current user
    private func fetchShiftsInHall(hallId: String, userEmail: String) {
        #if DEBUG
        print("📅 SCHEDULE: Querying shifts collection at halls/\(hallId)/shifts for email \(userEmail)")
        #endif

        // Query shifts where email matches current user, ordered by startTime
        let query = db.collection("halls")
            .document(hallId)
            .collection("shifts")
            .whereField("email", isEqualTo: userEmail)
            .order(by: "startTime", descending: false)

        #if DEBUG
        print("📅 SCHEDULE: Querying shifts where email == \(userEmail)")
        #endif

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self._legacyIsLoading = false

                if let error = error {
                    self._legacyErrorMessage = "Error loading shifts: \(error.localizedDescription)"
                    #if DEBUG
                    print("📅 SCHEDULE: Query error - \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = snapshot?.documents else {
                    self._legacyShifts = []
                    self._legacyErrorMessage = "No shifts found."
                    #if DEBUG
                    print("📅 SCHEDULE: No documents returned from query")
                    #endif
                    return
                }

                #if DEBUG
                print("📅 SCHEDULE: Query returned \(documents.count) shifts")
                #endif

                self._legacyShifts = documents.compactMap { doc -> DutyShift? in
                    let shift = self.parseShift(doc)
                    #if DEBUG
                    if shift == nil {
                        print("📅 SCHEDULE: Failed to parse shift doc \(doc.documentID): \(doc.data())")
                    } else {
                        print("📅 SCHEDULE: Parsed shift \(doc.documentID): \(shift!.formattedRange)")
                    }
                    #endif
                    return shift
                }

                self.lastUpdated = Date()

                if self._legacyShifts.isEmpty {
                    self._legacyErrorMessage = "No duty shifts assigned yet."
                } else {
                    self._legacyErrorMessage = nil
                }

                #if DEBUG
                print("📅 SCHEDULE: Loaded \(self._legacyShifts.count) shifts for email \(userEmail)")
                #endif
            }
        }
    }

    // MARK: - Fetch All Duty Shifts (for showing who's on duty)

    /// Fetches all upcoming duty shifts in the hall (for RAs to see full schedule)
    func fetchAllDutyShifts(hallId: String) {
        stopListening()
        _legacyIsLoading = true
        _legacyErrorMessage = nil
        _legacyShifts = []

        let now = Date()

        // Query shifts where startTime >= now
        let query = db.collection("halls")
            .document(hallId)
            .collection("shifts")
            .whereField("startTime", isGreaterThanOrEqualTo: Timestamp(date: now))
            .order(by: "startTime", descending: false)
            .limit(to: 50)

        listener = query.addSnapshotListener { [weak self] snapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                self._legacyIsLoading = false

                if let error = error {
                    self._legacyErrorMessage = "Error loading duty shifts: \(error.localizedDescription)"
                    return
                }

                guard let documents = snapshot?.documents else {
                    self._legacyShifts = []
                    return
                }

                self._legacyShifts = documents.compactMap { doc -> DutyShift? in
                    self.parseDutyShift(doc)
                }

                self.lastUpdated = Date()

                #if DEBUG
                print("📅 SCHEDULE: Loaded \(self._legacyShifts.count) duty shifts for hall \(hallId)")
                #endif
            }
        }
    }

    // MARK: - Parsing

    /// Parses shift document with fields: email, displayName, startTime, endTime, role
    private func parseShift(_ doc: QueryDocumentSnapshot) -> DutyShift? {
        let data = doc.data()

        // Use email as identifier, and startTime/endTime for timestamps
        guard let email = data["email"] as? String,
              let startTimestamp = data["startTime"] as? Timestamp,
              let endTimestamp = data["endTime"] as? Timestamp else {
            #if DEBUG
            print("📅 SCHEDULE: parseShift failed - email: \(data["email"] ?? "nil"), startTime: \(data["startTime"] ?? "nil"), endTime: \(data["endTime"] ?? "nil")")
            #endif
            return nil
        }

        return DutyShift(
            id: doc.documentID,
            odRAuid: email,
            raName: data["displayName"] as? String,
            start: startTimestamp.dateValue(),
            end: endTimestamp.dateValue(),
            syncedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )
    }

    /// Parses duty_shifts collection (may use different field names)
    private func parseDutyShift(_ doc: QueryDocumentSnapshot) -> DutyShift? {
        let data = doc.data()

        // Try both field name conventions
        let identifier = data["email"] as? String ?? data["odRAuid"] as? String ?? data["userId"] as? String
        let startTimestamp = data["startTime"] as? Timestamp ?? data["start"] as? Timestamp
        let endTimestamp = data["endTime"] as? Timestamp ?? data["end"] as? Timestamp

        guard let id = identifier,
              let start = startTimestamp,
              let end = endTimestamp else {
            return nil
        }

        return DutyShift(
            id: doc.documentID,
            odRAuid: id,
            raName: data["displayName"] as? String ?? data["raName"] as? String,
            start: start.dateValue(),
            end: end.dateValue(),
            syncedAt: (data["updatedAt"] as? Timestamp)?.dateValue() ?? (data["syncedAt"] as? Timestamp)?.dateValue()
        )
    }

    // MARK: - Stop Listening

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Clear Data

    func clearData() {
        stopListening()
        _legacyShifts = []
        _legacyErrorMessage = nil
        lastUpdated = nil
        cachedHallId = nil
    }

    // MARK: - Get Current Hall ID

    func getHallId() -> String? {
        cachedHallId
    }
}
