import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Hall Resident Model (Firebase)

/// Resident data from /halls/{hallId}/profiles where role == "resident"
/// Combined with membership data from /halls/{hallId}/members
struct HallResident: Identifiable, Equatable {
    var id: String // Document ID (userId)
    var displayName: String
    var email: String
    var roomNumber: String
    var floor: Int
    var wing: String?
    var role: String

    var fullName: String {
        displayName
    }

    // Parse name into first/last for initials
    var firstName: String {
        displayName.components(separatedBy: " ").first ?? displayName
    }

    var lastName: String {
        let parts = displayName.components(separatedBy: " ")
        return parts.count > 1 ? parts.dropFirst().joined(separator: " ") : ""
    }

    var initials: String {
        let parts = displayName.components(separatedBy: " ")
        let first = parts.first?.prefix(1).uppercased() ?? ""
        let last = parts.count > 1 ? (parts.last?.prefix(1).uppercased() ?? "") : ""
        return "\(first)\(last)"
    }

    init(
        id: String,
        displayName: String = "",
        email: String = "",
        roomNumber: String = "",
        floor: Int = 0,
        wing: String? = nil,
        role: String = "resident"
    ) {
        self.id = id
        self.displayName = displayName
        self.email = email
        self.roomNumber = roomNumber
        self.floor = floor
        self.wing = wing
        self.role = role
    }
}

// MARK: - Resident Service

/// Service for fetching residents assigned to the current RA
/// OPTIMIZED: Now proxies data from UserManager's centralized batch loading
/// UserManager loads residents in parallel with shifts on RA login
/// This service provides backward compatibility for views still referencing it
@MainActor
class ResidentService: ObservableObject {

    // MARK: - Singleton

    static let shared = ResidentService()

    // MARK: - Published State (proxied from UserManager)

    /// Residents are now loaded centrally by UserManager
    /// These computed properties proxy the data for backward compatibility
    var myResidents: [HallResident] {
        // If legacy local data exists, use it; otherwise use UserManager
        if !_legacyResidents.isEmpty { return _legacyResidents }
        return UserManager.shared.myResidents
    }

    var isLoading: Bool {
        if _legacyIsLoading { return true }
        return UserManager.shared.isLoadingRAData && !UserManager.shared.residentsLoaded
    }

    var errorMessage: String? {
        if _legacyErrorMessage != nil { return _legacyErrorMessage }
        return UserManager.shared.residentsError
    }

    // MARK: - Legacy State (for direct fetch methods)

    /// Used by legacy fetchMyResidentsDirectly() for backward compatibility
    @Published private var _legacyResidents: [HallResident] = []
    @Published private var _legacyIsLoading = false
    @Published private var _legacyErrorMessage: String?

    // MARK: - Cached RA Info

    private var cachedHallId: String?
    private var cachedFloor: Int?
    private var cachedWing: String?

    // MARK: - Computed Properties (proxied from UserManager)

    var residentCount: Int {
        if !_legacyResidents.isEmpty { return _legacyResidents.count }
        return UserManager.shared.residentCount
    }

