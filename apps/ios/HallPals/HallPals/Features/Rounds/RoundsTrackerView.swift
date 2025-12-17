import SwiftUI

struct RoundsTrackerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var viewModel: RoundsViewModel
    @State private var showingCancelAlert = false

    private let defaultStartingFloor = 1

    init() {
        // Get hallId from UserManager, default to empty string if not assigned
        let hallId = UserManager.shared.currentUser?.hallId ?? ""
        _viewModel = StateObject(wrappedValue: RoundsViewModel(hallId: hallId))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()

                if viewModel.isTracking {
                    trackingContent
                } else {
                    startPrompt
                }

                // Floor change toast
                if let direction = viewModel.lastFloorChangeDirection {
                    floorChangeToast(direction: direction)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        if viewModel.isTracking {
                            showingCancelAlert = true
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.secondary)
                    }
                }

                ToolbarItem(placement: .principal) {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(viewModel.isPaused ? Color.orange : Color.green)
                            .frame(width: 8, height: 8)
                        Text(viewModel.formattedElapsedTime)
                            .font(.system(size: 17, weight: .semibold, design: .monospaced))
                            .foregroundColor(.primary)
                    }
                }
            }
            .alert("Cancel Rounds?", isPresented: $showingCancelAlert) {
                Button("Keep Going", role: .cancel) { }
                Button("Cancel Rounds", role: .destructive) {
                    viewModel.cancelRounds()
                    dismiss()
                }
            } message: {
                Text("This will discard your current rounds session.")
            }
            .fullScreenCover(isPresented: $viewModel.showingSummary) {
                RoundsSummaryView(summary: viewModel.summary) {
                    dismiss()
                }
            }
            .onAppear {
                if !viewModel.isTracking {
                    viewModel.startRounds(startingFloor: defaultStartingFloor)
                }
            }
        }
    }

    // MARK: - Floor Change Toast

    private func floorChangeToast(direction: RoundsViewModel.FloorChangeDirection) -> some View {
        VStack {
            HStack(spacing: 8) {
                Image(systemName: direction == .up ? "arrow.up.circle.fill" : "arrow.down.circle.fill")
                    .font(.system(size: 16))
                    .foregroundColor(direction == .up ? .green : .blue)
                Text(direction == .up ? "Moved Up" : "Moved Down")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.primary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(20)
            .padding(.top, 8)

            Spacer()
        }
        .transition(.move(edge: .top).combined(with: .opacity))
        .animation(.spring(response: 0.4, dampingFraction: 0.8), value: direction)
    }

    // MARK: - Start Prompt

    private var startPrompt: some View {
        VStack(spacing: 20) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 80, height: 80)
                ProgressView()
                    .scaleEffect(1.3)
                    .tint(.blue)
            }
            Text("Starting Rounds...")
                .font(.system(size: 17))
                .foregroundColor(.secondary)
        }
    }

    // MARK: - Tracking Content

    private var trackingContent: some View {
        VStack(spacing: 0) {
            Spacer()

            // Current floor indicator
            currentFloorBadge
                .padding(.bottom, 24)

            // Progress Ring
            progressRing

            Spacer()

            // Stats card
            statsCard
                .padding(.horizontal, 20)
                .padding(.bottom, 20)

            // Action buttons
            actionButtons
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
        }
    }

    // MARK: - Current Floor Badge

    private var currentFloorBadge: some View {
        HStack(spacing: 8) {
            Image(systemName: "building.2")
                .font(.system(size: 14))
            Text("Floor \(viewModel.currentFloor)")
                .font(.system(size: 15, weight: .semibold))
        }
        .foregroundColor(.blue)
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(Color.blue.opacity(0.1))
        .cornerRadius(20)
    }

    // MARK: - Progress Ring

    private var progressRing: some View {
        let completionThreshold = Double(FloorTransitionConfig.stepsPerFloorCompletion)
        let steps = Double(viewModel.stepsOnCurrentFloor)
        let progress = min(steps / completionThreshold, 1.0)
        let targetSteps = Int(completionThreshold)

        return VStack(spacing: 32) {
            ZStack {
                // Track
                Circle()
                    .stroke(Color(UIColor.systemGray5), lineWidth: 14)

                // Progress
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(
                        Color.blue,
                        style: StrokeStyle(lineWidth: 14, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.easeOut(duration: 0.3), value: progress)

                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(progress * 100))%")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)

                    Text("\(viewModel.stepsOnCurrentFloor) / \(targetSteps)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)

                    Text("steps on floor")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
            }
            .frame(width: 240, height: 240)

            // Floors completed
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                Text("\(viewModel.floorsCompleted) floor\(viewModel.floorsCompleted == 1 ? "" : "s") completed")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 0) {
            statItem(
                icon: "figure.walk",
                value: "\(viewModel.currentSteps)",
                label: "Total Steps"
            )

            Divider()
                .frame(height: 40)

            statItem(
                icon: "arrow.up.arrow.down",
                value: "\(viewModel.floorsCompleted)",
                label: "Floors Done"
            )

            Divider()
                .frame(height: 40)

            statItem(
                icon: "waveform.path",
                value: statusLabel,
                label: "Activity"
            )
        }
        .padding(.vertical, 16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func statItem(icon: String, value: String, label: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.secondary)

            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.primary)

            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private var statusLabel: String {
        switch viewModel.currentMotionState {
        case .walking: return "Walking"
        case .idle, .stationary: return "Idle"
        case .unknown: return "—"
        }
    }

    // MARK: - Action Buttons

    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Pause/Resume
            Button {
                if viewModel.isPaused {
                    viewModel.resumeRounds()
                } else {
                    viewModel.pauseRounds()
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: viewModel.isPaused ? "play.fill" : "pause.fill")
                        .font(.system(size: 14))
                    Text(viewModel.isPaused ? "Resume" : "Pause")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.primary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(14)
            }

            // End Rounds
            Button {
                viewModel.endRounds()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                    Text("End Rounds")
                        .font(.system(size: 16, weight: .semibold))
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Color.blue)
                .cornerRadius(14)
            }
        }
    }
}

#Preview {
    RoundsTrackerView()
}
