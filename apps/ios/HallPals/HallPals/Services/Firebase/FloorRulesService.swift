import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - Models

struct FloorRules: Identifiable, Codable {
    @DocumentID var id: String?
    let raUid: String
    let raName: String?
    let floor: Int?
    let wing: String?
    let title: String
    let rules: [RuleItem]
    let expectations: [String]
    let isPublished: Bool
    let publishedAt: Timestamp?
    let createdAt: Timestamp?
    let updatedAt: Timestamp?

    struct RuleItem: Identifiable, Codable {
        let id: String
        let text: String
        let order: Int
        let category: String? // e.g., "Quiet Hours", "Common Areas", "Guest Policy"
    }
}

// MARK: - Service

@MainActor
class FloorRulesService: ObservableObject {
    static let shared = FloorRulesService()

    // For residents viewing rules
    @Published var currentRules: FloorRules?
    @Published var isLoading = false
    @Published var errorMessage: String?

    // For RAs managing their rules
    @Published var myRules: FloorRules?
    @Published var isSaving = false

    private let db = Firestore.firestore()
    private var rulesListener: ListenerRegistration?

    private init() {}

    // MARK: - Resident: Listen for Floor Rules

    /// Residents call this to listen for rules from their assigned RA (by floor/wing)
    func startListeningForResident(hallId: String, floor: Int?, wing: String?) {
        guard !hallId.isEmpty else {
            #if DEBUG
            print("🔥 FloorRulesService: No hall ID provided")
            #endif
            return
        }

        stopListening()
        isLoading = true

        #if DEBUG
        print("🔥 FloorRulesService: Listening for rules - hallId=\(hallId), floor=\(String(describing: floor)), wing=\(String(describing: wing))")
        #endif

        // Query for published rules matching resident's floor/wing
        var query: Query = db.collection("halls").document(hallId)
            .collection("floor_rules")
            .whereField("isPublished", isEqualTo: true)

        // Filter by floor if available
        if let floor = floor {
            query = query.whereField("floor", isEqualTo: floor)
        }

        // Note: Can't combine multiple inequality filters, so wing filtering happens client-side
        query = query.limit(to: 1)

        rulesListener = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }

            if let error = error {
                #if DEBUG
                print("🔥 FloorRulesService: Error fetching rules: \(error)")
                #endif
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                return
            }

            #if DEBUG
            print("🔥 FloorRulesService: Snapshot received, document count = \(snapshot?.documents.count ?? 0)")
            #endif

            // Find matching rules (filter by wing client-side if needed)
            if let doc = snapshot?.documents.first(where: { doc in
                let data = doc.data()
                // If wing is specified, check it matches (or rules have no wing = applies to all)
                if let residentWing = wing, !residentWing.isEmpty {
                    let rulesWing = data["wing"] as? String
                    return rulesWing == nil || rulesWing == residentWing || rulesWing?.isEmpty == true
                }
                return true
            }) {
                do {
                    self.currentRules = try doc.data(as: FloorRules.self)
                    #if DEBUG
                    print("🔥 FloorRulesService: Loaded rules: \(self.currentRules?.title ?? "nil")")
                    #endif
                } catch {
                    #if DEBUG
                    print("🔥 FloorRulesService: Error decoding rules: \(error)")
                    #endif
                }
            } else {
                self.currentRules = nil
                #if DEBUG
                print("🔥 FloorRulesService: No published rules found for this floor/wing")
                #endif
            }

