import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Firebase service for Resident Living features
/// Provides: Maintenance Requests, Move-Out Checklist, Announcements, Floor Rules, FAQs
@MainActor
final class ResidentLivingService: ObservableObject {

    // MARK: - Singleton

    static let shared = ResidentLivingService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    // Maintenance Requests
    @Published private(set) var maintenanceRequests: [MaintenanceRequest] = []
    @Published private(set) var isLoadingMaintenance = false
    @Published private(set) var isSubmittingMaintenance = false

    // Move-Out Checklist
    @Published private(set) var moveOutChecklist: MoveOutChecklist?
    @Published private(set) var isLoadingMoveOut = false

    // Announcements
    @Published private(set) var announcements: [Announcement] = []
    @Published private(set) var isLoadingAnnouncements = false

    // Floor Rules
    @Published private(set) var floorRules: [FloorRule] = []
    @Published private(set) var isLoadingRules = false

    // FAQs
    @Published private(set) var faqs: [FAQ] = []
    @Published private(set) var isLoadingFAQs = false

    private var maintenanceListener: Any?
    private var announcementsListener: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    #if canImport(FirebaseFunctions)
    private lazy var functions = Functions.functions()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Models

    struct MaintenanceRequest: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let category: Category
        let urgency: Urgency
        let location: String
        let roomNumber: String
        let status: Status
        let createdAt: Date
        let updatedAt: Date
        let resolvedAt: Date?
        let notes: String?

        enum Category: String, CaseIterable {
            case plumbing = "plumbing"
            case electrical = "electrical"
            case hvac = "hvac"
            case furniture = "furniture"
            case appliance = "appliance"
            case pest = "pest"
            case locksmith = "locksmith"
            case other = "other"

            var displayName: String {
                switch self {
                case .plumbing: return "Plumbing"
                case .electrical: return "Electrical"
                case .hvac: return "Heating/Cooling"
                case .furniture: return "Furniture"
                case .appliance: return "Appliance"
                case .pest: return "Pest Control"
                case .locksmith: return "Lock/Key"
                case .other: return "Other"
                }
            }

            var icon: String {
                switch self {
                case .plumbing: return "drop.fill"
                case .electrical: return "bolt.fill"
                case .hvac: return "thermometer"
                case .furniture: return "chair.fill"
                case .appliance: return "washer.fill"
                case .pest: return "ant.fill"
                case .locksmith: return "key.fill"
                case .other: return "wrench.fill"
                }
            }
        }

        enum Urgency: String, CaseIterable {
            case low = "low"
            case medium = "medium"
            case high = "high"
            case emergency = "emergency"

            var displayName: String {
                switch self {
                case .low: return "Low"
                case .medium: return "Medium"
                case .high: return "High"
                case .emergency: return "Emergency"
                }
            }

            var color: String {
                switch self {
                case .low: return "gray"
                case .medium: return "yellow"
                case .high: return "orange"
                case .emergency: return "red"
                }
            }
        }

        enum Status: String {
            case pending = "pending"
            case inProgress = "in_progress"
            case completed = "completed"
            case cancelled = "cancelled"

            var displayName: String {
                switch self {
                case .pending: return "Pending"
                case .inProgress: return "In Progress"
                case .completed: return "Completed"
                case .cancelled: return "Cancelled"
                }
            }

            var color: String {
                switch self {
                case .pending: return "yellow"
                case .inProgress: return "blue"
                case .completed: return "green"
                case .cancelled: return "gray"
                }
            }
        }

