import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

// MARK: - User Profile Model

struct HallPalsUser: Codable, Equatable {
    let uid: String
    let email: String
    var displayName: String?
    var role: String
    var hallId: String?
    var roomNumber: String?
    var floor: Int?
    var wing: String?
    var assignedRAUid: String?
    var createdAt: Date?
    var updatedAt: Date?
}

// MARK: - User Manager

/// Manages the current user's profile data from Firestore
/// OPTIMIZED: Provides centralized data loading for all RA data (user, shifts, residents)
/// Other services should observe this manager's published properties instead of fetching independently
@MainActor
final class UserManager: ObservableObject {

    // MARK: - Singleton

    static let shared = UserManager()

    // MARK: - Published State (Core User Data)

    @Published private(set) var currentUser: HallPalsUser?
    @Published private(set) var currentHall: Hall?
    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // MARK: - Published State (RA Data - Optimized Batch Loading)

    /// All shifts for current RA - loaded once on login, updated via listener
    @Published private(set) var myShifts: [DutyShift] = []
    @Published private(set) var shiftsLoaded = false
    @Published private(set) var shiftsError: String?

    /// All residents for current RA - loaded once on login
    @Published private(set) var myResidents: [HallResident] = []
    @Published private(set) var residentsLoaded = false
    @Published private(set) var residentsError: String?

    /// Loading state for batch data
    @Published private(set) var isLoadingRAData = false

    // MARK: - Published State (Resident Data - Optimized Batch Loading)

    /// On-duty RA - real-time listener for current duty shift
    @Published private(set) var onDutyRA: OnDutyRA?
    @Published private(set) var onDutyRALoaded = false
    @Published private(set) var isLoadingOnDutyRA = false

    /// Assigned RA (resident's personal RA)
    @Published private(set) var assignedRA: AssignedRA?
    @Published private(set) var assignedRALoaded = false
    @Published private(set) var isLoadingAssignedRA = false

    /// Upcoming hall events (first 5)
    @Published private(set) var upcomingEvents: [HallEvent] = []
    @Published private(set) var eventsLoaded = false
    @Published private(set) var isLoadingEvents = false

    /// Loading state for resident data
    @Published private(set) var isLoadingResidentData = false

    // MARK: - Computed Properties (User)

    var currentUserId: String? {
        return Auth.auth().currentUser?.uid
    }

    var currentUserEmail: String? {
        return Auth.auth().currentUser?.email
    }

    var isAuthenticated: Bool {
        currentUserId != nil
    }

    var hallId: String? {
        currentUser?.hallId
    }

    var roomNumber: String? {
        currentUser?.roomNumber
    }

    var floor: Int? {
        currentUser?.floor
    }

    var wing: String? {
        currentUser?.wing
    }

    var assignedRAUid: String? {
        currentUser?.assignedRAUid
    }

    var isRA: Bool {
        currentUser?.role == "ra"
    }

    // MARK: - Computed Properties (Shifts)

    var activeShift: DutyShift? {
        myShifts.first { $0.isActive }
    }

    var nextShift: DutyShift? {
        upcomingShifts.first
    }

    var upcomingShifts: [DutyShift] {
        let now = Date()
        return myShifts
            .filter { $0.start > now }
            .sorted { $0.start < $1.start }
    }

    var thisWeekShifts: [DutyShift] {
        let calendar = Calendar.current
        let now = Date()
        let endOfWeek = calendar.date(byAdding: .day, value: 7, to: now)!
        return myShifts
            .filter { $0.start >= now && $0.start <= endOfWeek }
            .sorted { $0.start < $1.start }
    }

    var isOnDuty: Bool {
        activeShift != nil
    }

    var shiftCount: Int {
        myShifts.count
    }

    // MARK: - Computed Properties (Residents)

    var residentCount: Int {
        myResidents.count
    }

    var sortedResidents: [HallResident] {
        myResidents.sorted { $0.lastName.lowercased() < $1.lastName.lowercased() }
    }

    // MARK: - Private Properties

