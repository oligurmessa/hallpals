import Foundation
import CoreMotion
import Combine

/// Manages CoreMotion services for step counting and activity detection
@MainActor
final class MotionManager: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var currentStepCount: Int = 0
    @Published private(set) var currentMotionState: MotionState = .unknown
    @Published private(set) var isWalking: Bool = false
    @Published private(set) var isAuthorized: Bool = false
    @Published private(set) var authorizationError: String?
    @Published private(set) var currentCadence: Double = 0 // steps per minute

    // MARK: - Private Properties

    private let pedometer = CMPedometer()
    private let activityManager = CMMotionActivityManager()
    private var sessionStartDate: Date?
    private var lastStepCount: Int = 0
    private var cadenceTimer: Timer?

    // MARK: - Computed Properties

    var isPedometerAvailable: Bool {
        CMPedometer.isStepCountingAvailable()
    }

    var isActivityTrackingAvailable: Bool {
        CMMotionActivityManager.isActivityAvailable()
    }

    // MARK: - Initialization

    init() {
        checkAuthorization()
    }

    // MARK: - Authorization

    private func checkAuthorization() {
        // Check pedometer authorization
        switch CMPedometer.authorizationStatus() {
        case .authorized:
            isAuthorized = true
        case .denied, .restricted:
            isAuthorized = false
            authorizationError = "Motion tracking permission denied. Please enable in Settings."
        case .notDetermined:
            // Will be determined when we start tracking
            isAuthorized = true // Optimistically assume permission will be granted
        @unknown default:
            isAuthorized = false
        }
    }

    // MARK: - Start Tracking

    func startTracking() {
        guard isPedometerAvailable else {
            authorizationError = "Step counting is not available on this device."
            return
        }

        sessionStartDate = Date()
        currentStepCount = 0
        lastStepCount = 0

        // Start pedometer updates
        pedometer.startUpdates(from: sessionStartDate!) { [weak self] data, error in
            Task { @MainActor in
                guard let self = self else { return }

                if let error = error {
                    self.authorizationError = error.localizedDescription
                    return
                }

                if let data = data {
                    let newStepCount = data.numberOfSteps.intValue
                    self.currentStepCount = newStepCount

                    // Calculate cadence if available
                    if let cadence = data.currentCadence {
                        self.currentCadence = cadence.doubleValue * 60 // Convert to steps/min
                    }
                }
            }
        }

        // Start activity updates
        if isActivityTrackingAvailable {
            activityManager.startActivityUpdates(to: .main) { [weak self] activity in
                Task { @MainActor in
                    guard let self = self, let activity = activity else { return }
                    self.updateMotionState(from: activity)
                }
            }
        }

        // Start cadence calculation timer as backup
        startCadenceTimer()
    }

    // MARK: - Stop Tracking

    func stopTracking() {
        pedometer.stopUpdates()
        activityManager.stopActivityUpdates()
        cadenceTimer?.invalidate()
        cadenceTimer = nil
        sessionStartDate = nil
    }

    // MARK: - Query Steps for Time Range

    func querySteps(from start: Date, to end: Date) async -> Int {
        guard isPedometerAvailable else { return 0 }

        return await withCheckedContinuation { continuation in
            pedometer.queryPedometerData(from: start, to: end) { data, _ in
                let steps = data?.numberOfSteps.intValue ?? 0
                continuation.resume(returning: steps)
            }
        }
    }

    // MARK: - Private Methods

    private func updateMotionState(from activity: CMMotionActivity) {
        if activity.walking {
            currentMotionState = .walking
            isWalking = true
        } else if activity.stationary {
            currentMotionState = .stationary
            isWalking = false
        } else if activity.running {
            // Treat running as walking for our purposes
            currentMotionState = .walking
            isWalking = true
        } else {
            currentMotionState = .idle
            isWalking = false
        }
    }

    private func startCadenceTimer() {
        // Update cadence every 2 seconds based on step delta for more responsive detection
        cadenceTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                let stepDelta = self.currentStepCount - self.lastStepCount
                // Steps in 2 seconds -> steps per minute
                let calculatedCadence = Double(stepDelta) * 30.0
                self.currentCadence = calculatedCadence
                self.lastStepCount = self.currentStepCount

                // Use cadence as primary walking detection (more reliable than activity manager)
                if calculatedCadence >= FloorTransitionConfig.walkingCadenceThreshold {
                    self.currentMotionState = .walking
                    self.isWalking = true
                } else if calculatedCadence > 0 {
                    // Some movement but below walking threshold
                    self.currentMotionState = .walking
                    self.isWalking = true
                } else {
                    // No steps in the interval
                    self.currentMotionState = .idle
                    self.isWalking = false
                }
            }
        }
    }

    // MARK: - Movement Analysis

    func analyzeMovementPattern(steps: Int, duration: TimeInterval) -> SegmentClassification {
        guard duration > 0 else { return .transitioning }

        let stepsPerMinute = Double(steps) / (duration / 60)

        // Determine classification based on movement pattern
        if steps < FloorTransitionConfig.minimumWalkingSteps {
            return .idlePause
        } else if duration >= FloorTransitionConfig.hallwayCoverageDuration
                    && stepsPerMinute >= FloorTransitionConfig.walkingCadenceThreshold {
            return .hallwayCoverage
        } else if stepsPerMinute >= FloorTransitionConfig.walkingCadenceThreshold {
            return .transitioning
        } else {
            return .idlePause
        }
    }

    func estimateCoverage(steps: Int, duration: TimeInterval) -> Double {
        // Estimate coverage based on steps using config constant
        let expected = FloorTransitionConfig.expectedStepsPerFloor
        let stepsRatio = min(Double(steps) / expected, 1.0)
        return stepsRatio
    }

    func inferZone(steps: Int, duration: TimeInterval, isAfterFloorChange: Bool) -> FloorZone {
        // Simple heuristic for zone inference:
        // - If just after floor change with few steps -> stairwell
        // - Longer walks -> alternate between east/west wing assumption

        if isAfterFloorChange && duration < 20 {
            return .stairwell
        }

        // For now, we can't determine east/west without additional data
        // Could be enhanced with compass heading in future versions
        if steps > FloorTransitionConfig.minimumWalkingSteps {
            // Alternate based on time in session (simple heuristic)
            let minutes = Int(duration) / 60
            return minutes % 2 == 0 ? .eastWing : .westWing
        }

        return .unknown
    }
}