    var sortedResidents: [HallResident] {
        if !_legacyResidents.isEmpty {
            return _legacyResidents.sorted { $0.lastName.lowercased() < $1.lastName.lowercased() }
        }
        return UserManager.shared.sortedResidents
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

    // MARK: - Fetch Residents

    /// Fetches residents assigned to the current RA based on their floor/wing assignment
    /// OPTIMIZED: Now triggers refresh via UserManager's centralized batch loading
    /// UserManager loads residents in parallel with shifts for better performance
    func fetchMyResidents() {
        #if DEBUG
        print("🏠 RESIDENTS: fetchMyResidents() called - delegating to UserManager.refreshRAData()")
        #endif

        // Trigger refresh via UserManager (loads shifts + residents in parallel)
        UserManager.shared.refreshRAData()
    }

    // MARK: - Legacy Fetch Methods (kept for fallback scenarios)

    /// Legacy: Fetches residents directly (bypasses UserManager)
    /// Only used if UserManager fails or for specific edge cases
    func fetchMyResidentsDirectly() {
        // Remove any existing listener first to prevent duplicates
        stopListening()

        guard let userId = Auth.auth().currentUser?.uid else {
            _legacyErrorMessage = "No active user."
            #if DEBUG
            print("🏠 RESIDENTS: No active user.")
            #endif
            return
        }

        _legacyIsLoading = true
        _legacyErrorMessage = nil
        _legacyResidents = []

        #if DEBUG
        print("🏠 RESIDENTS: Direct fetch for userId: \(userId)")
        #endif

        // Step 1: Get hallId from /users/{uid} document
        db.collection("users").document(userId).getDocument { [weak self] userSnapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    self._legacyIsLoading = false
                    self._legacyErrorMessage = "Failed to load user: \(error.localizedDescription)"
                    #if DEBUG
                    print("🏠 RESIDENTS: User doc error - \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let userData = userSnapshot?.data(),
                      let hallId = userData["hallId"] as? String,
                      !hallId.isEmpty else {
                    self._legacyIsLoading = false
                    self._legacyErrorMessage = "No hall assignment found. Please join a hall first."
                    #if DEBUG
                    print("🏠 RESIDENTS: No hallId in user document")
                    #endif
                    return
                }

                let userRole = userData["role"] as? String ?? "resident"

                #if DEBUG
                print("🏠 RESIDENTS: User hallId=\(hallId), role=\(userRole)")
                #endif

                // Step 2: Get RA's member document for floor/wing info
                self.db.collection("halls").document(hallId).collection("members").document(userId)
                    .getDocument { [weak self] memberSnapshot, error in
                        Task { @MainActor [weak self] in
                            guard let self = self else { return }

                            if let error = error {
                                self._legacyIsLoading = false
                                self._legacyErrorMessage = "Failed to load membership: \(error.localizedDescription)"
                                #if DEBUG
                                print("🏠 RESIDENTS: Member doc error - \(error.localizedDescription)")
                                #endif
                                return
                            }

                            guard let memberData = memberSnapshot?.data() else {
                                self._legacyIsLoading = false
                                self._legacyErrorMessage = "No membership found in hall."
                                #if DEBUG
                                print("🏠 RESIDENTS: No member document at /halls/\(hallId)/members/\(userId)")
                                #endif
                                return
                            }

                            let memberRole = memberData["role"] as? String ?? "resident"

                            // Verify RA role
                            guard memberRole == "ra" || userRole == "ra" else {
                                self._legacyIsLoading = false
                                self._legacyErrorMessage = "Only RAs can view residents."
                                #if DEBUG
                                print("🏠 RESIDENTS: User is not an RA (memberRole=\(memberRole), userRole=\(userRole))")
                                #endif
                                return
                            }

                            // Get floor/wing from member document
                            let myFloor = memberData["floor"] as? Int
                            let myWing = memberData["wing"] as? String

                            #if DEBUG
                            print("🏠 RESIDENTS: RA in hall \(hallId) - floor: \(myFloor ?? -1), wing: \(myWing ?? "none")")
                            #endif

                            // Cache the values
                            self.cachedHallId = hallId
                            self.cachedFloor = myFloor
                            self.cachedWing = myWing

                            // Step 3: Fetch residents - prefer by assignedRaUid, fallback to floor
                            self.fetchResidentsForRA(hallId: hallId, raUid: userId, floor: myFloor, wing: myWing)
                        }
                    }
            }
        }
    }

    /// Fetches residents assigned to this RA
    /// V1 FIX: Query from ROSTER collection (source of truth for assignments)
    /// Step 1: Get RA's floor/wing from roster (by email)
    /// Step 2: Query roster for residents matching floor/wing
    private func fetchResidentsForRA(hallId: String, raUid: String, floor: Int?, wing: String?) {
        #if DEBUG
        print("🏠 RESIDENTS: Fetching residents for RA \(raUid) in hall \(hallId)")
        #endif

        // Get RA's email to look up their roster entry
        guard let raEmail = Auth.auth().currentUser?.email?.lowercased() else {
            self._legacyIsLoading = false
            self._legacyErrorMessage = "Could not determine RA email."
            return
        }

        let rosterRef = db.collection("halls").document(hallId).collection("roster")

        // Step 1: Get RA's assignment from roster
        rosterRef.document(raEmail).getDocument { [weak self] raDoc, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("🏠 RESIDENTS: Error fetching RA roster: \(error.localizedDescription)")
                    #endif
                }

                // Get floor/wing from roster (preferred) or member doc (fallback)
                var raFloor: Int? = floor
                var raWing: String? = wing

                if let raData = raDoc?.data() {
                    // Parse floor - handle both Int and String formats
                    if let floorInt = raData["floor"] as? Int {
                        raFloor = floorInt
                    } else if let floorStr = raData["floor"] as? String, let parsed = Int(floorStr) {
                        raFloor = parsed
                    }
                    raWing = raData["wing"] as? String

                    #if DEBUG
                    print("🏠 RESIDENTS: RA roster entry - floor: \(raFloor ?? -1), wing: \(raWing ?? "none")")
                    #endif
                }

                guard let finalFloor = raFloor else {
                    self._legacyIsLoading = false
                    self._legacyResidents = []
                    self._legacyErrorMessage = "No floor assignment found. Please contact your Hall Director."
                    #if DEBUG
                    print("🏠 RESIDENTS: No floor found for RA")
                    #endif
                    return
                }

                // Step 2: Query roster for residents on this floor/wing
                self.fetchResidentsFromRoster(hallId: hallId, floor: finalFloor, wing: raWing, raEmail: raEmail)
            }
        }
    }

    /// Fetches residents from the ROSTER collection by floor/wing
    private func fetchResidentsFromRoster(hallId: String, floor: Int, wing: String?, raEmail: String) {
        let rosterRef = db.collection("halls").document(hallId).collection("roster")

        #if DEBUG
        // First, let's see ALL documents in roster to understand the data
        print("🏠 RESIDENTS: Fetching ALL roster documents to debug...")
        rosterRef.getDocuments { snapshot, error in
            if let error = error {
                print("🏠 RESIDENTS: Debug fetch error: \(error.localizedDescription)")
            } else if let docs = snapshot?.documents {
                print("🏠 RESIDENTS: Total roster documents: \(docs.count)")
                for doc in docs.prefix(10) { // Show first 10 for debugging
                    print("🏠 RESIDENTS: Roster doc \(doc.documentID): \(doc.data())")
                }
            }
        }
        #endif

        // Build query for residents on this floor
        // Floor is stored as INTEGER in roster (not string)
        var query: Query = rosterRef
            .whereField("role", isEqualTo: "resident")
            .whereField("floor", isEqualTo: floor)

        // If RA has a wing assignment, filter by it
        if let wing = wing, !wing.isEmpty {
            query = query.whereField("wing", isEqualTo: wing)
            #if DEBUG
            print("🏠 RESIDENTS: Querying roster for floor=\(floor) (Int), wing=\(wing)")
            #endif
        } else {
            #if DEBUG
            print("🏠 RESIDENTS: Querying roster for floor=\(floor) (Int) (all wings)")
            #endif
        }

        // Also try querying by assignedRaEmail for direct assignments
        // This catches residents assigned to this RA regardless of floor
        let assignedQuery = rosterRef
            .whereField("role", isEqualTo: "resident")
            .whereField("assignedRaEmail", isEqualTo: raEmail)

        // Execute both queries and merge results
        var allResidents: [HallResident] = []
        let group = DispatchGroup()

        // Query 1: By floor/wing
        group.enter()
        query.getDocuments { [weak self] snapshot, error in
            defer { group.leave() }
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENTS: Floor query error: \(error.localizedDescription)")
                #endif
                return
            }

            if let documents = snapshot?.documents {
                #if DEBUG
                print("🏠 RESIDENTS: Found \(documents.count) residents by floor")
                #endif
                let residents = self.parseRosterDocuments(documents)
                allResidents.append(contentsOf: residents)
            }
        }

        // Query 2: By assignedRaEmail (direct assignments)
        group.enter()
        assignedQuery.getDocuments { [weak self] snapshot, error in
            defer { group.leave() }
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("🏠 RESIDENTS: AssignedRaEmail query error: \(error.localizedDescription)")
                #endif
                return
            }

            if let documents = snapshot?.documents {
                #if DEBUG
                print("🏠 RESIDENTS: Found \(documents.count) residents by assignedRaEmail")
                #endif
                let residents = self.parseRosterDocuments(documents)
                allResidents.append(contentsOf: residents)
            }
        }

        // When both queries complete, dedupe and update UI
        group.notify(queue: .main) { [weak self] in
            guard let self = self else { return }

            // Deduplicate by email (roster doc ID)
            var seen = Set<String>()
            let uniqueResidents = allResidents.filter { resident in
                if seen.contains(resident.id) {
                    return false
                }
                seen.insert(resident.id)
                return true
            }

            self._legacyResidents = uniqueResidents.sorted { $0.lastName.lowercased() < $1.lastName.lowercased() }
            self._legacyIsLoading = false

            if self._legacyResidents.isEmpty {
                self._legacyErrorMessage = "No residents assigned to your section yet."
            } else {
                self._legacyErrorMessage = nil
            }

            #if DEBUG
            print("🏠 RESIDENTS: Total unique residents: \(self._legacyResidents.count)")
            #endif
        }
    }

    /// Parses roster documents into HallResident objects
    private func parseRosterDocuments(_ documents: [QueryDocumentSnapshot]) -> [HallResident] {
        return documents.compactMap { doc -> HallResident? in
            let data = doc.data()
            let email = doc.documentID // Roster doc ID is the email

            let firstName = data["firstName"] as? String ?? ""
            let lastName = data["lastName"] as? String ?? ""
            let displayName = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)

            let roomNumber = data["roomNumber"] as? String ?? ""

            // Floor is stored as Int in roster
            let floor = data["floor"] as? Int ?? 0

            let wing = data["wing"] as? String

            #if DEBUG
            print("🏠 RESIDENTS: Parsed resident - \(displayName), room: \(roomNumber), floor: \(floor), wing: \(wing ?? "none")")
            #endif

            return HallResident(
                id: email,
                displayName: displayName.isEmpty ? email : displayName,
                email: email,
                roomNumber: roomNumber,
                floor: floor,
                wing: wing,
                role: "resident"
            )
        }
    }

    /// Fetches resident members in the hall filtered by floor and optionally wing
    /// Then enriches with profile data (displayName)
    private func fetchResidentMembersInHall(hallId: String, floor: Int, wing: String?) {
        // Build query: /halls/{hallId}/members where role == "resident" AND floor == raFloor
        var query: Query = db.collection("halls").document(hallId).collection("members")
            .whereField("role", isEqualTo: "resident")
            .whereField("floor", isEqualTo: floor)

        #if DEBUG
        print("🏠 RESIDENTS: Querying hall \(hallId)/members for role=resident, floor=\(floor)")
        #endif

        // If RA is assigned to a specific wing, only show residents in that wing
        // If RA has no wing (nil), show ALL residents on that floor
        if let wing = wing, !wing.isEmpty {
            query = query.whereField("wing", isEqualTo: wing)
            #if DEBUG
            print("🏠 RESIDENTS: Also filtering by wing: \(wing)")
            #endif
        }

        // Attach real-time listener for updates
        listener = query.addSnapshotListener { [weak self] querySnapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    self._legacyIsLoading = false
                    self._legacyErrorMessage = "Error loading residents: \(error.localizedDescription)"
                    #if DEBUG
                    print("🏠 RESIDENTS: Query error - \(error.localizedDescription)")
                    #endif
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    self._legacyIsLoading = false
                    self._legacyResidents = []
                    self._legacyErrorMessage = "No residents assigned to your section yet."
                    #if DEBUG
                    print("🏠 RESIDENTS: No resident members found")
                    #endif
                    return
                }

                #if DEBUG
                print("🏠 RESIDENTS: Found \(documents.count) resident members, fetching profiles...")
                #endif

                // Step 3: Enrich with profile data
                self.enrichWithProfiles(hallId: hallId, memberDocs: documents)
            }
        }
    }

    /// Process resident documents and enrich with profiles (used by assignedRaUid query)
    private func processResidentDocuments(_ documents: [QueryDocumentSnapshot], hallId: String) {
        enrichWithProfiles(hallId: hallId, memberDocs: documents)
    }

    /// Enriches member data with profile display names
    private func enrichWithProfiles(hallId: String, memberDocs: [QueryDocumentSnapshot]) {
        let profilesRef = db.collection("halls").document(hallId).collection("profiles")

        // Fetch all profiles in one batch
        profilesRef.getDocuments { [weak self] profileSnapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                self._legacyIsLoading = false

                if let error = error {
                    #if DEBUG
                    print("🏠 RESIDENTS: Error fetching profiles - \(error.localizedDescription)")
                    #endif
                    // Continue with member data only
                }

                // Build a map of userId -> displayName from profiles
                var profileMap: [String: String] = [:]
                if let profileDocs = profileSnapshot?.documents {
                    for doc in profileDocs {
                        let data = doc.data()
                        // Profile doc ID is the userId
                        if let displayName = data["displayName"] as? String {
                            profileMap[doc.documentID] = displayName
                        }
                    }
                }

                // Build resident list from member docs + profile enrichment
                // V1 FIX: Use document ID as userId if userId field is missing
                self._legacyResidents = memberDocs.compactMap { doc -> HallResident? in
                    let data = doc.data()
                    // V1: Document ID is the userId; userId field may also exist
                    let userId = (data["userId"] as? String) ?? doc.documentID

                    let displayName = profileMap[userId] ?? profileMap[doc.documentID] ?? "Unknown Resident"
                    let roomNumber = data["roomNumber"] as? String ?? ""
                    let floor = data["floor"] as? Int ?? 0
                    let wing = data["wing"] as? String
                    let email = data["email"] as? String ?? ""

                    return HallResident(
                        id: userId,
                        displayName: displayName,
                        email: email,
                        roomNumber: roomNumber,
                        floor: floor,
                        wing: wing,
                        role: "resident"
                    )
                }

                if self._legacyResidents.isEmpty {
                    self._legacyErrorMessage = "No residents assigned to your section yet."
                } else {
                    self._legacyErrorMessage = nil
                }

                #if DEBUG
                print("🏠 RESIDENTS: Loaded \(self._legacyResidents.count) residents in hall \(hallId)")
                #endif
            }
        }
    }

    // MARK: - Fetch All Residents (Admin/CD)

    /// Fetches all residents in the hall (for admins or CDs without floor assignment)
    func fetchAllResidents(hallId: String) {
        stopListening()
        _legacyIsLoading = true
        _legacyErrorMessage = nil
        _legacyResidents = []

        // Query all members with role == "resident"
        let query = db.collection("halls").document(hallId).collection("members")
            .whereField("role", isEqualTo: "resident")

        listener = query.addSnapshotListener { [weak self] querySnapshot, error in
            Task { @MainActor [weak self] in
                guard let self = self else { return }

                if let error = error {
                    self._legacyIsLoading = false
                    self._legacyErrorMessage = "Error loading residents: \(error.localizedDescription)"
                    return
                }

                guard let documents = querySnapshot?.documents, !documents.isEmpty else {
                    self._legacyIsLoading = false
                    self._legacyResidents = []
                    return
                }

                self.enrichWithProfiles(hallId: hallId, memberDocs: documents)

                #if DEBUG
                print("🏠 RESIDENTS: Loaded all residents in hall \(hallId)")
                #endif
            }
        }
    }

    // MARK: - Search

    /// Search residents by name or room number
    /// OPTIMIZED: Delegates to UserManager's search method
    func search(_ query: String) -> [HallResident] {
        UserManager.shared.searchResidents(query)
    }

    // MARK: - Stop Listening

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Clear Data

    func clearData() {
        stopListening()
        _legacyResidents = []
        _legacyErrorMessage = nil
        cachedHallId = nil
        cachedFloor = nil
        cachedWing = nil
    }
}
