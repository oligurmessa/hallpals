import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Models

struct MoveOutChecklistItem: Identifiable, Codable {
    let id: String
    let text: String
    let order: Int
    let isRequired: Bool
}

struct MoveOutTemplate: Identifiable, Codable {
    @DocumentID var id: String?
    let title: String
    let description: String?
    let items: [MoveOutChecklistItem]
    let isPublished: Bool
    let publishedAt: Timestamp?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
}

struct ResidentMoveOutChecklist: Identifiable, Codable {
    @DocumentID var id: String?
    let residentId: String
    let residentName: String
    let roomNumber: String
    let checklistId: String
    var completedItems: [String] // Array of item IDs that are completed
    var isComplete: Bool
    let completedAt: Timestamp?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?
}

// MARK: - Service

@MainActor
class MoveOutChecklistService: ObservableObject {
    static let shared = MoveOutChecklistService()

    @Published var currentTemplate: MoveOutTemplate?
    @Published var residentChecklist: ResidentMoveOutChecklist?
    @Published var isLoading = false
    @Published var errorMessage: String?

    private let db = Firestore.firestore()
    private var templateListener: ListenerRegistration?
    private var checklistListener: ListenerRegistration?

    private init() {}

    // MARK: - Fetch Published Template

    func startListening(hallId: String) {
        guard !hallId.isEmpty else {
            #if DEBUG
            print("🔥 MoveOutChecklistService: No hall ID provided")
            #endif
            return
        }

        #if DEBUG
        print("🔥 MoveOutChecklistService: Starting listener for hallId=\(hallId)")
        print("🔥 MoveOutChecklistService: Query path = halls/\(hallId)/move_out_templates where isPublished==true")
        #endif

        stopListening()
        isLoading = true

        // Listen for published template
        templateListener = db.collection("halls").document(hallId)
            .collection("move_out_templates")
            .whereField("isPublished", isEqualTo: true)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("🔥 MoveOutChecklistService: Error fetching template: \(error)")
                    #endif
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                #if DEBUG
                print("🔥 MoveOutChecklistService: Snapshot received, document count = \(snapshot?.documents.count ?? 0)")
                #endif

                if let doc = snapshot?.documents.first {
                    #if DEBUG
                    print("🔥 MoveOutChecklistService: Document ID = \(doc.documentID)")
                    print("🔥 MoveOutChecklistService: Document data = \(doc.data())")
                    #endif
                    do {
                        self.currentTemplate = try doc.data(as: MoveOutTemplate.self)
                        #if DEBUG
                        print("🔥 MoveOutChecklistService: Loaded template: \(self.currentTemplate?.title ?? "nil")")
                        #endif

                        // Now fetch or create resident's checklist
                        if let template = self.currentTemplate {
                            self.fetchOrCreateResidentChecklist(hallId: hallId, templateId: template.id ?? "")
                        }
                    } catch {
                        #if DEBUG
                        print("🔥 MoveOutChecklistService: Error decoding template: \(error)")
                        #endif
                    }
                } else {
                    self.currentTemplate = nil
                    self.residentChecklist = nil
                    #if DEBUG
                    print("🔥 MoveOutChecklistService: No published template found (0 documents)")
                    #endif
                }

                self.isLoading = false
            }
    }

    func stopListening() {
        templateListener?.remove()
        templateListener = nil
        checklistListener?.remove()
        checklistListener = nil
    }

    // MARK: - Resident Checklist

    private func fetchOrCreateResidentChecklist(hallId: String, templateId: String) {
        guard let userId = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("🔥 MoveOutChecklistService: No authenticated user")
            #endif
            return
        }

        // Listen for resident's checklist
        checklistListener?.remove()
        checklistListener = db.collection("halls").document(hallId)
            .collection("move_out_checklists")
            .whereField("residentId", isEqualTo: userId)
            .whereField("checklistId", isEqualTo: templateId)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("🔥 MoveOutChecklistService: Error fetching resident checklist: \(error)")
                    #endif
                    return
                }

                if let doc = snapshot?.documents.first {
                    do {
                        self.residentChecklist = try doc.data(as: ResidentMoveOutChecklist.self)
                        #if DEBUG
                        print("🔥 MoveOutChecklistService: Loaded resident checklist")
                        #endif
                    } catch {
                        #if DEBUG
                        print("🔥 MoveOutChecklistService: Error decoding resident checklist: \(error)")
                        #endif
                    }
                } else {
                    self.residentChecklist = nil
                    #if DEBUG
                    print("🔥 MoveOutChecklistService: No existing checklist for resident")
                    #endif
                }
            }
    }

    // MARK: - Toggle Item Completion

    func toggleItem(hallId: String, itemId: String) async {
        guard let template = currentTemplate,
              let templateId = template.id,
              let userId = Auth.auth().currentUser?.uid else {
            return
        }

        let userName = UserManager.shared.currentUser?.displayName ?? "Unknown"
        let roomNumber = UserManager.shared.roomNumber ?? "---"

        do {
            if let existingChecklist = residentChecklist, let checklistId = existingChecklist.id {
                // Update existing checklist
                var completedItems = existingChecklist.completedItems

                if completedItems.contains(itemId) {
                    completedItems.removeAll { $0 == itemId }
                } else {
                    completedItems.append(itemId)
                }

                // Check if all required items are complete
                let requiredItems = template.items.filter { $0.isRequired }.map { $0.id }
                let isComplete = requiredItems.allSatisfy { completedItems.contains($0) }

                try await db.collection("halls").document(hallId)
                    .collection("move_out_checklists").document(checklistId)
                    .updateData([
                        "completedItems": completedItems,
                        "isComplete": isComplete,
                        "completedAt": isComplete ? FieldValue.serverTimestamp() : NSNull(),
                        "updatedAt": FieldValue.serverTimestamp()
                    ])

                #if DEBUG
                print("🔥 MoveOutChecklistService: Updated item \(itemId), complete: \(isComplete)")
                #endif
            } else {
                // Create new checklist for resident
                let completedItems = [itemId]
                let requiredItems = template.items.filter { $0.isRequired }.map { $0.id }
                let isComplete = requiredItems.allSatisfy { completedItems.contains($0) }

                let newRef = db.collection("halls").document(hallId)
                    .collection("move_out_checklists").document()

                try await newRef.setData([
                    "residentId": userId,
                    "residentName": userName,
                    "roomNumber": roomNumber,
                    "checklistId": templateId,
                    "completedItems": completedItems,
                    "isComplete": isComplete,
                    "completedAt": isComplete ? FieldValue.serverTimestamp() : NSNull(),
                    "createdAt": FieldValue.serverTimestamp(),
                    "updatedAt": FieldValue.serverTimestamp()
                ])

                #if DEBUG
                print("🔥 MoveOutChecklistService: Created new checklist for resident")
                #endif
            }
        } catch {
            #if DEBUG
            print("🔥 MoveOutChecklistService: Error toggling item: \(error)")
            #endif
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Computed Properties

    var completionProgress: Double {
        guard let template = currentTemplate else { return 0 }
        let requiredItems = template.items.filter { $0.isRequired }
        guard !requiredItems.isEmpty else { return 1 }

        let completedRequired = requiredItems.filter { item in
            residentChecklist?.completedItems.contains(item.id) ?? false
        }.count

        return Double(completedRequired) / Double(requiredItems.count)
    }

    var statusText: String {
        guard currentTemplate != nil else { return "No checklist available" }
        if residentChecklist?.isComplete == true {
            return "Completed"
        }
        let percent = Int(completionProgress * 100)
        return "\(percent)% complete"
    }
}
