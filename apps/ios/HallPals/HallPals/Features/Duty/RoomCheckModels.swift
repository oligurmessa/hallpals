import Foundation
import SwiftUI

// MARK: - Room Model

struct Room: Identifiable, Codable, Equatable {
    let id: UUID
    var roomNumber: String
    var building: String?
    var floor: String?
    var residentNames: [String]

    init(
        id: UUID = UUID(),
        roomNumber: String,
        building: String? = nil,
        floor: String? = nil,
        residentNames: [String] = []
    ) {
        self.id = id
        self.roomNumber = roomNumber
        self.building = building
        self.floor = floor
        self.residentNames = residentNames
    }

    var displayName: String {
        if let building = building {
            return "\(building) \(roomNumber)"
        }
        return roomNumber
    }
}

// MARK: - Checklist Item

struct ChecklistItem: Identifiable, Codable, Equatable {
    let id: UUID
    var name: String
    var isChecked: Bool

    init(id: UUID = UUID(), name: String, isChecked: Bool = false) {
        self.id = id
        self.name = name
        self.isChecked = isChecked
    }
}

// MARK: - Room Inspection

struct RoomInspection: Identifiable, Codable, Equatable {
    let id: UUID
    let roomId: UUID
    var checklist: [ChecklistItem]
    var notes: String
    var photoData: [Data]  // Store photo data
    var isComplete: Bool
    var inspectedAt: Date?
    let createdAt: Date

    init(
        id: UUID = UUID(),
        roomId: UUID,
        checklist: [ChecklistItem] = RoomInspection.defaultChecklist(),
        notes: String = "",
        photoData: [Data] = [],
        isComplete: Bool = false,
        inspectedAt: Date? = nil,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.roomId = roomId
        self.checklist = checklist
        self.notes = notes
        self.photoData = photoData
        self.isComplete = isComplete
        self.inspectedAt = inspectedAt
        self.createdAt = createdAt
    }

    /// Default checklist items for room inspection
    static func defaultChecklist() -> [ChecklistItem] {
        [
            ChecklistItem(name: "Door and lock functioning"),
            ChecklistItem(name: "Windows secure and undamaged"),
            ChecklistItem(name: "Lights working"),
            ChecklistItem(name: "Smoke detector present and working"),
            ChecklistItem(name: "Furniture in good condition"),
            ChecklistItem(name: "No prohibited items visible"),
            ChecklistItem(name: "Room clean and orderly"),
            ChecklistItem(name: "No safety hazards"),
            ChecklistItem(name: "Bathroom clean (if applicable)"),
            ChecklistItem(name: "No signs of damage")
        ]
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
}

// MARK: - Room Check Store

class RoomCheckStore: ObservableObject {
    static let shared = RoomCheckStore()

    @Published var rooms: [Room] = []
    @Published var inspections: [RoomInspection] = []
    @Published var currentRoundDate: Date?

    private let roomsKey = "hallpals_roomcheck_rooms"
    private let inspectionsKey = "hallpals_roomcheck_inspections"
    private let roundDateKey = "hallpals_roomcheck_round_date"

    private init() {
        loadFromStorage()
        createDefaultRoomsIfNeeded()
    }

    // MARK: - Computed Properties

    var completedInspections: [RoomInspection] {
        inspections.filter { $0.isComplete }
    }

    var pendingInspections: [RoomInspection] {
        inspections.filter { !$0.isComplete }
    }

    var completedCount: Int {
        completedInspections.count
    }

    var totalCount: Int {
        rooms.count
    }

    var statusText: String {
        if rooms.isEmpty {
            return "Set up rooms"
        }
        return "\(completedCount)/\(totalCount) completed"
    }

    var overallProgress: Double {
        guard totalCount > 0 else { return 0 }
        return Double(completedCount) / Double(totalCount)
    }

    // MARK: - Room Management

    func addRoom(_ room: Room) {
        rooms.append(room)
        // Create an inspection for the new room
        let inspection = RoomInspection(roomId: room.id)
        inspections.append(inspection)
        saveToStorage()
    }

    func updateRoom(_ room: Room) {
        if let index = rooms.firstIndex(where: { $0.id == room.id }) {
            rooms[index] = room
            saveToStorage()
        }
    }

