import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Hall Resident Model (Firebase)

struct HallResident: Identifiable, Codable, Equatable {
    @DocumentID var id: String?
    var firstName: String
    var lastName: String
    var email: String
    var roomNumber: String
    var floor: Int
    var wing: String?
    var status: String // "active" | "inactive"
    var createdAt: Date?
    var updatedAt: Date?

    var fullName: String {
        "\(firstName) \(lastName)"
    }

    var initials: String {
        let first = firstName.prefix(1).uppercased()
        let last = lastName.prefix(1).uppercased()
        return "\(first)\(last)"
    }

    // Default values for initialization
    init(
        id: String? = nil,
        firstName: String = "",
        lastName: String = "",
        email: String = "",
        roomNumber: String = "",
        floor: Int = 0,
        wing: String? = nil,
        status: String = "active",
        createdAt: Date? = nil,
        updatedAt: Date? = nil
    ) {
        self.id = id
        self.firstName = firstName
        self.lastName = lastName
        self.email = email
        self.roomNumber = roomNumber
        self.floor = floor
        self.wing = wing
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

// MARK: - Resident Service

/// Service for fetching residents assigned to the current RA
/// Queries Firestore: /halls/{hallId}/residents
@MainActor
class ResidentService: ObservableObject {

    // MARK: - Singleton

    static let shared = ResidentService()

    // MARK: - Published State

    @Published var myResidents: [HallResident] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    // MARK: - Computed Properties

    var residentCount: Int {
        myResidents.count
    }

    var sortedResidents: [HallResident] {
        myResidents.sorted { $0.lastName.lowercased() < $1.lastName.lowercased() }
    }

    var activeResidents: [HallResident] {
        myResidents.filter { $0.status == "active" }
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
    func fetchMyResidents() {
        guard let uid = Auth.auth().currentUser?.uid else {
            self.errorMessage = "No active user."
            return
        }

        // Get hall ID from UserManager or default
        let hallId = UserManager.shared.hallId ?? "hall-001"

        isLoading = true
        errorMessage = nil

        #if DEBUG
        print("🏠 RESIDENTS: Fetching residents for RA \(uid) in hall \(hallId)")
        #endif

        // First, fetch the staff profile to get floor/wing assignment
        let staffRef = db.collection("halls").document(hallId).collection("staff").document(uid)

        staffRef.getDocument { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                self.isLoading = false
                self.errorMessage = "Failed to load staff profile: \(error.localizedDescription)"
                #if DEBUG
                print("🏠 RESIDENTS: Error loading staff profile - \(error.localizedDescription)")
                #endif
                return
            }

            // Get floor/wing from staff profile
            let data = snapshot?.data()
            let myFloor = data?["floor"] as? Int
            let myWing = data?["wing"] as? String

            #if DEBUG
            print("🏠 RESIDENTS: Staff profile - floor: \(myFloor ?? -1), wing: \(myWing ?? "none")")
            #endif

            // Build query for residents
            self.buildAndExecuteQuery(hallId: hallId, floor: myFloor, wing: myWing)
        }
    }

    private func buildAndExecuteQuery(hallId: String, floor: Int?, wing: String?) {
        // Start with base query
        var query: Query = db.collection("halls").document(hallId).collection("residents")
            .whereField("status", isEqualTo: "active")

        // Apply floor filter if assigned
        if let floor = floor {
            query = query.whereField("floor", isEqualTo: floor)
            #if DEBUG
            print("🏠 RESIDENTS: Filtering by floor \(floor)")
            #endif
        }

        // Apply wing filter if assigned
        if let wing = wing, !wing.isEmpty {
            query = query.whereField("wing", isEqualTo: wing)
            #if DEBUG
            print("🏠 RESIDENTS: Filtering by wing \(wing)")
            #endif
        }

        // Attach real-time listener
        listener = query.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }

            self.isLoading = false

            if let error = error {
                self.errorMessage = "Error loading residents: \(error.localizedDescription)"
                #if DEBUG
                print("🏠 RESIDENTS: Query error - \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = querySnapshot?.documents else {
                self.myResidents = []
                self.errorMessage = "No residents found."
                return
            }

            self.myResidents = documents.compactMap { doc -> HallResident? in
                do {
                    return try doc.data(as: HallResident.self)
                } catch {
                    #if DEBUG
                    print("🏠 RESIDENTS: Failed to decode resident \(doc.documentID) - \(error)")
                    #endif
                    return nil
                }
            }

            if self.myResidents.isEmpty {
                self.errorMessage = "No residents assigned to your section yet."
            } else {
                self.errorMessage = nil
            }

            #if DEBUG
            print("🏠 RESIDENTS: Loaded \(self.myResidents.count) residents")
            #endif
        }
    }

    // MARK: - Fetch All Residents (Admin/CD)

    /// Fetches all residents in the hall (for admins or CDs without floor assignment)
    func fetchAllResidents(hallId: String = "hall-001") {
        isLoading = true
        errorMessage = nil

        let query = db.collection("halls").document(hallId).collection("residents")
            .whereField("status", isEqualTo: "active")

        listener = query.addSnapshotListener { [weak self] querySnapshot, error in
            guard let self = self else { return }

            self.isLoading = false

            if let error = error {
                self.errorMessage = "Error loading residents: \(error.localizedDescription)"
                return
            }

            guard let documents = querySnapshot?.documents else {
                self.myResidents = []
                return
            }

            self.myResidents = documents.compactMap { doc -> HallResident? in
                try? doc.data(as: HallResident.self)
            }

            #if DEBUG
            print("🏠 RESIDENTS: Loaded all \(self.myResidents.count) residents in hall")
            #endif
        }
    }

    // MARK: - Search

    /// Search residents by name or room number
    func search(_ query: String) -> [HallResident] {
        let lowercasedQuery = query.lowercased()
        return sortedResidents.filter { resident in
            resident.firstName.lowercased().contains(lowercasedQuery) ||
            resident.lastName.lowercased().contains(lowercasedQuery) ||
            resident.fullName.lowercased().contains(lowercasedQuery) ||
            resident.roomNumber.lowercased().contains(lowercasedQuery) ||
            resident.email.lowercased().contains(lowercasedQuery)
        }
    }

    // MARK: - Stop Listening

    func stopListening() {
        listener?.remove()
        listener = nil
    }

    // MARK: - Clear Data

    func clearData() {
        stopListening()
        myResidents = []
        errorMessage = nil
    }
}
