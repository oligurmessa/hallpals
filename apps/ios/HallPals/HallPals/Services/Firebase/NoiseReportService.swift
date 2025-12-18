import Foundation

#if canImport(FirebaseFirestore)
import FirebaseFirestore
import FirebaseAuth
#endif

/// Service for RAs to view and manage noise reports from residents
/// Collection: /halls/{hallId}/noise_reports/{reportId}
@MainActor
final class NoiseReportService: ObservableObject {

    // MARK: - Singleton

    static let shared = NoiseReportService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?
    @Published private(set) var reports: [NoiseReport] = []

    private var listenerRegistration: Any?

    #if canImport(FirebaseFirestore)
    private let db = Firestore.firestore()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Noise Report Model

    struct NoiseReport: Identifiable, Equatable {
        let id: String
        let location: String
        let description: String?
        let urgency: Urgency
        let reportedBy: String
        let reporterName: String
        let status: ReportStatus
        let createdAt: Date
        let resolvedAt: Date?
        let resolvedBy: String?
        let raNote: String?

        var timeAgo: String {
            let interval = Date().timeIntervalSince(createdAt)
            if interval < 60 {
                return "Just now"
            } else if interval < 3600 {
                let mins = Int(interval / 60)
                return "\(mins)m ago"
            } else if interval < 86400 {
                let hours = Int(interval / 3600)
                return "\(hours)h ago"
            } else {
                let days = Int(interval / 86400)
                return "\(days)d ago"
            }
        }
    }

    enum Urgency: String, CaseIterable, Codable {
        case low = "low"
        case medium = "medium"
        case high = "high"

        var displayName: String {
            switch self {
            case .low: return "Low"
            case .medium: return "Medium"
            case .high: return "High"
            }
        }

        var color: String {
            switch self {
            case .low: return "green"
            case .medium: return "orange"
            case .high: return "red"
            }
        }
    }

    enum ReportStatus: String, Codable {
        case pending = "pending"
        case inProgress = "in_progress"
        case resolved = "resolved"

        var displayName: String {
            switch self {
            case .pending: return "Pending"
            case .inProgress: return "In Progress"
            case .resolved: return "Resolved"
            }
        }
    }

    // MARK: - Computed Properties

    var pendingCount: Int {
        reports.filter { $0.status == .pending }.count
    }

    var activeReports: [NoiseReport] {
        reports.filter { $0.status != .resolved }
    }

    var statusText: String {
        let pending = pendingCount
        if pending == 0 {
            return "No pending reports"
        } else if pending == 1 {
            return "1 pending report"
        } else {
            return "\(pending) pending reports"
        }
    }

    // MARK: - Listen to Reports (RA)

    #if canImport(FirebaseFirestore)
    func startListening(hallId: String) {
        stopListening()
        isLoading = true

        let query = db.collection("halls")
            .document(hallId)
            .collection("noise_reports")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)

        listenerRegistration = query.addSnapshotListener { [weak self] snapshot, error in
            guard let self = self else { return }
            self.isLoading = false

            if let error = error {
                self.error = error.localizedDescription
                #if DEBUG
                print("NOISE: Listen error - \(error.localizedDescription)")
                #endif
                return
            }

            guard let documents = snapshot?.documents else {
                self.reports = []
                return
            }

            self.reports = documents.compactMap { doc -> NoiseReport? in
                let data = doc.data()
                guard let location = data["location"] as? String,
                      let reportedBy = data["reportedBy"] as? String,
                      let reporterName = data["reporterName"] as? String,
                      let urgencyStr = data["urgency"] as? String,
                      let urgency = Urgency(rawValue: urgencyStr),
                      let statusStr = data["status"] as? String,
                      let status = ReportStatus(rawValue: statusStr),
                      let createdAt = (data["createdAt"] as? Timestamp)?.dateValue()
                else { return nil }

                return NoiseReport(
                    id: doc.documentID,
                    location: location,
                    description: data["description"] as? String,
                    urgency: urgency,
                    reportedBy: reportedBy,
                    reporterName: reporterName,
                    status: status,
                    createdAt: createdAt,
                    resolvedAt: (data["resolvedAt"] as? Timestamp)?.dateValue(),
                    resolvedBy: data["resolvedBy"] as? String,
                    raNote: data["raNote"] as? String
                )
            }

            #if DEBUG
            print("NOISE: Loaded \(self.reports.count) reports")
            #endif
        }
    }

    func stopListening() {
        if let listener = listenerRegistration as? ListenerRegistration {
            listener.remove()
        }
        listenerRegistration = nil
    }
    #endif

    // MARK: - Update Report Status (RA)

    #if canImport(FirebaseFirestore)
    func updateStatus(hallId: String, reportId: String, status: ReportStatus, note: String? = nil) async throws {
        guard let uid = Auth.auth().currentUser?.uid else {
            throw NSError(domain: "NoiseReportService", code: 401, userInfo: [NSLocalizedDescriptionKey: "Not authenticated"])
        }

        var updateData: [String: Any] = [
            "status": status.rawValue
        ]

        if status == .resolved {
            updateData["resolvedAt"] = FieldValue.serverTimestamp()
            updateData["resolvedBy"] = uid
        }

        if let note = note, !note.isEmpty {
            updateData["raNote"] = note
        }

        try await db.collection("halls")
            .document(hallId)
            .collection("noise_reports")
            .document(reportId)
            .updateData(updateData)

        #if DEBUG
        print("NOISE: Updated status to \(status.rawValue) for \(reportId)")
        #endif
    }
    #endif
}