    func deleteRoom(_ room: Room) {
        rooms.removeAll { $0.id == room.id }
        inspections.removeAll { $0.roomId == room.id }
        saveToStorage()
    }

    func room(for inspection: RoomInspection) -> Room? {
        rooms.first { $0.id == inspection.roomId }
    }

    func inspection(for room: Room) -> RoomInspection? {
        inspections.first { $0.roomId == room.id }
    }

    // MARK: - Inspection Management

    func updateInspection(_ inspection: RoomInspection) {
        if let index = inspections.firstIndex(where: { $0.id == inspection.id }) {
            inspections[index] = inspection
            saveToStorage()
        }
    }

    func markInspectionComplete(_ inspection: RoomInspection) {
        if let index = inspections.firstIndex(where: { $0.id == inspection.id }) {
            inspections[index].isComplete = true
            inspections[index].inspectedAt = Date()
            saveToStorage()
        }
    }

    func toggleChecklistItem(inspectionId: UUID, itemId: UUID) {
        if let inspectionIndex = inspections.firstIndex(where: { $0.id == inspectionId }),
           let itemIndex = inspections[inspectionIndex].checklist.firstIndex(where: { $0.id == itemId }) {
            inspections[inspectionIndex].checklist[itemIndex].isChecked.toggle()
            saveToStorage()
        }
    }

    func updateNotes(inspectionId: UUID, notes: String) {
        if let index = inspections.firstIndex(where: { $0.id == inspectionId }) {
            inspections[index].notes = notes
            saveToStorage()
        }
    }

    func addPhoto(inspectionId: UUID, photoData: Data) {
        if let index = inspections.firstIndex(where: { $0.id == inspectionId }) {
            inspections[index].photoData.append(photoData)
            saveToStorage()
        }
    }

    func removePhoto(inspectionId: UUID, at photoIndex: Int) {
        if let index = inspections.firstIndex(where: { $0.id == inspectionId }) {
            guard photoIndex < inspections[index].photoData.count else { return }
            inspections[index].photoData.remove(at: photoIndex)
            saveToStorage()
        }
    }

    // MARK: - Round Management

    func startNewRound() {
        currentRoundDate = Date()
        // Reset all inspections
        inspections = rooms.map { room in
            RoomInspection(roomId: room.id)
        }
        saveToStorage()
    }

    // MARK: - Bulk Room Setup

    func setupRooms(roomNumbers: [String], building: String? = nil) {
        // Clear existing
        rooms.removeAll()
        inspections.removeAll()

        // Add new rooms
        for number in roomNumbers {
            let room = Room(roomNumber: number, building: building)
            rooms.append(room)
            inspections.append(RoomInspection(roomId: room.id))
        }
        saveToStorage()
    }

    // MARK: - Default Rooms

    private func createDefaultRoomsIfNeeded() {
        if rooms.isEmpty {
            // Create sample rooms (user can customize later)
            let sampleRooms = (101...127).map { "\($0)" }
            setupRooms(roomNumbers: sampleRooms)
        }
    }

    // MARK: - Storage

    private func saveToStorage() {
        if let roomsData = try? JSONEncoder().encode(rooms) {
            UserDefaults.standard.set(roomsData, forKey: roomsKey)
        }
        if let inspectionsData = try? JSONEncoder().encode(inspections) {
            UserDefaults.standard.set(inspectionsData, forKey: inspectionsKey)
        }
        if let roundDate = currentRoundDate {
            UserDefaults.standard.set(roundDate, forKey: roundDateKey)
        }
    }

    private func loadFromStorage() {
        if let data = UserDefaults.standard.data(forKey: roomsKey),
           let decoded = try? JSONDecoder().decode([Room].self, from: data) {
            rooms = decoded
        }
        if let data = UserDefaults.standard.data(forKey: inspectionsKey),
           let decoded = try? JSONDecoder().decode([RoomInspection].self, from: data) {
            inspections = decoded
        }
        currentRoundDate = UserDefaults.standard.object(forKey: roundDateKey) as? Date
    }

    func clearAll() {
        rooms = []
        inspections = []
        currentRoundDate = nil
        UserDefaults.standard.removeObject(forKey: roomsKey)
        UserDefaults.standard.removeObject(forKey: inspectionsKey)
        UserDefaults.standard.removeObject(forKey: roundDateKey)
    }
}
