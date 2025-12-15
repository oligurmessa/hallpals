import Foundation
import Combine

/// Main view model for managing rounds tracking session
@MainActor
final class RoundsViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published private(set) var session: RoundsSession
    @Published private(set) var isTracking: Bool = false
    @Published private(set) var isPaused: Bool = false
    @Published private(set) var elapsedTime: TimeInterval = 0
    @Published private(set) var currentSegment: MovementSegment?
    @Published var showingSummary: Bool = false
    @Published var errorMessage: String?
    @Published private(set) var lastFloorChangeDirection: FloorChangeDirection? = nil
    @Published private(set) var floorsCompleted: Int = 0
    @Published private(set) var stepsOnCurrentFloor: Int = 0
    @Published private(set) var isSaving: Bool = false
    @Published private(set) var savedSessionId: String?

    enum FloorChangeDirection {
        case up, down
    }

    // MARK: - Managers

    let motionManager: MotionManager
    let altitudeManager: AltitudeManager

    // MARK: - Private Properties

    private var timer: Timer?
    private var segmentTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var segmentStartTime: Date?
    private var segmentStartSteps: Int = 0
    private var lastFloor: Int = 1
    private var recentFloorChange: Bool = false
    private var floorStartStepCount: Int = 0
    private let hallId: String

    // MARK: - Computed Properties

    var formattedElapsedTime: String {
        let hours = Int(elapsedTime) / 3600
        let minutes = (Int(elapsedTime) % 3600) / 60
        let seconds = Int(elapsedTime) % 60

        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        }
        return String(format: "%02d:%02d", minutes, seconds)
    }

    var currentSteps: Int {
        motionManager.currentStepCount
    }

    var currentMotionState: MotionState {
        motionManager.currentMotionState
    }

    var currentFloor: Int {
        altitudeManager.currentFloor
    }

    var floorsVisited: [Int] {
        session.floorsVisited
    }

    var summary: RoundsSummary {
        RoundsSummary(session: session)
    }

    // MARK: - Initialization

    init(
        motionManager: MotionManager? = nil,
        altitudeManager: AltitudeManager? = nil,
        hallId: String = "hall-001"
    ) {
        self.motionManager = motionManager ?? MotionManager()
        self.altitudeManager = altitudeManager ?? AltitudeManager()
        self.hallId = hallId
        self.session = RoundsSession()

        setupObservers()
    }

    // MARK: - Setup

    private func setupObservers() {
        // Observe floor changes from altitude manager
        altitudeManager.$currentFloor
            .dropFirst()
            .sink { [weak self] newFloor in
                self?.handleFloorChange(to: newFloor)
            }
            .store(in: &cancellables)

        // Observe motion state changes
        motionManager.$currentMotionState
            .dropFirst()
            .sink { [weak self] newState in
                self?.handleMotionStateChange(to: newState)
            }
            .store(in: &cancellables)

        // Observe step count for session total and per-floor tracking
        motionManager.$currentStepCount
            .sink { [weak self] steps in
                guard let self = self else { return }
                self.session.totalSteps = steps
                self.updateStepsForCurrentFloor(totalSteps: steps)
            }
            .store(in: &cancellables)
    }

    private func updateStepsForCurrentFloor(totalSteps: Int) {
        // Steps taken since we started this floor
        let delta = max(0, totalSteps - floorStartStepCount)
        stepsOnCurrentFloor = delta
    }

    // MARK: - Session Control

    func startRounds(startingFloor: Int = 1) {
        // Create new session
        session = RoundsSession(
            startTime: Date(),
            status: .inProgress,
            currentFloor: startingFloor,
            startingFloor: startingFloor
        )

        lastFloor = startingFloor
        isTracking = true
        isPaused = false
        elapsedTime = 0
        errorMessage = nil

        // Initialize per-floor tracking
        floorsCompleted = 0
        stepsOnCurrentFloor = 0
        floorStartStepCount = motionManager.currentStepCount

        // Start managers
        motionManager.startTracking()
        altitudeManager.startTracking(startingFloor: startingFloor)

        // Start elapsed time timer
        startTimer()

        // Start first segment
        startNewSegment()

        // Create initial floor visit
        let initialVisit = FloorVisit(floorNumber: startingFloor)
        session.floorVisits.append(initialVisit)
    }

    func pauseRounds() {
        guard isTracking, !isPaused else { return }

        isPaused = true
        session.status = .paused
        timer?.invalidate()
        segmentTimer?.invalidate()

        // Finalize current segment
        finalizeCurrentSegment()
    }

    func resumeRounds() {
        guard isTracking, isPaused else { return }

        isPaused = false
        session.status = .inProgress
        startTimer()
        startNewSegment()
    }

    func endRounds() {
        guard isTracking else { return }

        // Finalize current segment
        finalizeCurrentSegment()

        // Finalize current floor visit
        if var lastVisit = session.floorVisits.last {
            lastVisit.exitTime = Date()
            session.floorVisits[session.floorVisits.count - 1] = lastVisit
        }

        // Update session
        session.endTime = Date()
        session.status = .completed

        // Stop everything
        stopTracking()

        // Save to Firebase
        saveSessionToFirebase()

        // Show summary
        showingSummary = true
    }

    private func saveSessionToFirebase() {
        isSaving = true
        savedSessionId = nil

        Task {
            do {
                let sessionId = try await RoundsService.shared.saveSession(session, hallId: hallId)
                await MainActor.run {
                    self.savedSessionId = sessionId
                    self.isSaving = false
                    #if DEBUG
                    print("✅ Rounds session saved with ID: \(sessionId)")
                    #endif
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.errorMessage = "Failed to save rounds: \(error.localizedDescription)"
                    #if DEBUG
                    print("❌ Failed to save rounds session: \(error)")
                    #endif
                }
            }
        }
    }

    func cancelRounds() {
        session.status = .cancelled
        session.endTime = Date()
        stopTracking()
    }

    // MARK: - Manual Floor Correction (for edge cases)

    func adjustFloor(to floor: Int) {
        altitudeManager.setCurrentFloor(floor)
        session.currentFloor = floor

        // Handle as floor change if different
        if floor != lastFloor {
            handleFloorChange(to: floor)
        }
    }

    // MARK: - Private Methods

    private func startTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.elapsedTime += 1
            }
        }
    }

    private func stopTracking() {
        isTracking = false
        isPaused = false

        timer?.invalidate()
        timer = nil

        segmentTimer?.invalidate()
        segmentTimer = nil

        motionManager.stopTracking()
        altitudeManager.stopTracking()
    }

    private func startNewSegment() {
        segmentStartTime = Date()
        segmentStartSteps = motionManager.currentStepCount

        currentSegment = MovementSegment(
            startTime: Date(),
            motionState: motionManager.currentMotionState,
            floorNumber: altitudeManager.currentFloor
        )

        // Timer to periodically finalize segments (every 30 seconds)
        segmentTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.finalizeCurrentSegment()
                self?.startNewSegment()
            }
        }
    }

    private func finalizeCurrentSegment() {
        guard var segment = currentSegment,
              let startTime = segmentStartTime else { return }

        segmentTimer?.invalidate()

        let endTime = Date()
        let duration = endTime.timeIntervalSince(startTime)
        let steps = motionManager.currentStepCount - segmentStartSteps

        // Update segment
        segment.endTime = endTime
        segment.stepCount = steps
        segment.motionState = motionManager.currentMotionState
        segment.floorNumber = altitudeManager.currentFloor
        segment.relativeAltitudeChange = altitudeManager.relativeAltitude

        // Classify the segment
        segment.classification = motionManager.analyzeMovementPattern(
            steps: steps,
            duration: duration
        )

        // Infer zone
        segment.zone = motionManager.inferZone(
            steps: steps,
            duration: duration,
            isAfterFloorChange: recentFloorChange
        )

        // Add to session
        session.segments.append(segment)

        // Add to current floor visit
        if var currentVisit = session.floorVisits.last {
            currentVisit.segments.append(segment)
            currentVisit.estimatedCoverage = motionManager.estimateCoverage(
                steps: currentVisit.totalSteps,
                duration: currentVisit.duration
            )
            session.floorVisits[session.floorVisits.count - 1] = currentVisit
        }

        currentSegment = nil
        recentFloorChange = false
    }

    private func handleFloorChange(to newFloor: Int) {
        guard isTracking, !isPaused else { return }

        // Determine direction
        let direction: FloorChangeDirection = newFloor > lastFloor ? .up : .down
        lastFloorChangeDirection = direction

        // Auto-clear the direction indicator after animation (linger for 3 seconds)
        Task {
            try? await Task.sleep(nanoseconds: 3_000_000_000) // 3 seconds
            await MainActor.run {
                if self.lastFloorChangeDirection == direction {
                    self.lastFloorChangeDirection = nil
                }
            }
        }

        // Determine if the floor we are leaving should count as completed
        if stepsOnCurrentFloor >= FloorTransitionConfig.stepsPerFloorCompletion {
            floorsCompleted += 1
        }

        // Reset per-floor step tracking for the next floor
        floorStartStepCount = motionManager.currentStepCount
        stepsOnCurrentFloor = 0

        // Finalize current segment as stairwell traversal
        if var segment = currentSegment {
            segment.classification = .stairwellTraversal
            segment.zone = .stairwell
        }
        finalizeCurrentSegment()

        // Finalize current floor visit
        if var lastVisit = session.floorVisits.last {
            lastVisit.exitTime = Date()
            session.floorVisits[session.floorVisits.count - 1] = lastVisit
        }

        // Create new floor visit
        let newVisit = FloorVisit(floorNumber: newFloor)
        session.floorVisits.append(newVisit)

        // Update session
        session.currentFloor = newFloor
        lastFloor = newFloor
        recentFloorChange = true

        // Start new segment for new floor
        startNewSegment()
    }

    private func handleMotionStateChange(to newState: MotionState) {
        guard isTracking, !isPaused else { return }

        // If significant state change, consider finalizing segment
        if let segment = currentSegment,
           segment.motionState != newState,
           segment.motionState != .unknown {

            let duration = Date().timeIntervalSince(segment.startTime)

            // Only create new segment if meaningful duration has passed
            if duration > 10 {
                finalizeCurrentSegment()
                startNewSegment()
            }
        }
    }

    // MARK: - Session History

    func loadRecentSessions() async -> [RoundsSessionSummary] {
        do {
            return try await RoundsService.shared.fetchRecentSessions(hallId: hallId)
        } catch {
            #if DEBUG
            print("❌ Failed to load recent sessions: \(error)")
            #endif
            return []
        }
    }
}
