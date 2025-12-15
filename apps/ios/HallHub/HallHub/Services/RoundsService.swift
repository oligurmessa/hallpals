import Foundation
import FirebaseFirestore
import FirebaseAuth

/// Service for persisting rounds sessions to Firebase
/// Data goes to: /halls/{hallId}/rounds_sessions/{sessionId}
/// With subcollections: floor_visits/{visitId}/segments/{segmentId}
class RoundsService {
    static let shared = RoundsService()
    private let db = Firestore.firestore()

    private init() {}

    // MARK: - Save Completed Rounds Session

    /// Saves a completed rounds session to Firestore
    /// - Parameters:
    ///   - session: The completed RoundsSession
    ///   - hallId: The hall ID (e.g., "hall-001")
    /// - Returns: The Firestore document ID of the saved session
    @discardableResult
    func saveSession(_ session: RoundsSession, hallId: String) async throws -> String {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw RoundsServiceError.notAuthenticated
        }

        // Create session document data
        let sessionData: [String: Any] = [
            "userId": userId,
            "startTime": Timestamp(date: session.startTime),
            "endTime": Timestamp(date: session.endTime ?? Date()),
            "status": session.status.rawValue,
            "startingFloor": session.startingFloor,
            "totalSteps": session.totalSteps,
            "floorsVisited": session.floorsVisited,
            "walkingTime": session.walkingTime,
            "idleTime": session.idleTime,
            "isFullLoop": session.isFullLoop,
            "createdAt": FieldValue.serverTimestamp()
        ]

        // Create session document
        let sessionRef = db.collection("halls").document(hallId)
            .collection("rounds_sessions").document()

        // Use batch write to save session + floor visits + segments atomically
        let batch = db.batch()

        // 1. Set session document
        batch.setData(sessionData, forDocument: sessionRef)

        // 2. Add floor visits as subcollection
        for visit in session.floorVisits {
            let visitRef = sessionRef.collection("floor_visits").document()

            let visitData: [String: Any] = [
                "floorNumber": visit.floorNumber,
                "entryTime": Timestamp(date: visit.entryTime),
                "exitTime": visit.exitTime != nil ? Timestamp(date: visit.exitTime!) : NSNull(),
                "estimatedCoverage": visit.estimatedCoverage,
                "totalSteps": visit.totalSteps
            ]
            batch.setData(visitData, forDocument: visitRef)

            // 3. Add segments for each floor visit
            for segment in visit.segments {
                let segmentRef = visitRef.collection("segments").document()

                let segmentData: [String: Any] = [
                    "startTime": Timestamp(date: segment.startTime),
                    "endTime": Timestamp(date: segment.endTime),
                    "motionState": segment.motionState.rawValue,
                    "stepCount": segment.stepCount,
                    "floorNumber": segment.floorNumber,
                    "zone": segment.zone.rawValue,
                    "classification": segment.classification.rawValue,
                    "relativeAltitudeChange": segment.relativeAltitudeChange
                ]
                batch.setData(segmentData, forDocument: segmentRef)
            }
        }

        // Commit the batch
        try await batch.commit()

        #if DEBUG
        print("📍 RoundsService: Session saved successfully")
        print("   Path: halls/\(hallId)/rounds_sessions/\(sessionRef.documentID)")
        print("   Floor visits: \(session.floorVisits.count)")
        print("   Total segments: \(session.segments.count)")
        #endif

        return sessionRef.documentID
    }

    // MARK: - Fetch Session History

    /// Fetches recent rounds sessions for the current user
    /// - Parameters:
    ///   - hallId: The hall ID
    ///   - limit: Maximum number of sessions to fetch (default 10)
    /// - Returns: Array of session summaries
    func fetchRecentSessions(hallId: String, limit: Int = 10) async throws -> [RoundsSessionSummary] {
        guard let userId = Auth.auth().currentUser?.uid else {
            throw RoundsServiceError.notAuthenticated
        }

        let snapshot = try await db.collection("halls").document(hallId)
            .collection("rounds_sessions")
            .whereField("userId", isEqualTo: userId)
            .order(by: "startTime", descending: true)
            .limit(to: limit)
            .getDocuments()

        return snapshot.documents.compactMap { doc -> RoundsSessionSummary? in
            let data = doc.data()

            guard let startTime = (data["startTime"] as? Timestamp)?.dateValue(),
                  let endTime = (data["endTime"] as? Timestamp)?.dateValue(),
                  let statusRaw = data["status"] as? String,
                  let totalSteps = data["totalSteps"] as? Int,
                  let floorsVisited = data["floorsVisited"] as? [Int] else {
                return nil
            }

            return RoundsSessionSummary(
                id: doc.documentID,
                startTime: startTime,
                endTime: endTime,
                status: statusRaw,
                totalSteps: totalSteps,
                floorsVisited: floorsVisited
            )
        }
    }
}

// MARK: - Supporting Types

enum RoundsServiceError: LocalizedError {
    case notAuthenticated
    case saveFailed(Error)

    var errorDescription: String? {
        switch self {
        case .notAuthenticated:
            return "User not authenticated"
        case .saveFailed(let error):
            return "Failed to save session: \(error.localizedDescription)"
        }
    }
}

/// Lightweight summary for displaying session history
struct RoundsSessionSummary: Identifiable {
    let id: String
    let startTime: Date
    let endTime: Date
    let status: String
    let totalSteps: Int
    let floorsVisited: [Int]

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return "\(minutes)m \(seconds)s"
    }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: startTime)
    }
}
