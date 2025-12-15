import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Firebase service for Room Check functionality
/// Syncs room inspections to /halls/{hallId}/room_inspections/{inspectionId}
@MainActor
final class RoomCheckService: ObservableObject {

    // MARK: - Singleton

    static let shared = RoomCheckService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var isSyncing = false
    @Published private(set) var error: String?
    @Published private(set) var inspections: [FirebaseRoomInspection] = []

    private var listenerRegistration: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Firebase Models

    struct FirebaseRoomInspection: Identifiable, Equatable {
        let id: String
        let roomNumber: String
        let building: String?
        let floor: String?
        let checklist: [FirebaseChecklistItem]
        let notes: String
        let photoUrls: [String]
        let isComplete: Bool
        let inspectedAt: Date?
        let inspectedBy: String?
        let createdAt: Date
        let updatedAt: Date

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
    }

    struct FirebaseChecklistItem: Identifiable, Equatable, Codable {
        let id: String
        var name: String
        var isChecked: Bool
    }

    // MARK: - Listen to Inspections

    /// Start listening to room inspections for the current hall
    func startListening(hallId: String) {
        #if canImport(FirebaseFirestore)
        stopListening()

        #if DEBUG
        print("🏠 ROOMCHECK: Starting listener for hall \(hallId)")
        #endif

        let query = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .order(by: "roomNumber", descending: false)

        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("🏠 ROOMCHECK: Listener error: \(error.localizedDescription)")
                #endif
                self.error = error.localizedDescription
                return
            }

            guard let documents = snapshot?.documents else {
                self.inspections = []
                return
            }

            #if DEBUG
            print("🏠 ROOMCHECK: Received \(documents.count) inspections")
            #endif

