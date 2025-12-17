import Foundation

// MARK: - Motion State

enum MotionState: String, Codable {
    case idle = "Idle"
    case walking = "Walking"
    case stationary = "Stationary"
    case unknown = "Unknown"
}

// MARK: - Floor Zone (Wing/Area)

enum FloorZone: String, Codable, CaseIterable {
    case eastWing = "East Wing"
    case westWing = "West Wing"
    case stairwell = "Stairwell"
    case unknown = "Unknown"

    var icon: String {
        switch self {
        case .eastWing: return "arrow.right"
        case .westWing: return "arrow.left"
        case .stairwell: return "stairs"
        case .unknown: return "questionmark"
        }
    }
}

// MARK: - Segment Classification

enum SegmentClassification: String, Codable {
    case hallwayCoverage = "Hallway Coverage"
    case stairwellTraversal = "Stairwell Traversal"
    case idlePause = "Idle/Pause"
    case transitioning = "Transitioning"
}

// MARK: - Movement Segment

struct MovementSegment: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date
    var motionState: MotionState
    var stepCount: Int
    var floorNumber: Int
    var zone: FloorZone
    var classification: SegmentClassification
    var relativeAltitudeChange: Double // in meters

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date = Date(),
        motionState: MotionState = .unknown,
        stepCount: Int = 0,
        floorNumber: Int = 1,
        zone: FloorZone = .unknown,
        classification: SegmentClassification = .transitioning,
        relativeAltitudeChange: Double = 0.0
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.motionState = motionState
        self.stepCount = stepCount
        self.floorNumber = floorNumber
        self.zone = zone
        self.classification = classification
        self.relativeAltitudeChange = relativeAltitudeChange
    }

    var duration: TimeInterval {
        endTime.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        if minutes > 0 {
            return "\(minutes)m \(seconds)s"
        }
        return "\(seconds)s"
    }
}

// MARK: - Floor Visit

struct FloorVisit: Identifiable, Codable {
    let id: UUID
    let floorNumber: Int
    let entryTime: Date
    var exitTime: Date?
    var segments: [MovementSegment]
    var estimatedCoverage: Double // 0.0 to 1.0

    init(
        id: UUID = UUID(),
        floorNumber: Int,
        entryTime: Date = Date(),
        exitTime: Date? = nil,
        segments: [MovementSegment] = [],
        estimatedCoverage: Double = 0.0
    ) {
        self.id = id
        self.floorNumber = floorNumber
        self.entryTime = entryTime
        self.exitTime = exitTime
        self.segments = segments
        self.estimatedCoverage = estimatedCoverage
    }

    var duration: TimeInterval {
        let end = exitTime ?? Date()
        return end.timeIntervalSince(entryTime)
    }

    var totalSteps: Int {
        segments.reduce(0) { $0 + $1.stepCount }
    }

    var coverageDescription: String {
        switch estimatedCoverage {
        case 0..<0.3: return "Partial"
        case 0.3..<0.7: return "Moderate"
        case 0.7...1.0: return "Full"
        default: return "Unknown"
        }
    }
}

// MARK: - Rounds Session Status

enum RoundsSessionStatus: String, Codable {
    case notStarted = "Not Started"
    case inProgress = "In Progress"
    case paused = "Paused"
    case completed = "Completed"
    case cancelled = "Cancelled"
}

// MARK: - Rounds Session

struct RoundsSession: Identifiable, Codable {
    let id: UUID
    let startTime: Date
    var endTime: Date?
    var status: RoundsSessionStatus
    var segments: [MovementSegment]
    var floorVisits: [FloorVisit]
    var currentFloor: Int
    var startingFloor: Int
    var totalSteps: Int
    var baselineAltitude: Double? // Starting altitude reference

    init(
        id: UUID = UUID(),
        startTime: Date = Date(),
        endTime: Date? = nil,
        status: RoundsSessionStatus = .notStarted,
        segments: [MovementSegment] = [],
        floorVisits: [FloorVisit] = [],
        currentFloor: Int = 1,
        startingFloor: Int = 1,
        totalSteps: Int = 0,
        baselineAltitude: Double? = nil
    ) {
        self.id = id
        self.startTime = startTime
        self.endTime = endTime
        self.status = status
        self.segments = segments
        self.floorVisits = floorVisits
        self.currentFloor = currentFloor
        self.startingFloor = startingFloor
        self.totalSteps = totalSteps
        self.baselineAltitude = baselineAltitude
    }

