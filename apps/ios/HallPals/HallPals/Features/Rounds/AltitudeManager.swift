import Foundation
import CoreMotion
import Combine

/// Manages barometric altitude tracking for floor change detection
@MainActor
final class AltitudeManager: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var relativeAltitude: Double = 0.0  // smoothed meters from start
    @Published private(set) var currentFloor: Int = 1
    @Published private(set) var floorChanges: [FloorChange] = []
    @Published private(set) var isAvailable: Bool = false
    @Published private(set) var error: String?

    // MARK: - Floor Change Event

    struct FloorChange: Identifiable {
        let id = UUID()
        let timestamp: Date
        let fromFloor: Int
        let toFloor: Int
        let altitudeChange: Double
        let direction: Direction

        enum Direction: String {
            case up = "Ascended"
            case down = "Descended"
        }
    }

    // MARK: - Private Properties

    private let altimeter = CMAltimeter()

    private var baselineAltitude: Double = 0.0
    private var startingFloor: Int = 1

    // For noise-robust detection
    private var lastSmoothedAltitude: Double?
    private var previousSmoothedAltitude: Double?
    private var lastUpdateTime: Date?
    private var lastFloorEventTime: Date?

    // "Climb session" state
    private var currentClimbDirection: FloorChange.Direction?
    private var climbStartAltitude: Double?
    private var climbStartTime: Date?

    // For legacy support / analysis
    private var lastSignificantAltitude: Double = 0.0

    // MARK: - Computed Properties

    var altimeterAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    var totalFloorsAscended: Int {
        floorChanges.filter { $0.direction == .up }.count
    }

    var totalFloorsDescended: Int {
        floorChanges.filter { $0.direction == .down }.count
    }

    // MARK: - Initialization

    init() {
        isAvailable = altimeterAvailable
    }

    // MARK: - Start Tracking

    func startTracking(startingFloor: Int = 1) {
        guard altimeterAvailable else {
            error = "Barometric altitude is not available on this device."
            return
        }

        self.startingFloor = startingFloor
        self.currentFloor = startingFloor
        self.floorChanges = []
        self.relativeAltitude = 0.0
        self.baselineAltitude = 0.0
        self.lastSignificantAltitude = 0.0

        self.lastSmoothedAltitude = nil
        self.previousSmoothedAltitude = nil
        self.lastUpdateTime = nil
        self.lastFloorEventTime = nil
        self.currentClimbDirection = nil
        self.climbStartAltitude = nil
        self.climbStartTime = nil

        error = nil

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, altimeterError in
            Task { @MainActor in
                guard let self = self else { return }

                if let altimeterError = altimeterError {
                    self.error = altimeterError.localizedDescription
                    return
                }

                if let data = data {
                    self.processAltitudeUpdate(data)
                }
            }
        }
    }

    // MARK: - Stop Tracking

    func stopTracking() {
        altimeter.stopRelativeAltitudeUpdates()
    }

    // MARK: - Reset Baseline

    func resetBaseline() {
        baselineAltitude = relativeAltitude
        lastSignificantAltitude = relativeAltitude
        climbStartAltitude = relativeAltitude
        climbStartTime = Date()
    }

    // MARK: - Manual Floor Setting

    func setCurrentFloor(_ floor: Int) {
        currentFloor = max(1, floor)
        startingFloor = currentFloor
        resetBaseline()
    }

    // MARK: - Private Methods

    private func processAltitudeUpdate(_ data: CMAltitudeData) {
        let rawAltitude = data.relativeAltitude.doubleValue
        let now = Date()

        // 1. Low-pass filter to reduce noise
        let smoothed: Double
        if let last = lastSmoothedAltitude {
            let alpha = FloorTransitionConfig.lowPassAlpha
            smoothed = last + alpha * (rawAltitude - last)
        } else {
            smoothed = rawAltitude
        }

        previousSmoothedAltitude = lastSmoothedAltitude ?? smoothed
        lastSmoothedAltitude = smoothed

        // Expose smoothed altitude
        relativeAltitude = smoothed

        // Initialize baseline on first reading
        if lastUpdateTime == nil {
            lastUpdateTime = now
            baselineAltitude = smoothed
            lastSignificantAltitude = smoothed
            climbStartAltitude = smoothed
            climbStartTime = now
            return
        }

        guard let previous = previousSmoothedAltitude,
              let lastTime = lastUpdateTime else {
            lastUpdateTime = now
            return
        }

        let dt = now.timeIntervalSince(lastTime)
        lastUpdateTime = now
        guard dt > 0 else { return }

        let verticalSpeed = (smoothed - previous) / dt

        // 2. Ignore tiny speed (barometer drift / micro-noise)
        if abs(verticalSpeed) < FloorTransitionConfig.minVerticalSpeed {
            // If we were mid-climb and it died before threshold, reset climb state
            if currentClimbDirection != nil {
                currentClimbDirection = nil
                climbStartAltitude = smoothed
                climbStartTime = now
            }
            return
        }

        // 3. Enforce minimum time between floor events
        if let lastEvent = lastFloorEventTime,
           now.timeIntervalSince(lastEvent) < FloorTransitionConfig.minTimeBetweenFloorEvents {
            // Still update climb baseline so we do not accumulate stale delta
            if currentClimbDirection == nil {
                climbStartAltitude = smoothed
                climbStartTime = now
            }
            return
        }

        // 4. Determine direction for this climb session
        let direction: FloorChange.Direction = verticalSpeed > 0 ? .up : .down

        if currentClimbDirection == nil || currentClimbDirection != direction {
            // New climb session
            currentClimbDirection = direction
            climbStartAltitude = smoothed
            climbStartTime = now
            return
        }

        guard let startAltitude = climbStartAltitude else {
            climbStartAltitude = smoothed
            climbStartTime = now
            return
        }

        let altitudeDelta = smoothed - startAltitude

        switch direction {
        case .up:
            if altitudeDelta >= FloorTransitionConfig.floorChangeThreshold {
                registerFloorChange(direction: .up,
                                    altitudeChange: altitudeDelta,
                                    at: now)
            }
        case .down:
            if altitudeDelta <= -FloorTransitionConfig.floorChangeThreshold {
                registerFloorChange(direction: .down,
                                    altitudeChange: altitudeDelta,
                                    at: now)
            }
        }
    }

    private func registerFloorChange(direction: FloorChange.Direction,
                                     altitudeChange: Double,
                                     at timestamp: Date) {
        let previousFloor = currentFloor
        let floorDelta = direction == .up ? 1 : -1

        currentFloor = max(1, previousFloor + floorDelta)

        let change = FloorChange(
            timestamp: timestamp,
            fromFloor: previousFloor,
            toFloor: currentFloor,
            altitudeChange: altitudeChange,
            direction: direction
        )

        floorChanges.append(change)

        lastSignificantAltitude = relativeAltitude
        lastFloorEventTime = timestamp

        // Prepare for a possible second floor in the same climb
        climbStartAltitude = relativeAltitude
        climbStartTime = timestamp
    }

    // MARK: - Analysis Methods

    func estimateFloorFromAltitude(_ altitude: Double) -> Int {
        let floorsFromStart = Int(
            round((altitude - baselineAltitude) / FloorTransitionConfig.metersPerFloor)
        )
        return max(1, startingFloor + floorsFromStart)
    }

    func getFloorSequence() -> [Int] {
        var sequence: [Int] = [startingFloor]
        for change in floorChanges {
            if sequence.last != change.toFloor {
                sequence.append(change.toFloor)
            }
        }
        return sequence
    }

    func getFloorSequenceString() -> String {
        let sequence = getFloorSequence()
        guard !sequence.isEmpty else { return "None" }
        return sequence.map { String($0) }.joined(separator: " → ")
    }
}