    private let db = Firestore.firestore()
    private var userListener: ListenerRegistration?
    private var hallListener: ListenerRegistration?
    private var shiftsListener: ListenerRegistration?
    private var dutyRAListener: ListenerRegistration?
    private var eventsListener: ListenerRegistration?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        setupAuthObserver()
    }

    deinit {
        userListener?.remove()
        userListener = nil
        hallListener?.remove()
        hallListener = nil
        shiftsListener?.remove()
        shiftsListener = nil
        dutyRAListener?.remove()
        dutyRAListener = nil
        eventsListener?.remove()
        eventsListener = nil
    }

    // MARK: - Auth Observer

    private func setupAuthObserver() {
        Auth.auth().addStateDidChangeListener { [weak self] _, user in
            Task { @MainActor in
                if let uid = user?.uid {
                    self?.startListening(uid: uid)
                } else {
                    self?.stopListening()
                    self?.currentUser = nil
                }
            }
        }
    }

    // MARK: - Firestore Listener

    /// Start listening to the current user's profile document
    func startListening(uid: String) {
        stopListening()

        isLoading = true
        error = nil

        #if DEBUG
        print("👤 USER: Starting listener for user \(uid)")
        #endif

        let userRef = db.collection("users").document(uid)

        userListener = userRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            self.isLoading = false

            if let error = error {
                #if DEBUG
                print("👤 USER: Error listening to user profile - \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                #if DEBUG
                print("👤 USER: User document not found for \(uid)")
                #endif
                self.currentUser = nil
                return
            }

            // Parse user data
            let user = HallPalsUser(
                uid: uid,
                email: data["email"] as? String ?? "",
                displayName: data["displayName"] as? String,
                role: data["role"] as? String ?? "resident",
                hallId: data["hallId"] as? String,
                roomNumber: data["roomNumber"] as? String,
                floor: data["floor"] as? Int,
                wing: data["wing"] as? String,
                assignedRAUid: data["assignedRAUid"] as? String,
                createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
                updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
            )

            self.currentUser = user

            #if DEBUG
            print("👤 USER: Profile loaded - role: \(user.role), hallId: \(user.hallId ?? "none"), floor: \(user.floor ?? -1), wing: \(user.wing ?? "none")")
            #endif

            // Start listening to hall data if user has a hallId
            if let hallId = user.hallId, !hallId.isEmpty {
                self.startHallListener(hallId: hallId)

                // OPTIMIZATION: Batch load role-specific data
                if user.role == "ra" {
                    // RA: Load shifts and their assigned residents
                    self.loadRADataInParallel(hallId: hallId, user: user)
                } else {
                    // Resident: Enrich user profile with member data, then load resident data
                    self.enrichResidentProfile(hallId: hallId, user: user)
                }
            } else {
                self.stopHallListener()
                self.stopRADataListeners()
                self.stopResidentDataListeners()
                self.currentHall = nil
            }
        }
    }

    /// Stop listening to user profile changes and clear all cached data
    func stopListening() {
        userListener?.remove()
        userListener = nil
        currentUser = nil
        stopHallListener()
        stopRADataListeners()
        stopResidentDataListeners()
    }

    /// Stop all RA data listeners
    private func stopRADataListeners() {
        shiftsListener?.remove()
        shiftsListener = nil
        myShifts = []
        shiftsLoaded = false
        myResidents = []
        residentsLoaded = false
    }

    /// Stop all resident data listeners
    private func stopResidentDataListeners() {
        dutyRAListener?.remove()
        dutyRAListener = nil
        eventsListener?.remove()
        eventsListener = nil
        onDutyRA = nil
        onDutyRALoaded = false
        assignedRA = nil
        assignedRALoaded = false
        upcomingEvents = []
        eventsLoaded = false
    }

    // MARK: - Hall Listener

    /// Start listening to the hall document for hall info and director
    func startHallListener(hallId: String) {
        // Don't restart if already listening to same hall
        if currentHall?.hallId == hallId && hallListener != nil {
            return
        }

        stopHallListener()

        #if DEBUG
        print("🏢 HALL: Starting listener for hall \(hallId)")
        #endif

        let hallRef = db.collection("halls").document(hallId)

        hallListener = hallRef.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("🏢 HALL: Error listening to hall - \(error.localizedDescription)")
                #endif
                return
            }

            guard let snapshot = snapshot, snapshot.exists, let data = snapshot.data() else {
                #if DEBUG
                print("🏢 HALL: Hall document not found for \(hallId)")
                #endif
                self.currentHall = nil
                return
            }

            // Parse hall director if present
            var hallDirector: HallDirector?
            if let directorData = data["hallDirector"] as? [String: Any] {
                hallDirector = HallDirector(
                    uid: directorData["uid"] as? String,
                    name: directorData["name"] as? String ?? "Unknown",
                    email: directorData["email"] as? String,
                    phone: directorData["phone"] as? String
                )
            }

            // Parse hall data
            let hall = Hall(
                hallId: hallId,
                name: data["name"] as? String ?? hallId,
                shortName: data["shortName"] as? String,
                address: data["address"] as? String,
                floors: data["floors"] as? [Int],
                wings: data["wings"] as? [String],
                hallDirector: hallDirector,
                isActive: data["isActive"] as? Bool ?? true
            )

            self.currentHall = hall

            #if DEBUG
            print("🏢 HALL: Hall loaded - name: \(hall.name), director: \(hall.hallDirector?.name ?? "none")")
            #endif
        }
    }

    /// Stop listening to hall changes
    private func stopHallListener() {
        hallListener?.remove()
        hallListener = nil
        currentHall = nil
    }

    // MARK: - Manual Fetch (for one-time reads)

    /// Fetch the current user's profile once (non-realtime)
    func fetchCurrentUser() async throws -> HallPalsUser? {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw UserManagerError.notAuthenticated
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let snapshot = try await db.collection("users").document(uid).getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            return nil
        }

        let user = HallPalsUser(
            uid: uid,
            email: data["email"] as? String ?? "",
            displayName: data["displayName"] as? String,
            role: data["role"] as? String ?? "resident",
            hallId: data["hallId"] as? String,
            roomNumber: data["roomNumber"] as? String,
            floor: data["floor"] as? Int,
            wing: data["wing"] as? String,
            assignedRAUid: data["assignedRAUid"] as? String,
            createdAt: (data["createdAt"] as? Timestamp)?.dateValue(),
            updatedAt: (data["updatedAt"] as? Timestamp)?.dateValue()
        )

        self.currentUser = user
        return user
    }

    // MARK: - Hall ID Lookup via Members Collection Group

    /// Fetch hall ID by querying the members collection group
    /// Useful when user's hallId is not set directly on their user document
    /// Uses the composite index on members(userId, role)
    func fetchHallIdFromMembership() async throws -> String? {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw UserManagerError.notAuthenticated
        }

        #if DEBUG
        print("👤 USER: Looking up hall membership for user \(uid)")
        #endif

        // Query ALL 'members' collections across the database
        let snapshot = try await db.collectionGroup("members")
            .whereField("userId", isEqualTo: uid)
            .getDocuments()

        guard let doc = snapshot.documents.first else {
            #if DEBUG
            print("👤 USER: No hall membership found for user \(uid)")
            #endif
            return nil
        }

        // The parent of 'members' is the Hall document
        // Path: halls/{hallId}/members/{memberDocId}
        guard let hallId = doc.reference.parent.parent?.documentID else {
            #if DEBUG
            print("👤 USER: Could not extract hallId from membership document path")
            #endif
            return nil
        }

        #if DEBUG
        print("👤 USER: Found hall membership - hallId: \(hallId)")
        #endif

        // Optionally start listening to this hall
        if currentHall == nil || currentHall?.hallId != hallId {
            startHallListener(hallId: hallId)
        }

        return hallId
    }

    /// Fetch hall ID with fallback: first check user doc, then members collection group
    func fetchHallIdWithFallback() async throws -> String? {
        // First, try to get hallId from current user
        if let hallId = currentUser?.hallId, !hallId.isEmpty {
            return hallId
        }

        // Try to fetch user doc if not loaded yet
        if currentUser == nil {
            _ = try await fetchCurrentUser()
            if let hallId = currentUser?.hallId, !hallId.isEmpty {
                return hallId
            }
        }

        // Fallback: look up via members collection group
        return try await fetchHallIdFromMembership()
    }

    // MARK: - Optimized RA Data Loading

    /// OPTIMIZATION: Load shifts and residents in parallel when RA logs in
    /// This replaces the individual service fetches with a single coordinated load
    private func loadRADataInParallel(hallId: String, user: HallPalsUser) {
        guard let email = Auth.auth().currentUser?.email else {
            #if DEBUG
            print("🚀 BATCH: No email available for RA data loading")
            #endif
            return
        }

        isLoadingRAData = true

        #if DEBUG
        print("🚀 BATCH: Starting parallel load for RA data - hallId: \(hallId), email: \(email)")
        let startTime = Date()
        #endif

        // Load shifts with real-time listener
        loadShiftsForRA(hallId: hallId, email: email)

        // Load residents (one-time fetch, can be refreshed manually)
        loadResidentsForRA(hallId: hallId, user: user)

        #if DEBUG
        print("🚀 BATCH: Parallel load initiated in \(Date().timeIntervalSince(startTime) * 1000)ms")
        #endif
    }

    /// Load shifts for RA with real-time listener
    private func loadShiftsForRA(hallId: String, email: String) {
        shiftsListener?.remove()
        shiftsLoaded = false
        shiftsError = nil

        let query = db.collection("halls")
            .document(hallId)
            .collection("shifts")
            .whereField("email", isEqualTo: email)
            .order(by: "startTime", descending: false)

        shiftsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.shiftsError = error.localizedDescription
                self.shiftsLoaded = true
                self.updateLoadingState()
                #if DEBUG
                print("📅 BATCH-SHIFTS: Error - \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = snapshot?.documents else {
                self.myShifts = []
                self.shiftsLoaded = true
                self.updateLoadingState()
                return
            }

            self.myShifts = documents.compactMap { doc -> DutyShift? in
                let data = doc.data()
                guard let email = data["email"] as? String,
                      let startTimestamp = data["startTime"] as? Timestamp,
                      let endTimestamp = data["endTime"] as? Timestamp else {
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

            self.shiftsLoaded = true
            self.shiftsError = nil
            self.updateLoadingState()

            #if DEBUG
            print("📅 BATCH-SHIFTS: Loaded \(self.myShifts.count) shifts")
            #endif
        }
    }

    /// Load residents for RA (by floor/wing from roster)
    private func loadResidentsForRA(hallId: String, user: HallPalsUser) {
        residentsLoaded = false
        residentsError = nil

        // Get floor/wing from user or roster
        let raEmail = Auth.auth().currentUser?.email?.lowercased() ?? ""
        let rosterRef = db.collection("halls").document(hallId).collection("roster")

        // First get RA's floor/wing from roster
        rosterRef.document(raEmail).getDocument { [weak self] raDoc, error in
            guard let self = self else { return }

            var raFloor: Int? = user.floor
            var raWing: String? = user.wing

            // Use roster data if available
            if let raData = raDoc?.data() {
                if let floorInt = raData["floor"] as? Int {
                    raFloor = floorInt
                }
                raWing = raData["wing"] as? String
            }

            guard let floor = raFloor else {
                self.residentsError = "No floor assignment found"
                self.residentsLoaded = true
                self.updateLoadingState()
                #if DEBUG
                print("🏠 BATCH-RESIDENTS: No floor found for RA")
                #endif
                return
            }

            // Query residents on this floor/wing
            self.fetchResidentsFromRoster(hallId: hallId, floor: floor, wing: raWing, raEmail: raEmail)
        }
    }

    /// Fetch residents from roster by floor/wing
    private func fetchResidentsFromRoster(hallId: String, floor: Int, wing: String?, raEmail: String) {
        let rosterRef = db.collection("halls").document(hallId).collection("roster")

        // Build query for residents on this floor
        var query: Query = rosterRef
            .whereField("role", isEqualTo: "resident")
            .whereField("floor", isEqualTo: floor)

        if let wing = wing, !wing.isEmpty {
            query = query.whereField("wing", isEqualTo: wing)
        }

        // Execute query
        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.residentsError = error.localizedDescription
                self.residentsLoaded = true
                self.updateLoadingState()
                #if DEBUG
                print("🏠 BATCH-RESIDENTS: Error - \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = snapshot?.documents else {
                self.myResidents = []
                self.residentsLoaded = true
                self.updateLoadingState()
                return
            }

            self.myResidents = documents.compactMap { doc -> HallResident? in
                let data = doc.data()
                let email = doc.documentID

                let firstName = data["firstName"] as? String ?? ""
                let lastName = data["lastName"] as? String ?? ""
                let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

                return HallResident(
                    id: email,
                    displayName: displayName.isEmpty ? email : displayName,
                    email: email,
                    roomNumber: data["roomNumber"] as? String ?? "",
                    floor: data["floor"] as? Int ?? 0,
                    wing: data["wing"] as? String,
                    role: "resident"
                )
            }

            self.residentsLoaded = true
            self.residentsError = nil
            self.updateLoadingState()

            #if DEBUG
            print("🏠 BATCH-RESIDENTS: Loaded \(self.myResidents.count) residents")
            #endif
        }
    }

    /// Update overall loading state
    private func updateLoadingState() {
        // Done loading when both shifts and residents are loaded (or errored)
        if shiftsLoaded && residentsLoaded {
            isLoadingRAData = false
            #if DEBUG
            print("🚀 BATCH: All RA data loaded - \(myShifts.count) shifts, \(myResidents.count) residents")
            #endif
        }
    }

    /// Search residents by name, room, or email
    func searchResidents(_ query: String) -> [HallResident] {
        let lowercasedQuery = query.lowercased()
        return sortedResidents.filter { resident in
            resident.displayName.lowercased().contains(lowercasedQuery) ||
            resident.roomNumber.lowercased().contains(lowercasedQuery) ||
            resident.email.lowercased().contains(lowercasedQuery)
        }
    }

    /// Manually refresh RA data (for pull-to-refresh)
    func refreshRAData() {
        guard let hallId = currentUser?.hallId, !hallId.isEmpty,
              let user = currentUser, user.role == "ra" else {
            return
        }
        loadRADataInParallel(hallId: hallId, user: user)
    }

    // MARK: - Resident Profile Enrichment

    /// Fetch additional resident data from member document and/or roster
    /// This enriches the user profile with roomNumber, floor, wing, assignedRAUid
    private func enrichResidentProfile(hallId: String, user: HallPalsUser) {
        #if DEBUG
        print("🏠 RESIDENT-ENRICH: Fetching member data for resident \(user.uid) in hall \(hallId)")
        #endif

        // Try to fetch from member document first
        db.collection("halls").document(hallId).collection("members").document(user.uid)
            .getDocument { [weak self] memberSnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("🏠 RESIDENT-ENRICH: Member doc error - \(error.localizedDescription)")
                    #endif
                    // Continue with user profile as-is
                    self.loadResidentDataInParallel(hallId: hallId, user: user)
                    return
                }

                var enrichedUser = user

                if let memberData = memberSnapshot?.data() {
                    #if DEBUG
                    print("🏠 RESIDENT-ENRICH: Found member doc - room: \(memberData["roomNumber"] ?? "none"), floor: \(memberData["floor"] ?? "none"), wing: \(memberData["wing"] ?? "none")")
                    #endif

                    // Merge member data into user if fields are missing
                    if enrichedUser.roomNumber == nil || enrichedUser.roomNumber?.isEmpty == true {
                        enrichedUser.roomNumber = memberData["roomNumber"] as? String
                    }
                    if enrichedUser.floor == nil {
                        enrichedUser.floor = memberData["floor"] as? Int
                    }
                    if enrichedUser.wing == nil || enrichedUser.wing?.isEmpty == true {
                        enrichedUser.wing = memberData["wing"] as? String
                    }
                    if enrichedUser.assignedRAUid == nil || enrichedUser.assignedRAUid?.isEmpty == true {
                        enrichedUser.assignedRAUid = memberData["assignedRAUid"] as? String
                    }

                    // Update currentUser with enriched data
                    self.currentUser = enrichedUser

                    #if DEBUG
                    print("🏠 RESIDENT-ENRICH: Enriched profile - room: \(enrichedUser.roomNumber ?? "none"), floor: \(enrichedUser.floor ?? -1), wing: \(enrichedUser.wing ?? "none"), assignedRA: \(enrichedUser.assignedRAUid ?? "none")")
                    #endif

                    // Now load resident data with enriched profile
                    self.loadResidentDataInParallel(hallId: hallId, user: enrichedUser)
                } else {
                    // No member doc, try roster by email
                    self.enrichFromRoster(hallId: hallId, user: user)
                }
            }
    }

    /// Fallback: Fetch from roster document by email
    private func enrichFromRoster(hallId: String, user: HallPalsUser) {
        guard let email = user.email.lowercased() as String?, !email.isEmpty else {
            self.loadResidentDataInParallel(hallId: hallId, user: user)
            return
        }

        #if DEBUG
        print("🏠 RESIDENT-ENRICH: Trying roster lookup for \(email)")
        #endif

        db.collection("halls").document(hallId).collection("roster").document(email)
            .getDocument { [weak self] rosterSnapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("🏠 RESIDENT-ENRICH: Roster doc error - \(error.localizedDescription)")
                    #endif
                    self.loadResidentDataInParallel(hallId: hallId, user: user)
                    return
                }

                var enrichedUser = user

                if let rosterData = rosterSnapshot?.data() {
                    #if DEBUG
                    print("🏠 RESIDENT-ENRICH: Found roster doc - room: \(rosterData["room"] ?? rosterData["roomNumber"] ?? "none"), floor: \(rosterData["floor"] ?? "none")")
                    #endif

                    if enrichedUser.roomNumber == nil || enrichedUser.roomNumber?.isEmpty == true {
                        enrichedUser.roomNumber = rosterData["room"] as? String ?? rosterData["roomNumber"] as? String
                    }
                    if enrichedUser.floor == nil {
                        enrichedUser.floor = rosterData["floor"] as? Int
                    }
                    if enrichedUser.wing == nil || enrichedUser.wing?.isEmpty == true {
                        enrichedUser.wing = rosterData["wing"] as? String
                    }
                    if enrichedUser.assignedRAUid == nil || enrichedUser.assignedRAUid?.isEmpty == true {
                        enrichedUser.assignedRAUid = rosterData["assignedRAUid"] as? String ?? rosterData["raUid"] as? String
                    }

                    self.currentUser = enrichedUser

                    #if DEBUG
                    print("🏠 RESIDENT-ENRICH: Enriched from roster - room: \(enrichedUser.roomNumber ?? "none"), floor: \(enrichedUser.floor ?? -1)")
                    #endif
                }

                self.loadResidentDataInParallel(hallId: hallId, user: enrichedUser)
            }
    }

    // MARK: - Optimized Resident Data Loading

    /// OPTIMIZATION: Load on-duty RA, assigned RA, and events in parallel when resident logs in
    private func loadResidentDataInParallel(hallId: String, user: HallPalsUser) {
        isLoadingResidentData = true

        #if DEBUG
        print("🏠 BATCH-RESIDENT: Starting parallel load for resident data - hallId: \(hallId), assignedRAUid: \(user.assignedRAUid ?? "none"), floor: \(user.floor ?? -1), wing: \(user.wing ?? "none")")
        let startTime = Date()
        #endif

        // Load on-duty RA with real-time listener
        loadOnDutyRA(hallId: hallId)

        // Load assigned RA - by UID if available, otherwise by floor/wing
        if let raUid = user.assignedRAUid, !raUid.isEmpty {
            loadAssignedRA(hallId: hallId, raUid: raUid)
        } else if let floor = user.floor, floor > 0 {
            // No explicit RA assignment - find RA by matching floor/wing
            findAssignedRAByFloorWing(hallId: hallId, floor: floor, wing: user.wing)
        } else {
            assignedRALoaded = true
        }

        // Load upcoming events with real-time listener
        loadUpcomingEvents(hallId: hallId)

        #if DEBUG
        print("🏠 BATCH-RESIDENT: Parallel load initiated in \(Date().timeIntervalSince(startTime) * 1000)ms")
        #endif
    }

    /// Load on-duty RA with real-time listener
    /// Queries the shifts collection for shifts where startTime <= now AND endTime > now
    private func loadOnDutyRA(hallId: String) {
        dutyRAListener?.remove()
        onDutyRALoaded = false
        isLoadingOnDutyRA = true

        #if DEBUG
        print("🏠 BATCH-DUTY: Loading on-duty RA for hall \(hallId)")
        #endif

        // Query shifts where startTime <= now, ordered by startTime desc, limit 10
        // Then filter in-memory for endTime > now
        let now = Date()
        let query = db.collection("halls")
            .document(hallId)
            .collection("shifts")
            .whereField("startTime", isLessThanOrEqualTo: Timestamp(date: now))
            .order(by: "startTime", descending: true)
            .limit(to: 10)

        dutyRAListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingOnDutyRA = false

            if let error = error {
                #if DEBUG
                print("🏠 BATCH-DUTY: Error - \(error.localizedDescription)")
                #endif
                self.onDutyRA = nil
                self.onDutyRALoaded = true
                self.updateResidentLoadingState()
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                #if DEBUG
                print("🏠 BATCH-DUTY: No shifts found in halls/\(hallId)/shifts")
                #endif
                self.onDutyRA = nil
                self.onDutyRALoaded = true
                self.updateResidentLoadingState()
                return
            }

            #if DEBUG
            print("🏠 BATCH-DUTY: Found \(documents.count) shifts to check")
            #endif

            // Find the first shift that's still active (endTime > now)
            let nowDate = Date()
            for doc in documents {
                let data = doc.data()
                // Support both field name conventions: endTime (new) and end (legacy)
                if let endTimestamp = data["endTime"] as? Timestamp ?? data["end"] as? Timestamp {
                    if endTimestamp.dateValue() > nowDate {
                        // Check if we need to resolve UID from email
                        let hasUid = (data["uid"] as? String) != nil ||
                                     (data["odRAuid"] as? String) != nil ||
                                     (data["userId"] as? String) != nil

                        if hasUid {
                            // Has direct UID - parse immediately
                            self.onDutyRA = self.parseOnDutyRA(data, docId: doc.documentID)
                            #if DEBUG
                            if let ra = self.onDutyRA {
                                print("🏠 BATCH-DUTY: On-duty RA found: \(ra.displayName)")
                            } else {
                                print("🏠 BATCH-DUTY: Failed to parse shift doc: \(data)")
                            }
                            #endif
                            self.onDutyRALoaded = true
                            self.updateResidentLoadingState()
                        } else if let email = data["email"] as? String, !email.isEmpty {
                            // No UID but has email - resolve UID from email_index
                            self.resolveOnDutyRAFromEmail(shiftData: data, email: email, docId: doc.documentID)
                        } else {
                            // No UID and no email - still show RA info but DM won't work
                            self.onDutyRA = self.parseOnDutyRA(data, docId: doc.documentID)
                            self.onDutyRALoaded = true
                            self.updateResidentLoadingState()
                        }
                        return
                    }
                }
            }

            // No active shift found
            #if DEBUG
            print("🏠 BATCH-DUTY: No active shift found (all shifts ended)")
            #endif
            self.onDutyRA = nil
            self.onDutyRALoaded = true
            self.updateResidentLoadingState()
        }
    }

    /// Resolve RA UID from email_index when shift document only has email
    private func resolveOnDutyRAFromEmail(shiftData: [String: Any], email: String, docId: String) {
        db.collection("email_index").document(email).getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let data = snapshot?.data(), let uid = data["uid"] as? String {
                // Found UID - merge into shift data and parse
                var mergedData = shiftData
                mergedData["userId"] = uid
                self.onDutyRA = self.parseOnDutyRA(mergedData, docId: docId)
            } else {
                // Couldn't resolve - still parse without UID (DM won't work)
                self.onDutyRA = self.parseOnDutyRA(shiftData, docId: docId)
            }

            self.onDutyRALoaded = true
            self.updateResidentLoadingState()
        }
    }

    /// Parse duty shift data to OnDutyRA model
    /// Supports both field name conventions for backward compatibility
    /// NOTE: Does NOT use email as fallback for UID - use resolveOnDutyRAFromEmail first if needed
    private func parseOnDutyRA(_ data: [String: Any], docId: String) -> OnDutyRA? {
        // Get RA identifier - try multiple field names (but NOT email - email is not a UID)
        let odRAuid = data["uid"] as? String ?? data["odRAuid"] as? String ?? data["userId"] as? String
        // Get display name - fall back to email prefix if no name
        let email = data["email"] as? String
        let displayName = data["displayName"] as? String ?? data["raName"] as? String ?? data["name"] as? String ?? email?.components(separatedBy: "@").first
        // Get timestamps - support both conventions
        let start = (data["startTime"] as? Timestamp)?.dateValue() ?? (data["start"] as? Timestamp)?.dateValue()
        let end = (data["endTime"] as? Timestamp)?.dateValue() ?? (data["end"] as? Timestamp)?.dateValue()

        // We can show the RA even without UID (DM just won't work)
        guard let raName = displayName,
              let shiftStart = start,
              let shiftEnd = end else {
            #if DEBUG
            print("🏠 BATCH-DUTY: parseOnDutyRA failed - uid: \(odRAuid ?? "nil"), name: \(displayName ?? "nil"), start: \(start ?? Date()), end: \(end ?? Date())")
            #endif
            return nil
        }

        // If no UID, we'll still return the RA info but DM functionality won't work
        let raId = odRAuid ?? ""

        return OnDutyRA(
            odRAuid: raId,
            displayName: raName,
            room: data["room"] as? String ?? data["roomNumber"] as? String,
            shiftStart: shiftStart,
            shiftEnd: shiftEnd,
            dutyPhone: data["dutyPhone"] as? String ?? data["phone"] as? String
        )
    }

    /// Load assigned RA by UID
    /// Tries staff collection first, then members collection as fallback
    private func loadAssignedRA(hallId: String, raUid: String) {
        assignedRALoaded = false
        isLoadingAssignedRA = true

        #if DEBUG
        print("🏠 BATCH-ASSIGNED: Loading assigned RA by UID: \(raUid)")
        #endif

        // Try staff collection first
        db.collection("halls")
            .document(hallId)
            .collection("staff")
            .document(raUid)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }

                if let data = snapshot?.data(),
                   let displayName = data["displayName"] as? String ?? data["name"] as? String {
                    // Found in staff collection
                    self.assignedRA = AssignedRA(
                        odRAuid: raUid,
                        displayName: displayName,
                        room: data["room"] as? String ?? data["roomNumber"] as? String,
                        email: data["email"] as? String,
                        floor: data["floor"] as? Int,
                        wing: data["wing"] as? String
                    )
                    self.isLoadingAssignedRA = false
                    self.assignedRALoaded = true
                    self.updateResidentLoadingState()

                    #if DEBUG
                    print("🏠 BATCH-ASSIGNED: Found RA in staff collection: \(displayName)")
                    #endif
                    return
                }

                // Not in staff, try members collection
                #if DEBUG
                print("🏠 BATCH-ASSIGNED: Not in staff, trying members collection")
                #endif

                self.db.collection("halls")
                    .document(hallId)
                    .collection("members")
                    .document(raUid)
                    .getDocument { [weak self] memberSnapshot, memberError in
                        guard let self = self else { return }
                        self.isLoadingAssignedRA = false

                        if let data = memberSnapshot?.data(),
                           let displayName = data["displayName"] as? String ?? data["name"] as? String {
                            self.assignedRA = AssignedRA(
                                odRAuid: raUid,
                                displayName: displayName,
                                room: data["room"] as? String ?? data["roomNumber"] as? String,
                                email: data["email"] as? String,
                                floor: data["floor"] as? Int,
                                wing: data["wing"] as? String
                            )

                            #if DEBUG
                            print("🏠 BATCH-ASSIGNED: Found RA in members collection: \(displayName)")
                            #endif
                        } else {
                            // Try users collection as last resort
                            self.loadAssignedRAFromUsers(raUid: raUid)
                            return
                        }

                        self.assignedRALoaded = true
                        self.updateResidentLoadingState()
                    }
            }
    }

    /// Fallback: Load assigned RA from users collection
    private func loadAssignedRAFromUsers(raUid: String) {
        db.collection("users")
            .document(raUid)
            .getDocument { [weak self] snapshot, error in
                guard let self = self else { return }

                if let data = snapshot?.data(),
                   let displayName = data["displayName"] as? String ?? data["name"] as? String {
                    self.assignedRA = AssignedRA(
                        odRAuid: raUid,
                        displayName: displayName,
                        room: data["room"] as? String ?? data["roomNumber"] as? String,
                        email: data["email"] as? String,
                        floor: data["floor"] as? Int,
                        wing: data["wing"] as? String
                    )

                    #if DEBUG
                    print("🏠 BATCH-ASSIGNED: Found RA in users collection: \(displayName)")
                    #endif
                } else {
                    #if DEBUG
                    print("🏠 BATCH-ASSIGNED: No RA profile found for \(raUid) in any collection")
                    #endif
                    self.assignedRA = nil
                }

                self.assignedRALoaded = true
                self.updateResidentLoadingState()
            }
    }

    /// Find assigned RA by matching floor/wing from roster
    /// Used when no explicit assignedRAUid is set on the resident
    private func findAssignedRAByFloorWing(hallId: String, floor: Int, wing: String?) {
        assignedRALoaded = false
        isLoadingAssignedRA = true

        #if DEBUG
        print("🏠 BATCH-ASSIGNED: Finding RA by floor: \(floor), wing: \(wing ?? "any")")
        #endif

        // Query roster for RAs on this floor
        let query = db.collection("halls")
            .document(hallId)
            .collection("roster")
            .whereField("floor", isEqualTo: floor)
            .whereField("role", isEqualTo: "ra")

        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("🏠 BATCH-ASSIGNED: Roster query error - \(error.localizedDescription), falling back to members")
                #endif
                // Fallback to members collection when roster query fails (e.g., permission denied for residents)
                self.findAssignedRAByFloorWingInMembers(hallId: hallId, floor: floor, wing: wing)
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                #if DEBUG
                print("🏠 BATCH-ASSIGNED: No RA found in roster on floor \(floor), trying members collection")
                #endif
                // Fallback: Try members collection
                self.findAssignedRAByFloorWingInMembers(hallId: hallId, floor: floor, wing: wing)
                return
            }

            #if DEBUG
            print("🏠 BATCH-ASSIGNED: Found \(documents.count) RAs on floor \(floor)")
            #endif

            // Find RA matching wing, or first RA if no wing match
            var matchedDoc: QueryDocumentSnapshot?
            for doc in documents {
                let data = doc.data()
                let raWing = data["wing"] as? String
                if let wing = wing, !wing.isEmpty {
                    if raWing?.lowercased() == wing.lowercased() {
                        matchedDoc = doc
                        break
                    }
                } else {
                    matchedDoc = doc
                    break
                }
            }

            // Use first RA if no wing match found
            if matchedDoc == nil {
                matchedDoc = documents.first
            }

            guard let doc = matchedDoc else {
                self.isLoadingAssignedRA = false
                self.assignedRALoaded = true
                self.updateResidentLoadingState()
                return
            }

            let data = doc.data()
            let displayName = data["displayName"] as? String ?? data["name"] as? String ?? data["firstName"] as? String ?? "RA"
            let raUid = data["uid"] as? String ?? data["userId"] as? String ?? doc.documentID

            self.assignedRA = AssignedRA(
                odRAuid: raUid,
                displayName: displayName,
                room: data["room"] as? String ?? data["roomNumber"] as? String,
                email: doc.documentID, // Document ID is the email
                floor: data["floor"] as? Int,
                wing: data["wing"] as? String
            )

            self.isLoadingAssignedRA = false
            self.assignedRALoaded = true
            self.updateResidentLoadingState()

            #if DEBUG
            print("🏠 BATCH-ASSIGNED: Found RA by floor/wing: \(displayName)")
            #endif
        }
    }

    /// Fallback: Find assigned RA by floor/wing in members collection
    private func findAssignedRAByFloorWingInMembers(hallId: String, floor: Int, wing: String?) {
        #if DEBUG
        print("🏠 BATCH-ASSIGNED-FALLBACK: Finding RA in members by floor: \(floor), wing: \(wing ?? "any")")
        #endif

        // Query members for RAs on this floor
        // Note: If no RAs are found with exact floor match, we'll try a broader search
        let query = db.collection("halls")
            .document(hallId)
            .collection("members")
            .whereField("role", isEqualTo: "ra")

        query.getDocuments { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("🏠 BATCH-ASSIGNED-FALLBACK: Members query error - \(error.localizedDescription)")
                #endif
                self.isLoadingAssignedRA = false
                self.assignedRALoaded = true
                self.updateResidentLoadingState()
                return
            }

            guard let documents = snapshot?.documents, !documents.isEmpty else {
                #if DEBUG
                print("🏠 BATCH-ASSIGNED-FALLBACK: No RAs found in members collection")
                #endif
                self.isLoadingAssignedRA = false
                self.assignedRALoaded = true
                self.updateResidentLoadingState()
                return
            }

            #if DEBUG
            print("🏠 BATCH-ASSIGNED-FALLBACK: Found \(documents.count) RAs in members collection")
            for doc in documents {
                let d = doc.data()
                print("🏠 BATCH-ASSIGNED-FALLBACK: RA - id: \(doc.documentID), name: \(d["displayName"] ?? d["name"] ?? "?"), floor: \(d["floor"] ?? "nil"), wing: \(d["wing"] ?? "nil")")
            }
            #endif

            // Priority 1: Find RA matching both floor AND wing
            var matchedDoc: QueryDocumentSnapshot?
            for doc in documents {
                let data = doc.data()
                let raFloor = data["floor"] as? Int
                let raWing = data["wing"] as? String

                if raFloor == floor {
                    if let wing = wing, !wing.isEmpty, let raWing = raWing {
                        if raWing.lowercased() == wing.lowercased() {
                            matchedDoc = doc
                            #if DEBUG
                            print("🏠 BATCH-ASSIGNED-FALLBACK: Matched RA by floor+wing: \(data["displayName"] ?? data["name"] ?? "?")")
                            #endif
                            break
                        }
                    } else {
                        // Floor match but no wing requirement
                        matchedDoc = doc
                        #if DEBUG
                        print("🏠 BATCH-ASSIGNED-FALLBACK: Matched RA by floor only: \(data["displayName"] ?? data["name"] ?? "?")")
                        #endif
                        break
                    }
                }
            }

            // Priority 2: If no floor match, use any RA (first in list)
            if matchedDoc == nil {
                matchedDoc = documents.first
                #if DEBUG
                print("🏠 BATCH-ASSIGNED-FALLBACK: No floor match, using first RA")
                #endif
            }

            guard let doc = matchedDoc else {
                self.isLoadingAssignedRA = false
                self.assignedRALoaded = true
                self.updateResidentLoadingState()
                return
            }

            let data = doc.data()
            let memberDisplayName = data["displayName"] as? String ?? data["name"] as? String
            // Try uid field first, then document ID as fallback
            let raUid = data["uid"] as? String ?? data["userId"] as? String ?? doc.documentID
            let memberRoom = data["room"] as? String ?? data["roomNumber"] as? String
            let memberEmail = data["email"] as? String
            let memberFloor = data["floor"] as? Int
            let memberWing = data["wing"] as? String

            #if DEBUG
            print("🏠 BATCH-ASSIGNED-FALLBACK: RA data - docId: \(doc.documentID), uid: \(raUid), name: \(memberDisplayName ?? "nil"), room: \(memberRoom ?? "nil")")
            #endif

            // If member doc has displayName, use it directly
            if let name = memberDisplayName, !name.isEmpty, name != "RA" {
                self.assignedRA = AssignedRA(
                    odRAuid: raUid,
                    displayName: name,
                    room: memberRoom,
                    email: memberEmail,
                    floor: memberFloor,
                    wing: memberWing
                )
                self.isLoadingAssignedRA = false
                self.assignedRALoaded = true
                self.updateResidentLoadingState()

                #if DEBUG
                print("🏠 BATCH-ASSIGNED-FALLBACK: Assigned RA from member: \(name)")
                #endif
            } else {
                // Member doc doesn't have displayName, fetch from profiles collection (readable by hall members)
                #if DEBUG
                print("🏠 BATCH-ASSIGNED-FALLBACK: No displayName in member doc, fetching from profiles/\(raUid)")
                #endif

                self.db.collection("halls").document(hallId).collection("profiles").document(raUid).getDocument { [weak self] profileSnapshot, error in
                    guard let self = self else { return }

                    if let error = error {
                        #if DEBUG
                        print("🏠 BATCH-ASSIGNED-FALLBACK: Error fetching profile \(raUid): \(error.localizedDescription)")
                        #endif
                    }

                    var finalName = "RA"
                    if let profileData = profileSnapshot?.data() {
                        let profileName = profileData["displayName"] as? String ?? profileData["name"] as? String ?? ""
                        if !profileName.isEmpty {
                            finalName = profileName
                            #if DEBUG
                            print("🏠 BATCH-ASSIGNED-FALLBACK: Found name in profiles: \(finalName)")
                            #endif
                        } else {
                            #if DEBUG
                            print("🏠 BATCH-ASSIGNED-FALLBACK: Profile exists but displayName is empty")
                            #endif
                            // Check if on-duty RA is the same person - use their name
                            if let onDuty = self.onDutyRA, onDuty.odRAuid == raUid {
                                finalName = onDuty.displayName
                                #if DEBUG
                                print("🏠 BATCH-ASSIGNED-FALLBACK: Using on-duty RA name: \(finalName)")
                                #endif
                            }
                        }
                    } else {
                        #if DEBUG
                        print("🏠 BATCH-ASSIGNED-FALLBACK: No profile doc found at profiles/\(raUid)")
                        #endif
                        // Check if on-duty RA is the same person - use their name
                        if let onDuty = self.onDutyRA, onDuty.odRAuid == raUid {
                            finalName = onDuty.displayName
                            #if DEBUG
                            print("🏠 BATCH-ASSIGNED-FALLBACK: Using on-duty RA name: \(finalName)")
                            #endif
                        }
                    }

                    // If still no name, try to find from shifts collection
                    if finalName == "RA" {
                        self.findRANameFromShifts(hallId: hallId, raUid: raUid, memberRoom: memberRoom, memberEmail: memberEmail, memberFloor: memberFloor, memberWing: memberWing)
                        return
                    }

                    self.assignedRA = AssignedRA(
                        odRAuid: raUid,
                        displayName: finalName,
                        room: memberRoom,
                        email: memberEmail,
                        floor: memberFloor,
                        wing: memberWing
                    )
                    self.isLoadingAssignedRA = false
                    self.assignedRALoaded = true
                    self.updateResidentLoadingState()

                    #if DEBUG
                    print("🏠 BATCH-ASSIGNED-FALLBACK: Assigned RA: \(finalName)")
                    #endif
                }
            }
        }
    }

    /// Last resort: Find RA name from shifts collection
    private func findRANameFromShifts(hallId: String, raUid: String, memberRoom: String?, memberEmail: String?, memberFloor: Int?, memberWing: String?) {
        #if DEBUG
        print("🏠 BATCH-ASSIGNED-SHIFTS: Looking for RA name in shifts for uid: \(raUid)")
        #endif

        // Query shifts collection for any shift by this RA
        db.collection("halls")
            .document(hallId)
            .collection("shifts")
            .whereField("uid", isEqualTo: raUid)
            .limit(to: 1)
            .getDocuments { [weak self] snapshot, error in
                guard let self = self else { return }

                var finalName = "Your RA"
                if let doc = snapshot?.documents.first {
                    let data = doc.data()
                    if let name = data["displayName"] as? String ?? data["raName"] as? String ?? data["name"] as? String, !name.isEmpty {
                        finalName = name
                        #if DEBUG
                        print("🏠 BATCH-ASSIGNED-SHIFTS: Found name in shifts: \(finalName)")
                        #endif
                    }
                } else {
                    #if DEBUG
                    print("🏠 BATCH-ASSIGNED-SHIFTS: No shifts found for this RA, using default name")
                    #endif
                }

                self.assignedRA = AssignedRA(
                    odRAuid: raUid,
                    displayName: finalName,
                    room: memberRoom,
                    email: memberEmail,
                    floor: memberFloor,
                    wing: memberWing
                )
                self.isLoadingAssignedRA = false
                self.assignedRALoaded = true
                self.updateResidentLoadingState()

                #if DEBUG
                print("🏠 BATCH-ASSIGNED-SHIFTS: Assigned RA: \(finalName)")
                #endif
            }
    }

    /// Load upcoming events with real-time listener
    private func loadUpcomingEvents(hallId: String) {
        eventsListener?.remove()
        eventsLoaded = false
        isLoadingEvents = true

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
                print("🏠 BATCH-EVENTS: Error - \(error.localizedDescription)")
                #endif
                self.upcomingEvents = []
                self.eventsLoaded = true
                self.updateResidentLoadingState()
                return
            }

            guard let documents = snapshot?.documents else {
                self.upcomingEvents = []
                self.eventsLoaded = true
                self.updateResidentLoadingState()
                return
            }

            self.upcomingEvents = documents.compactMap { doc -> HallEvent? in
                let data = doc.data()
                guard let title = data["title"] as? String,
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

            self.eventsLoaded = true
            self.updateResidentLoadingState()

            #if DEBUG
            print("🏠 BATCH-EVENTS: Loaded \(self.upcomingEvents.count) upcoming events")
            #endif
        }
    }

    /// Update overall loading state for resident data
    private func updateResidentLoadingState() {
        // Done loading when all resident data is loaded
        if onDutyRALoaded && assignedRALoaded && eventsLoaded {
            isLoadingResidentData = false
            #if DEBUG
            print("🏠 BATCH-RESIDENT: All resident data loaded - onDutyRA: \(onDutyRA?.displayName ?? "none"), assignedRA: \(assignedRA?.displayName ?? "none"), events: \(upcomingEvents.count)")
            #endif
        }
    }

    /// Manually refresh resident data (for pull-to-refresh)
    func refreshResidentData() {
        guard let hallId = currentUser?.hallId, !hallId.isEmpty,
              let user = currentUser, user.role != "ra" else {
            return
        }
        loadResidentDataInParallel(hallId: hallId, user: user)
    }

    // MARK: - Staff Profile Fetch

    /// Fetch the staff profile for the current user (for RA floor/wing assignment)
    /// Staff profiles are stored at /halls/{hallId}/staff/{uid}
    func fetchStaffProfile() async throws -> StaffProfile? {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw UserManagerError.notAuthenticated
        }

        guard let hallId = currentUser?.hallId, !hallId.isEmpty else {
            throw UserManagerError.noHallAssigned
        }

        let staffRef = db.collection("halls").document(hallId).collection("staff").document(uid)
        let snapshot = try await staffRef.getDocument()

        guard snapshot.exists, let data = snapshot.data() else {
            #if DEBUG
            print("👤 USER: No staff profile found for \(uid) in hall \(hallId)")
            #endif
            return nil
        }

        let profile = StaffProfile(
            uid: uid,
            hallId: hallId,
            floor: data["floor"] as? Int,
            wing: data["wing"] as? String,
            role: data["role"] as? String ?? "ra",
            isActive: data["isActive"] as? Bool ?? true
        )

        #if DEBUG
        print("👤 USER: Staff profile loaded - floor: \(profile.floor ?? -1), wing: \(profile.wing ?? "none")")
        #endif

        return profile
    }
}

// MARK: - Staff Profile Model

struct StaffProfile: Codable, Equatable {
    let uid: String
    let hallId: String
    var floor: Int?
    var wing: String?
    var role: String
    var isActive: Bool
}

// MARK: - Hall Director Model

struct HallDirector: Codable, Equatable {
    var uid: String?
    var name: String
    var email: String?
    var phone: String?
}

// MARK: - Hall Model

struct Hall: Codable, Equatable {
    let hallId: String
    var name: String
    var shortName: String?
    var address: String?
    var floors: [Int]?
    var wings: [String]?
    var hallDirector: HallDirector?
    var isActive: Bool
}

// MARK: - On-Duty RA Model

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

// MARK: - Assigned RA Model

struct AssignedRA: Equatable {
    let odRAuid: String
    let displayName: String
    let room: String?
    let email: String?
    let floor: Int?
    let wing: String?
}

// MARK: - Hall Event Model

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

// MARK: - Errors

enum UserManagerError: LocalizedError {
    case notAuthenticated
    case noHallAssigned
    case profileNotFound

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User is not authenticated"
        case .noHallAssigned:
            return "User has no hall assigned"
        case .profileNotFound:
            return "User profile not found"
        }
    }
}