    // MARK: - Computed Properties

    var duration: TimeInterval {
        let end = endTime ?? Date()
        return end.timeIntervalSince(startTime)
    }

    var formattedDuration: String {
        let hours = Int(duration) / 3600
        let minutes = (Int(duration) % 3600) / 60
        let seconds = Int(duration) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%d:%02d", minutes, seconds)
    }

    var floorsVisited: [Int] {
        Array(Set(floorVisits.map { $0.floorNumber })).sorted()
    }

    var floorSequence: String {
        guard !floorVisits.isEmpty else { return "None" }
        return floorVisits.map { String($0.floorNumber) }.joined(separator: " → ")
    }

    var walkingTime: TimeInterval {
        segments
            .filter { $0.motionState == .walking }
            .reduce(0) { $0 + $1.duration }
    }

    var idleTime: TimeInterval {
        segments
            .filter { $0.motionState == .idle || $0.motionState == .stationary }
            .reduce(0) { $0 + $1.duration }
    }

    var walkingPercentage: Double {
        guard duration > 0 else { return 0 }
        return (walkingTime / duration) * 100
    }

    var averageStepsPerMinute: Double {
        guard duration > 60 else { return Double(totalSteps) }
        return Double(totalSteps) / (duration / 60)
    }

    var isFullLoop: Bool {
        // A full loop means returning to starting floor after visiting others
        guard let lastVisit = floorVisits.last else { return false }
        return lastVisit.floorNumber == startingFloor && floorsVisited.count > 1
    }

    var overallCoverage: Double {
        guard !floorVisits.isEmpty else { return 0 }
        return floorVisits.reduce(0) { $0 + $1.estimatedCoverage } / Double(floorVisits.count)
    }

    var coverageDescription: String {
        switch overallCoverage {
        case 0..<0.3: return "Partial Coverage"
        case 0.3..<0.7: return "Moderate Coverage"
        case 0.7...1.0: return "Full Coverage"
        default: return "Unknown"
        }
    }
}

// MARK: - Rounds Summary

struct RoundsSummary {
    let session: RoundsSession

    var totalDuration: String {
        session.formattedDuration
    }

    var totalSteps: Int {
        session.totalSteps
    }

    var floorsVisitedCount: Int {
        session.floorsVisited.count
    }

    var floorSequence: String {
        session.floorSequence
    }

    var walkingTimeFormatted: String {
        let minutes = Int(session.walkingTime) / 60
        let seconds = Int(session.walkingTime) % 60
        return "\(minutes)m \(seconds)s"
    }

    var idleTimeFormatted: String {
        let minutes = Int(session.idleTime) / 60
        let seconds = Int(session.idleTime) % 60
        return "\(minutes)m \(seconds)s"
    }

    var isFullLoop: Bool {
        session.isFullLoop
    }

    var coverageLevel: String {
        session.coverageDescription
    }

    var floorCoverageDetails: [(floor: Int, coverage: String, steps: Int)] {
        session.floorVisits.map { visit in
            (floor: visit.floorNumber, coverage: visit.coverageDescription, steps: visit.totalSteps)
        }
    }
}

// MARK: - Floor Transition Detection Config

struct FloorTransitionConfig {
    /// Approximate height of one floor in meters (tune this per building)
    static let metersPerFloor: Double = 3.0

    /// Altitude change (meters) needed to confirm a floor change
    static let floorChangeThreshold: Double = 2.0

    /// Minimum vertical speed (m/s) to consider that we're actually climbing/descending,
    /// not just seeing barometer drift.
    static let minVerticalSpeed: Double = 0.04

    /// Minimum time between floor events to avoid rapid flapping on noise.
    static let minTimeBetweenFloorEvents: TimeInterval = 2.0

    /// Low-pass filter alpha for smoothing altitude [0, 1].
    /// Smaller = more smoothing, less noise, but more lag.
    static let lowPassAlpha: Double = 0.15

    // Minimum steps to consider as meaningful movement
    static let minimumWalkingSteps: Int = 10
    // Duration threshold for hallway coverage classification (seconds)
    static let hallwayCoverageDuration: TimeInterval = 30
    // Cadence threshold for walking detection (steps per minute)
    static let walkingCadenceThreshold: Double = 50

    /// Steps needed for a floor to count as "completed" for rounds
    static let stepsPerFloorCompletion: Int = 65

    /// Expected steps per floor for coverage calculations / analytics
    static let expectedStepsPerFloor: Double = 80
}