        var statusText: String {
            switch status {
            case .pending:
                return "Awaiting review"
            case .inProgress:
                return "Being worked on"
            case .completed:
                if let resolved = resolvedAt {
                    return "Resolved \(resolved.formatted(date: .abbreviated, time: .omitted))"
                }
                return "Completed"
            case .cancelled:
                return "Cancelled"
            }
        }
    }

    struct MoveOutChecklist: Identifiable, Equatable {
        let id: String
        let roomNumber: String
        let moveOutDate: Date?
        let items: [ChecklistItem]
        let notes: String?
        let isComplete: Bool
        let completedAt: Date?

        var completedCount: Int {
            items.filter { $0.isChecked }.count
        }

        var totalCount: Int {
            items.count
        }

        var progressPercentage: Double {
            guard totalCount > 0 else { return 0 }
            return Double(completedCount) / Double(totalCount)
        }

        struct ChecklistItem: Identifiable, Equatable {
            let id: String
            let name: String
            let description: String?
            let isChecked: Bool
        }
    }

    struct Announcement: Identifiable, Equatable {
        let id: String
        let title: String
        let body: String
        let category: Category
        let isPinned: Bool
        let createdAt: Date
        let expiresAt: Date?
        let createdBy: String

        enum Category: String {
            case general = "general"
            case safety = "safety"
            case event = "event"
            case maintenance = "maintenance"
            case policy = "policy"

            var icon: String {
                switch self {
                case .general: return "megaphone.fill"
                case .safety: return "exclamationmark.triangle.fill"
                case .event: return "calendar"
                case .maintenance: return "wrench.fill"
                case .policy: return "doc.text.fill"
                }
            }

            var color: String {
                switch self {
                case .general: return "blue"
                case .safety: return "red"
                case .event: return "purple"
                case .maintenance: return "orange"
                case .policy: return "gray"
                }
            }
        }

        var isExpired: Bool {
            if let expires = expiresAt {
                return Date() > expires
            }
            return false
        }
    }

    struct FloorRule: Identifiable, Equatable {
        let id: String
        let title: String
        let description: String
        let category: String
        let order: Int
    }

    struct FAQ: Identifiable, Equatable {
        let id: String
        let question: String
        let answer: String
        let category: String
        let order: Int
    }

    // MARK: - Maintenance Requests

    /// Start listening to user's maintenance requests
    func startListeningForMaintenanceRequests(hallId: String) {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else { return }

        stopListeningForMaintenanceRequests()
        isLoadingMaintenance = true

        #if DEBUG
        print("🏠 LIVING: Starting maintenance requests listener")
        #endif

        let query = db.collection("halls")
            .document(hallId)
            .collection("maintenance_requests")
            .whereField("requestedBy", isEqualTo: uid)
            .order(by: "createdAt", descending: true)

        maintenanceListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingMaintenance = false

            if let error = error {
                #if DEBUG
                print("🏠 LIVING: Maintenance listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.maintenanceRequests = []
                return
            }

            self.maintenanceRequests = documents.compactMap { doc -> MaintenanceRequest? in
                self.parseMaintenanceRequest(doc)
            }

            #if DEBUG
            print("🏠 LIVING: Loaded \(self.maintenanceRequests.count) maintenance requests")
            #endif
        }
        #endif
    }

    func stopListeningForMaintenanceRequests() {
        #if canImport(FirebaseFirestore)
        if let listener = maintenanceListener as? ListenerRegistration {
            listener.remove()
            maintenanceListener = nil
        }
        #endif
    }

    /// Submit a new maintenance request
    func submitMaintenanceRequest(
        hallId: String,
        title: String,
        description: String,
        category: MaintenanceRequest.Category,
        urgency: MaintenanceRequest.Urgency,
        location: String,
        allowEntry: Bool = false
    ) async throws -> String {
        #if canImport(FirebaseFunctions)
        guard Auth.auth().currentUser?.uid != nil else {
            throw ResidentLivingError.notAuthenticated
        }

        isSubmittingMaintenance = true
        defer { isSubmittingMaintenance = false }

        #if DEBUG
        print("🏠 LIVING: Submitting maintenance request: \(title)")
        #endif

        let params: [String: Any] = [
            "hallId": hallId,
            "title": title,
            "description": description,
            "category": category.rawValue,
            "urgency": urgency.rawValue,
            "location": location,
            "allowEntry": allowEntry
        ]

        let result = try await functions.httpsCallable("submitMaintenanceRequest").call(params)

        guard let data = result.data as? [String: Any],
              let requestId = data["requestId"] as? String else {
            throw ResidentLivingError.invalidResponse
        }

        #if DEBUG
        print("🏠 LIVING: Maintenance request submitted: \(requestId)")
        #endif

        return requestId
        #else
        throw ResidentLivingError.notConfigured
        #endif
    }

    // MARK: - Move-Out Checklist

    /// Load the resident's move-out checklist
    func loadMoveOutChecklist(hallId: String, roomNumber: String) async {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else { return }

        isLoadingMoveOut = true
        defer { isLoadingMoveOut = false }

        #if DEBUG
        print("🏠 LIVING: Loading move-out checklist for room \(roomNumber)")
        #endif

        do {
            let snapshot = try await db.collection("halls")
                .document(hallId)
                .collection("move_out_checklists")
                .whereField("residentId", isEqualTo: uid)
                .limit(to: 1)
                .getDocuments()

            guard let doc = snapshot.documents.first else {
                #if DEBUG
                print("🏠 LIVING: No move-out checklist found")
                #endif
                moveOutChecklist = nil
                return
            }

            moveOutChecklist = parseMoveOutChecklist(doc)

            #if DEBUG
            if let checklist = moveOutChecklist {
                print("🏠 LIVING: Move-out checklist loaded: \(checklist.completedCount)/\(checklist.totalCount)")
            }
            #endif
        } catch {
            #if DEBUG
            print("🏠 LIVING: Error loading move-out checklist: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
        }
        #endif
    }

    /// Toggle a move-out checklist item
    func toggleMoveOutItem(hallId: String, checklistId: String, itemId: String, isChecked: Bool) async throws {
        #if canImport(FirebaseFirestore)
        let checklistRef = db.collection("halls")
            .document(hallId)
            .collection("move_out_checklists")
            .document(checklistId)

        let snapshot = try await checklistRef.getDocument()
        guard snapshot.exists, var data = snapshot.data() else {
            throw ResidentLivingError.notFound
        }

        if var items = data["items"] as? [[String: Any]] {
            if let index = items.firstIndex(where: { ($0["id"] as? String) == itemId }) {
                items[index]["isChecked"] = isChecked

                try await checklistRef.updateData([
                    "items": items,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

                #if DEBUG
                print("🏠 LIVING: Toggled move-out item \(itemId) to \(isChecked)")
                #endif

                // Reload checklist
                if let roomNumber = moveOutChecklist?.roomNumber {
                    await loadMoveOutChecklist(hallId: hallId, roomNumber: roomNumber)
                }
            }
        }
        #else
        throw ResidentLivingError.notConfigured
        #endif
    }

    // MARK: - Announcements

    /// Start listening to hall announcements
    func startListeningForAnnouncements(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListeningForAnnouncements()
        isLoadingAnnouncements = true

        #if DEBUG
        print("🏠 LIVING: Starting announcements listener")
        #endif

        // Get non-expired announcements, pinned first, then by date
        let query = db.collection("halls")
            .document(hallId)
            .collection("announcements")
            .order(by: "isPinned", descending: true)
            .order(by: "createdAt", descending: true)
            .limit(to: 20)

        announcementsListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoadingAnnouncements = false

            if let error = error {
                #if DEBUG
                print("🏠 LIVING: Announcements listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.announcements = []
                return
            }

            self.announcements = documents.compactMap { doc -> Announcement? in
                self.parseAnnouncement(doc)
            }.filter { !$0.isExpired }

            #if DEBUG
            print("🏠 LIVING: Loaded \(self.announcements.count) announcements")
            #endif
        }
        #endif
    }

    func stopListeningForAnnouncements() {
        #if canImport(FirebaseFirestore)
        if let listener = announcementsListener as? ListenerRegistration {
            listener.remove()
            announcementsListener = nil
        }
        #endif
    }

    // MARK: - Floor Rules

    /// Load floor rules for the hall
    func loadFloorRules(hallId: String) async {
        #if canImport(FirebaseFirestore)
        isLoadingRules = true
        defer { isLoadingRules = false }

        #if DEBUG
        print("🏠 LIVING: Loading floor rules")
        #endif

        do {
            let snapshot = try await db.collection("halls")
                .document(hallId)
                .collection("floor_rules")
                .order(by: "order", descending: false)
                .getDocuments()

            floorRules = snapshot.documents.compactMap { doc -> FloorRule? in
                parseFloorRule(doc)
            }

            #if DEBUG
            print("🏠 LIVING: Loaded \(floorRules.count) floor rules")
            #endif
        } catch {
            #if DEBUG
            print("🏠 LIVING: Error loading floor rules: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
        }
        #endif
    }

    // MARK: - FAQs

    /// Load FAQs for the hall
    func loadFAQs(hallId: String) async {
        #if canImport(FirebaseFirestore)
        isLoadingFAQs = true
        defer { isLoadingFAQs = false }

        #if DEBUG
        print("🏠 LIVING: Loading FAQs")
        #endif

        do {
            let snapshot = try await db.collection("halls")
                .document(hallId)
                .collection("faqs")
                .order(by: "order", descending: false)
                .getDocuments()

            faqs = snapshot.documents.compactMap { doc -> FAQ? in
                parseFAQ(doc)
            }

            #if DEBUG
            print("🏠 LIVING: Loaded \(faqs.count) FAQs")
            #endif
        } catch {
            #if DEBUG
            print("🏠 LIVING: Error loading FAQs: \(error.localizedDescription)")
            #endif
            self.error = error.localizedDescription
        }
        #endif
    }

    // MARK: - Stop All Listeners

    func stopAllListeners() {
        stopListeningForMaintenanceRequests()
        stopListeningForAnnouncements()
    }

    // MARK: - Computed Properties

    var pendingRequests: [MaintenanceRequest] {
        maintenanceRequests.filter { $0.status == .pending || $0.status == .inProgress }
    }

    var completedRequests: [MaintenanceRequest] {
        maintenanceRequests.filter { $0.status == .completed || $0.status == .cancelled }
    }

    var maintenanceStatusText: String {
        let pending = pendingRequests.count
        if pending == 0 {
            return "No active requests"
        }
        return "\(pending) active request\(pending == 1 ? "" : "s")"
    }

    var pinnedAnnouncements: [Announcement] {
        announcements.filter { $0.isPinned }
    }

    var recentAnnouncements: [Announcement] {
        announcements.filter { !$0.isPinned }
    }

    // MARK: - Parsing Helpers

    #if canImport(FirebaseFirestore)
    private func parseMaintenanceRequest(_ doc: DocumentSnapshot) -> MaintenanceRequest? {
        guard let data = doc.data(),
              let title = data["title"] as? String,
              let description = data["description"] as? String,
              let categoryRaw = data["category"] as? String,
              let urgencyRaw = data["urgency"] as? String,
              let location = data["location"] as? String,
              let roomNumber = data["roomNumber"] as? String,
              let statusRaw = data["status"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        return MaintenanceRequest(
            id: doc.documentID,
            title: title,
            description: description,
            category: MaintenanceRequest.Category(rawValue: categoryRaw) ?? .other,
            urgency: MaintenanceRequest.Urgency(rawValue: urgencyRaw) ?? .medium,
            location: location,
            roomNumber: roomNumber,
            status: MaintenanceRequest.Status(rawValue: statusRaw) ?? .pending,
            createdAt: createdAt,
            updatedAt: updatedAt,
            resolvedAt: (data["resolvedAt"] as? Timestamp)?.dateValue(),
            notes: data["notes"] as? String
        )
    }

    private func parseMoveOutChecklist(_ doc: DocumentSnapshot) -> MoveOutChecklist? {
        guard let data = doc.data(),
              let roomNumber = data["roomNumber"] as? String else {
            return nil
        }

        let itemsData = data["items"] as? [[String: Any]] ?? []
        let items = itemsData.compactMap { item -> MoveOutChecklist.ChecklistItem? in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String else {
                return nil
            }
            return MoveOutChecklist.ChecklistItem(
                id: id,
                name: name,
                description: item["description"] as? String,
                isChecked: item["isChecked"] as? Bool ?? false
            )
        }

        return MoveOutChecklist(
            id: doc.documentID,
            roomNumber: roomNumber,
            moveOutDate: (data["moveOutDate"] as? Timestamp)?.dateValue(),
            items: items,
            notes: data["notes"] as? String,
            isComplete: data["isComplete"] as? Bool ?? false,
            completedAt: (data["completedAt"] as? Timestamp)?.dateValue()
        )
    }

    private func parseAnnouncement(_ doc: DocumentSnapshot) -> Announcement? {
        guard let data = doc.data(),
              let title = data["title"] as? String,
              let body = data["body"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let createdBy = data["createdBy"] as? String else {
            return nil
        }

        return Announcement(
            id: doc.documentID,
            title: title,
            body: body,
            category: Announcement.Category(rawValue: data["category"] as? String ?? "general") ?? .general,
            isPinned: data["isPinned"] as? Bool ?? false,
            createdAt: createdAt,
            expiresAt: (data["expiresAt"] as? Timestamp)?.dateValue(),
            createdBy: createdBy
        )
    }

    private func parseFloorRule(_ doc: DocumentSnapshot) -> FloorRule? {
        guard let data = doc.data(),
              let title = data["title"] as? String,
              let description = data["description"] as? String else {
            return nil
        }

        return FloorRule(
            id: doc.documentID,
            title: title,
            description: description,
            category: data["category"] as? String ?? "General",
            order: data["order"] as? Int ?? 0
        )
    }

    private func parseFAQ(_ doc: DocumentSnapshot) -> FAQ? {
        guard let data = doc.data(),
              let question = data["question"] as? String,
              let answer = data["answer"] as? String else {
            return nil
        }

        return FAQ(
            id: doc.documentID,
            question: question,
            answer: answer,
            category: data["category"] as? String ?? "General",
            order: data["order"] as? Int ?? 0
        )
    }
    #endif

    // MARK: - Default Move-Out Checklist Items

    static func defaultMoveOutItems() -> [[String: Any]] {
        [
            ["id": UUID().uuidString, "name": "Remove all personal belongings", "description": "Take all your items from closets, drawers, and common areas", "isChecked": false],
            ["id": UUID().uuidString, "name": "Clean room thoroughly", "description": "Vacuum, dust, and wipe down all surfaces", "isChecked": false],
            ["id": UUID().uuidString, "name": "Clean bathroom", "description": "Scrub toilet, sink, shower, and mirror", "isChecked": false],
            ["id": UUID().uuidString, "name": "Empty and clean refrigerator", "description": "Remove all food and wipe down interior", "isChecked": false],
            ["id": UUID().uuidString, "name": "Take out trash", "description": "Empty all trash cans and recycling", "isChecked": false],
            ["id": UUID().uuidString, "name": "Return room key", "description": "Turn in your room key to the front desk", "isChecked": false],
            ["id": UUID().uuidString, "name": "Complete forwarding address form", "description": "Submit mail forwarding information", "isChecked": false],
            ["id": UUID().uuidString, "name": "Schedule room inspection", "description": "Contact your RA to schedule final inspection", "isChecked": false],
            ["id": UUID().uuidString, "name": "Settle any outstanding charges", "description": "Pay any fees or fines on your account", "isChecked": false],
            ["id": UUID().uuidString, "name": "Return any borrowed items", "description": "Return equipment, books, or supplies", "isChecked": false]
        ]
    }
}

// MARK: - Errors

enum ResidentLivingError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case notFound
    case invalidResponse
    case functionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Living service is not configured"
        case .notAuthenticated:
            return "Please sign in first"
        case .notFound:
            return "Item not found"
        case .invalidResponse:
            return "Invalid response from server"
        case .functionFailed(let message):
            return message
        }
    }
}