            self.isLoading = false
        }
    }

    // MARK: - RA: Listen for My Rules

    /// RAs call this to listen for their own floor rules document
    func startListeningForRA(hallId: String) {
        guard !hallId.isEmpty else {
            #if DEBUG
            print("🔥 FloorRulesService: No hall ID provided")
            #endif
            return
        }

        guard let userId = Auth.auth().currentUser?.uid else {
            #if DEBUG
            print("🔥 FloorRulesService: No authenticated user")
            #endif
            return
        }

        stopListening()
        isLoading = true

        #if DEBUG
        print("🔥 FloorRulesService: RA listening for own rules - hallId=\(hallId), raUid=\(userId)")
        #endif

        // Listen for the RA's own rules document
        rulesListener = db.collection("halls").document(hallId)
            .collection("floor_rules")
            .whereField("raUid", isEqualTo: userId)
            .limit(to: 1)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self = self else { return }

                if let error = error {
                    #if DEBUG
                    print("🔥 FloorRulesService: Error fetching RA rules: \(error)")
                    #endif
                    self.errorMessage = error.localizedDescription
                    self.isLoading = false
                    return
                }

                if let doc = snapshot?.documents.first {
                    do {
                        self.myRules = try doc.data(as: FloorRules.self)
                        #if DEBUG
                        print("🔥 FloorRulesService: Loaded RA's rules: \(self.myRules?.title ?? "nil")")
                        #endif
                    } catch {
                        #if DEBUG
                        print("🔥 FloorRulesService: Error decoding RA rules: \(error)")
                        #endif
                    }
                } else {
                    self.myRules = nil
                    #if DEBUG
                    print("🔥 FloorRulesService: RA has no rules document yet")
                    #endif
                }

                self.isLoading = false
            }
    }

    func stopListening() {
        rulesListener?.remove()
        rulesListener = nil
    }

    // MARK: - RA: Save/Update Rules

    func saveRules(
        hallId: String,
        title: String,
        rules: [FloorRules.RuleItem],
        expectations: [String],
        floor: Int?,
        wing: String?
    ) async throws {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "FloorRulesService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        let raName = UserManager.shared.currentUser?.displayName

        isSaving = true
        defer { isSaving = false }

        let now = FieldValue.serverTimestamp()

        if let existingId = myRules?.id {
            // Update existing rules
            try await db.collection("halls").document(hallId)
                .collection("floor_rules").document(existingId)
                .updateData([
                    "title": title,
                    "rules": rules.map { rule in
                        [
                            "id": rule.id,
                            "text": rule.text,
                            "order": rule.order,
                            "category": rule.category as Any
                        ]
                    },
                    "expectations": expectations,
                    "floor": floor as Any,
                    "wing": wing as Any,
                    "raName": raName as Any,
                    "updatedAt": now
                ])

            #if DEBUG
            print("🔥 FloorRulesService: Updated existing rules")
            #endif
        } else {
            // Create new rules document
            let newRef = db.collection("halls").document(hallId)
                .collection("floor_rules").document()

            try await newRef.setData([
                "raUid": userId,
                "raName": raName as Any,
                "title": title,
                "rules": rules.map { rule in
                    [
                        "id": rule.id,
                        "text": rule.text,
                        "order": rule.order,
                        "category": rule.category as Any
                    ]
                },
                "expectations": expectations,
                "floor": floor as Any,
                "wing": wing as Any,
                "isPublished": false,
                "publishedAt": NSNull(),
                "createdAt": now,
                "updatedAt": now
            ])

            #if DEBUG
            print("🔥 FloorRulesService: Created new rules document")
            #endif
        }
    }

    // MARK: - RA: Publish/Unpublish Rules

    func publishRules(hallId: String) async throws {
        guard let rulesId = myRules?.id else {
            throw NSError(domain: "FloorRulesService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No rules to publish"])
        }

        try await db.collection("halls").document(hallId)
            .collection("floor_rules").document(rulesId)
            .updateData([
                "isPublished": true,
                "publishedAt": FieldValue.serverTimestamp(),
                "updatedAt": FieldValue.serverTimestamp()
            ])

        #if DEBUG
        print("🔥 FloorRulesService: Published rules")
        #endif
    }

    func unpublishRules(hallId: String) async throws {
        guard let rulesId = myRules?.id else {
            throw NSError(domain: "FloorRulesService", code: 404, userInfo: [NSLocalizedDescriptionKey: "No rules to unpublish"])
        }

        try await db.collection("halls").document(hallId)
            .collection("floor_rules").document(rulesId)
            .updateData([
                "isPublished": false,
                "updatedAt": FieldValue.serverTimestamp()
            ])

        #if DEBUG
        print("🔥 FloorRulesService: Unpublished rules")
        #endif
    }
}
