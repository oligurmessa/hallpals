import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Firebase service for Room Inspection functionality
/// Fetches inspection rounds from /halls/{hallId}/inspection_rounds/{roundId}
/// Schema matches web admin: name, templateId, templateName, dueDate, status, rooms[]
@MainActor
final class RoomCheckService: ObservableObject {

    // MARK: - Singleton

    static let shared = RoomCheckService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var error: String?
    @Published private(set) var rounds: [InspectionRound] = []

    private var listenerRegistration: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Models (matches web schema)

    struct InspectionRound: Identifiable, Equatable {
        let id: String
        let name: String
        let templateId: String
        let templateName: String
        let dueDate: Date?
        let status: RoundStatus
        var rooms: [RoomInspection]
        let createdAt: Date

        enum RoundStatus: String {
            case active = "active"
            case completed = "completed"
        }

        var completedRoomsCount: Int {
            rooms.filter { $0.status == .completed }.count
        }

        var totalRoomsCount: Int {
            rooms.count
        }

        var progressPercentage: Double {
            guard totalRoomsCount > 0 else { return 0 }
            return Double(completedRoomsCount) / Double(totalRoomsCount)
        }

        var isOverdue: Bool {
            guard let dueDate = dueDate, status == .active else { return false }
            return Date() > dueDate
        }

        var dueDateText: String? {
            guard let dueDate = dueDate else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d, yyyy"
            return formatter.string(from: dueDate)
        }
    }

    struct RoomInspection: Identifiable, Equatable {
        let id: String // Use roomNumber as id
        let roomNumber: String
        var status: RoomStatus
        var checklist: [ChecklistItem]
        var notes: String
        var completedAt: Date?
        var completedBy: String?

        enum RoomStatus: String {
            case pending = "pending"
            case completed = "completed"
        }

        var completedItemsCount: Int {
            checklist.filter { $0.isChecked }.count
        }

        var totalItemsCount: Int {
            checklist.count
        }

        var progressPercentage: Double {
            guard totalItemsCount > 0 else { return 0 }
            return Double(completedItemsCount) / Double(totalItemsCount)
        }

        var isComplete: Bool {
            status == .completed
        }
    }

    struct ChecklistItem: Identifiable, Equatable, Codable {
        let id: String
        var name: String
        var isChecked: Bool
    }

    // MARK: - Listen to Inspection Rounds