            self.inspections = documents.compactMap { doc -> FirebaseRoomInspection? in
                self.parseInspection(doc)
            }
        }
        #endif
    }

    /// Stop listening to inspections
    func stopListening() {
        #if canImport(FirebaseFirestore)
        if let registration = listenerRegistration as? ListenerRegistration {
            registration.remove()
            listenerRegistration = nil
        }
        #endif
    }

    // MARK: - Create Inspection

    /// Create a new room inspection
    func createInspection(
        hallId: String,
        roomNumber: String,
        building: String? = nil,
        floor: String? = nil
    ) async throws -> String {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw RoomCheckError.notAuthenticated
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let inspectionRef = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document()

        let defaultChecklist = Self.defaultChecklistItems()

        let data: [String: Any] = [
            "roomNumber": roomNumber,
            "building": building as Any,
            "floor": floor as Any,
            "checklist": defaultChecklist.map { item in
                [
                    "id": item.id,
                    "name": item.name,
                    "isChecked": item.isChecked
                ]
            },
            "notes": "",
            "photoUrls": [],
            "isComplete": false,
            "inspectedAt": NSNull(),
            "inspectedBy": NSNull(),
            "createdBy": uid,
            "createdAt": FieldValue.serverTimestamp(),
            "updatedAt": FieldValue.serverTimestamp()
        ]

        try await inspectionRef.setData(data)

        #if DEBUG
        print("🏠 ROOMCHECK: Created inspection \(inspectionRef.documentID)")
        #endif

        return inspectionRef.documentID
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    // MARK: - Update Inspection

    /// Update checklist item status
    func updateChecklistItem(
        hallId: String,
        inspectionId: String,
        itemId: String,
        isChecked: Bool
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        // First get the current inspection
        let inspectionRef = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document(inspectionId)

        let snapshot = try await inspectionRef.getDocument()
        guard snapshot.exists, var data = snapshot.data() else {
            throw RoomCheckError.notFound
        }

        // Update the checklist item
        if var checklist = data["checklist"] as? [[String: Any]] {
            if let index = checklist.firstIndex(where: { ($0["id"] as? String) == itemId }) {
                checklist[index]["isChecked"] = isChecked
                data["checklist"] = checklist

                try await inspectionRef.updateData([
                    "checklist": checklist,
                    "updatedAt": FieldValue.serverTimestamp()
                ])

                #if DEBUG
                print("🏠 ROOMCHECK: Updated checklist item \(itemId) to \(isChecked)")
                #endif
            }
        }
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    /// Update notes for an inspection
    func updateNotes(
        hallId: String,
        inspectionId: String,
        notes: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let inspectionRef = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document(inspectionId)

        try await inspectionRef.updateData([
            "notes": notes,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Updated notes for \(inspectionId)")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    /// Mark inspection as complete
    func markComplete(
        hallId: String,
        inspectionId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw RoomCheckError.notAuthenticated
        }

        isSyncing = true
        defer { isSyncing = false }

        let inspectionRef = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document(inspectionId)

        try await inspectionRef.updateData([
            "isComplete": true,
            "inspectedAt": FieldValue.serverTimestamp(),
            "inspectedBy": uid,
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Marked \(inspectionId) as complete")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    /// Reopen an inspection (mark as incomplete)
    func reopenInspection(
        hallId: String,
        inspectionId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let inspectionRef = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document(inspectionId)

        try await inspectionRef.updateData([
            "isComplete": false,
            "inspectedAt": NSNull(),
            "inspectedBy": NSNull(),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Reopened \(inspectionId)")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    /// Add photo URL to inspection
    func addPhotoUrl(
        hallId: String,
        inspectionId: String,
        photoUrl: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let inspectionRef = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document(inspectionId)

        try await inspectionRef.updateData([
            "photoUrls": FieldValue.arrayUnion([photoUrl]),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Added photo to \(inspectionId)")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    /// Remove photo URL from inspection
    func removePhotoUrl(
        hallId: String,
        inspectionId: String,
        photoUrl: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isSyncing = true
        defer { isSyncing = false }

        let inspectionRef = db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document(inspectionId)

        try await inspectionRef.updateData([
            "photoUrls": FieldValue.arrayRemove([photoUrl]),
            "updatedAt": FieldValue.serverTimestamp()
        ])

        #if DEBUG
        print("🏠 ROOMCHECK: Removed photo from \(inspectionId)")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    // MARK: - Batch Operations

    /// Create multiple inspections for a list of room numbers
    func setupRooms(
        hallId: String,
        roomNumbers: [String],
        building: String? = nil
    ) async throws {
        #if canImport(FirebaseFirestore)
        guard let uid = Auth.auth().currentUser?.uid else {
            throw RoomCheckError.notAuthenticated
        }

        isLoading = true
        error = nil
        defer { isLoading = false }

        let batch = db.batch()
        let defaultChecklist = Self.defaultChecklistItems()

        for roomNumber in roomNumbers {
            let inspectionRef = db.collection("halls")
                .document(hallId)
                .collection("room_inspections")
                .document()

            let data: [String: Any] = [
                "roomNumber": roomNumber,
                "building": building as Any,
                "floor": NSNull(),
                "checklist": defaultChecklist.map { item in
                    [
                        "id": item.id,
                        "name": item.name,
                        "isChecked": item.isChecked
                    ]
                },
                "notes": "",
                "photoUrls": [],
                "isComplete": false,
                "inspectedAt": NSNull(),
                "inspectedBy": NSNull(),
                "createdBy": uid,
                "createdAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ]

            batch.setData(data, forDocument: inspectionRef)
        }

        try await batch.commit()

        #if DEBUG
        print("🏠 ROOMCHECK: Created \(roomNumbers.count) inspections")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    /// Start a new inspection round (reset all inspections)
    func startNewRound(hallId: String) async throws {
        #if canImport(FirebaseFirestore)
        isLoading = true
        error = nil
        defer { isLoading = false }

        // Get all existing inspections
        let snapshot = try await db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .getDocuments()

        let batch = db.batch()
        let defaultChecklist = Self.defaultChecklistItems()

        for doc in snapshot.documents {
            let ref = doc.reference
            batch.updateData([
                "checklist": defaultChecklist.map { item in
                    [
                        "id": item.id,
                        "name": item.name,
                        "isChecked": false
                    ]
                },
                "notes": "",
                "photoUrls": [],
                "isComplete": false,
                "inspectedAt": NSNull(),
                "inspectedBy": NSNull(),
                "updatedAt": FieldValue.serverTimestamp()
            ], forDocument: ref)
        }

        try await batch.commit()

        #if DEBUG
        print("🏠 ROOMCHECK: Started new round, reset \(snapshot.documents.count) inspections")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    /// Delete an inspection
    func deleteInspection(
        hallId: String,
        inspectionId: String
    ) async throws {
        #if canImport(FirebaseFirestore)
        isLoading = true
        defer { isLoading = false }

        try await db.collection("halls")
            .document(hallId)
            .collection("room_inspections")
            .document(inspectionId)
            .delete()

        #if DEBUG
        print("🏠 ROOMCHECK: Deleted inspection \(inspectionId)")
        #endif
        #else
        throw RoomCheckError.notConfigured
        #endif
    }

    // MARK: - Computed Properties

    var completedInspections: [FirebaseRoomInspection] {
        inspections.filter { $0.isComplete }
    }

    var pendingInspections: [FirebaseRoomInspection] {
        inspections.filter { !$0.isComplete }
    }

    var completedCount: Int {
        completedInspections.count
    }

    var totalCount: Int {
        inspections.count
    }

    var overallProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    var statusText: String {
        if inspections.isEmpty {
            return "Set up rooms"
        }
        return "\(completedCount)/\(totalCount) completed"
    }

    // MARK: - Helpers

    #if canImport(FirebaseFirestore)
    private func parseInspection(_ doc: DocumentSnapshot) -> FirebaseRoomInspection? {
        guard let data = doc.data() else { return nil }

        guard let roomNumber = data["roomNumber"] as? String,
              let createdAt = (data["createdAt"] as? Timestamp)?.dateValue(),
              let updatedAt = (data["updatedAt"] as? Timestamp)?.dateValue() else {
            return nil
        }

        let checklistData = data["checklist"] as? [[String: Any]] ?? []
        let checklist = checklistData.compactMap { item -> FirebaseChecklistItem? in
            guard let id = item["id"] as? String,
                  let name = item["name"] as? String else {
                return nil
            }
            return FirebaseChecklistItem(
                id: id,
                name: name,
                isChecked: item["isChecked"] as? Bool ?? false
            )
        }

        return FirebaseRoomInspection(
            id: doc.documentID,
            roomNumber: roomNumber,
            building: data["building"] as? String,
            floor: data["floor"] as? String,
            checklist: checklist,
            notes: data["notes"] as? String ?? "",
            photoUrls: data["photoUrls"] as? [String] ?? [],
            isComplete: data["isComplete"] as? Bool ?? false,
            inspectedAt: (data["inspectedAt"] as? Timestamp)?.dateValue(),
            inspectedBy: data["inspectedBy"] as? String,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
    #endif

    static func defaultChecklistItems() -> [FirebaseChecklistItem] {
        [
            FirebaseChecklistItem(id: UUID().uuidString, name: "Door and lock functioning", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "Windows secure and undamaged", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "Lights working", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "Smoke detector present and working", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "Furniture in good condition", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "No prohibited items visible", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "Room clean and orderly", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "No safety hazards", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "Bathroom clean (if applicable)", isChecked: false),
            FirebaseChecklistItem(id: UUID().uuidString, name: "No signs of damage", isChecked: false)
        ]
    }
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