    func startListening(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListening()
        isLoading = true
        error = nil

        #if DEBUG
        print("🏠 ROOMCHECK: Starting listener for hall \(hallId)")
        #endif

        // Only fetch active rounds
        let query = db.collection("halls")
            .document(hallId)
            .collection("inspection_rounds")
            .whereField("status", isEqualTo: "active")
            .order(by: "createdAt", descending: true)

        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, err in
            guard let self = self else { return }
            self.isLoading = false

            if let err = err {
                #if DEBUG
                print("🏠 ROOMCHECK: Listener error: \(err.localizedDescription)")
                #endif
                self.error = err.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.rounds = []
                return
            }

            #if DEBUG
            print("🏠 ROOMCHECK: Received \(documents.count) active rounds")
            #endif

            self.rounds = documents.compactMap { doc -> InspectionRound? in
                self.parseRound(doc)
            }

            #if DEBUG
            print("🏠 ROOMCHECK: Parsed \(self.rounds.count) rounds successfully")
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

    // MARK: - Update Room in Round

    func updateRoomChecklist(
        hallId: String,
        roundId: String,
        roomNumber: String,
        itemId: String,
        isChecked: Bool
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        // Get the round document
        let roundRef = db.collection("halls")
            .document(hallId)
            .collection("inspection_rounds")
            .document(roundId)

        let snapshot = try await roundRef.getDocument()
        guard var data = snapshot.data(),
              var roomsArray = data["rooms"] as? [[String: Any]] else {
            throw RoomCheckError.notFound
        }

        // Find and update the room
        if let roomIndex = roomsArray.firstIndex(where: { ($0["roomNumber"] as? String) == roomNumber }) {
            if var checklist = roomsArray[roomIndex]["checklist"] as? [[String: Any]] {
                if let itemIndex = checklist.firstIndex(where: { ($0["id"] as? String) == itemId }) {
                    checklist[itemIndex]["isChecked"] = isChecked
                    roomsArray[roomIndex]["checklist"] = checklist
                }
            }
        }

        try await roundRef.updateData([
            "rooms": roomsArray,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Updated checklist item \(itemId) in room \(roomNumber)")
        #endif
        #endif
    }

    func updateRoomNotes(
        hallId: String,
        roundId: String,
        roomNumber: String,
        notes: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let roundRef = db.collection("halls")
            .document(hallId)
            .collection("inspection_rounds")
            .document(roundId)

        let snapshot = try await roundRef.getDocument()
        guard var data = snapshot.data(),
              var roomsArray = data["rooms"] as? [[String: Any]] else {
            throw RoomCheckError.notFound
        }

        if let roomIndex = roomsArray.firstIndex(where: { ($0["roomNumber"] as? String) == roomNumber }) {
            roomsArray[roomIndex]["notes"] = notes
        }

        try await roundRef.updateData([
            "rooms": roomsArray,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Updated notes for room \(roomNumber)")
        #endif
        #endif
    }

    func markRoomComplete(
        hallId: String,
        roundId: String,
        roomNumber: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw RoomCheckError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        let roundRef = db.collection("halls")
            .document(hallId)
            .collection("inspection_rounds")
            .document(roundId)

        let snapshot = try await roundRef.getDocument()
        guard var data = snapshot.data(),
              var roomsArray = data["rooms"] as? [[String: Any]] else {
            throw RoomCheckError.notFound
        }

        if let roomIndex = roomsArray.firstIndex(where: { ($0["roomNumber"] as? String) == roomNumber }) {
            roomsArray[roomIndex]["status"] = "completed"
            roomsArray[roomIndex]["completedAt"] = Timestamp(date: Date())
            roomsArray[roomIndex]["completedBy"] = uid
        }

        // Check if all rooms are complete
        let allComplete = roomsArray.allSatisfy { ($0["status"] as? String) == "completed" }

        var updateData: [String: Any] = [
            "rooms": roomsArray,
            "updatedAt": FieldValue.serverTimestamp()
        ]

        if allComplete {
            updateData["status"] = "completed"
        }

        try await roundRef.updateData(updateData)

        #if DEBUG
        print("🏠 ROOMCHECK: Marked room \(roomNumber) as complete")
        #endif
        #endif
    }

    func reopenRoom(
        hallId: String,
        roundId: String,
        roomNumber: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let roundRef = db.collection("halls")
            .document(hallId)
            .collection("inspection_rounds")
            .document(roundId)

        let snapshot = try await roundRef.getDocument()
        guard var data = snapshot.data(),
              var roomsArray = data["rooms"] as? [[String: Any]] else {
            throw RoomCheckError.notFound
        }

        if let roomIndex = roomsArray.firstIndex(where: { ($0["roomNumber"] as? String) == roomNumber }) {
            roomsArray[roomIndex]["status"] = "pending"
            roomsArray[roomIndex]["completedAt"] = NSNull()
            roomsArray[roomIndex]["completedBy"] = NSNull()
        }

        try await roundRef.updateData([
            "rooms": roomsArray,
            "status": "active", // Reopen round if it was completed
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Reopened room \(roomNumber)")
        #endif
        #endif
    }

    // MARK: - Computed Properties

    var activeRounds: [InspectionRound] {
        rounds.filter { $0.status == .active }
    }

    var hasActiveRounds: Bool {
        !activeRounds.isEmpty
    }

    var totalPendingRooms: Int {
        rounds.flatMap { $0.rooms }.filter { $0.status == .pending }.count
    }

    var statusText: String {
        if rounds.isEmpty {
            return "No inspections assigned"
        }
        let pending = totalPendingRooms
        if pending == 0 {
            return "All complete"
        }
        return "\(pending) rooms remaining"
    }

    // MARK: - Helpers

    #if canImport(FirebaseFirestore)
    private func parseRound(_ doc: DocumentSnapshot) -> InspectionRound? {
        guard let data = doc.data() else {
            #if DEBUG
            print("🏠 ROOMCHECK: No data for doc \(doc.documentID)")
            #endif
            return nil
        }

        guard let name = data["name"] as? String else {
            #if DEBUG
            print("🏠 ROOMCHECK: Missing name for doc \(doc.documentID)")
            #endif
            return nil
        }

        // Parse dueDate - ISO string from web
        var dueDate: Date? = nil
        if let dueDateStr = data["dueDate"] as? String, !dueDateStr.isEmpty {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            dueDate = formatter.date(from: dueDateStr)
        }

        // Parse status
        let statusStr = data["status"] as? String ?? "active"
        let status = InspectionRound.RoundStatus(rawValue: statusStr) ?? .active

        // Parse createdAt
        var createdAt = Date()
        if let timestamp = data["createdAt"] as? Timestamp {
            createdAt = timestamp.dateValue()
        }

        // Parse rooms
        let roomsData = data["rooms"] as? [[String: Any]] ?? []
        let rooms = roomsData.compactMap { parseRoom($0) }

        return InspectionRound(
            id: doc.documentID,
            name: name,
            templateId: data["templateId"] as? String ?? "",
            templateName: data["templateName"] as? String ?? "Unknown",
            dueDate: dueDate,
            status: status,
            rooms: rooms,
            createdAt: createdAt
        )
    }

    private func parseRoom(_ data: [String: Any]) -> RoomInspection? {
        guard let roomNumber = data["roomNumber"] as? String else { return nil }

        let statusStr = data["status"] as? String ?? "pending"
        let status = RoomInspection.RoomStatus(rawValue: statusStr) ?? .pending

        let checklistData = data["checklist"] as? [[String: Any]] ?? []
        let checklist = checklistData.compactMap { item -> ChecklistItem? in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String else { return nil }
            return ChecklistItem(
                id: id,
                name: name,
                isChecked: item["isChecked"] as? Bool ?? false
            )
        }

        var completedAt: Date? = nil
        if let timestamp = data["completedAt"] as? Timestamp {
            completedAt = timestamp.dateValue()
        }

        return RoomInspection(
            id: roomNumber,
            roomNumber: roomNumber,
            status: status,
            checklist: checklist,
            notes: data["notes"] as? String ?? "",
            completedAt: completedAt,
            completedBy: data["completedBy"] as? String
        )
    }
    #endif
}

// MARK: - Errors

enum RoomCheckError: LocalizedError {
    case notConfigured
    case notAuthenticated
    case notFound
    case permissionDenied

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Room check service is not configured"
        case .notAuthenticated:
            return "User is not authenticated"
        case .notFound:
            return "Inspection not found"
        case .permissionDenied:
            return "Permission denied"
        }
    }
}
