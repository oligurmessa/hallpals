import SwiftUI

struct RATasksView: View {
    @StateObject private var bulletinService = BulletinService.shared
    @StateObject private var userManager = UserManager.shared
    @State private var showingCompletedTasks = false

    private var hallId: String {
        userManager.hallId ?? ""
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Content
                if bulletinService.isLoading {
                    loadingView
                } else if bulletinService.tasks.isEmpty {
                    emptyStateView
                        .padding(.horizontal, 20)
                } else {
                    // Stats card
                    statsCard
                        .padding(.horizontal, 20)

                    // Pending tasks
                    if !bulletinService.pendingTasks.isEmpty {
                        pendingTasksSection
                    }

                    // Completed tasks toggle
                    if !bulletinService.completedTasks.isEmpty {
                        completedTasksSection
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Tasks")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if !hallId.isEmpty {
                        bulletinService.startListening(hallId: hallId)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17))
                }
                .disabled(bulletinService.isLoading)
            }
        }
        .onAppear {
            if !hallId.isEmpty {
                bulletinService.startListening(hallId: hallId)
            }
        }
        .onDisappear {
            bulletinService.stopListening()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Tasks")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text("From hall staff")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading tasks...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State View

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle")
                .font(.system(size: 44))
                .foregroundColor(.green)

            Text("No Tasks Assigned")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            if let error = bulletinService.error {
                Text(error)
                    .font(.system(size: 14))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            } else {
                Text("You're all caught up! Check back later for new tasks.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                if !hallId.isEmpty {
                    bulletinService.startListening(hallId: hallId)
                }
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Stats Card

    private var statsCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text("\(bulletinService.pendingCount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(bulletinService.hasOverdueTasks ? .red : .blue)
                Text("Pending")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if bulletinService.highPriorityCount > 0 {
                Divider()
                    .frame(height: 30)

                VStack(spacing: 2) {
                    Text("\(bulletinService.highPriorityCount)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.red)
                    Text("High Priority")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(bulletinService.completedTasks.count)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.green)
                Text("Completed")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Pending Tasks Section

    private var pendingTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("To Do")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(bulletinService.pendingTasks.enumerated()), id: \.element.id) { index, task in
                    BulletinTaskRow(
                        task: task,
                        isLast: index == bulletinService.pendingTasks.count - 1
                    ) {
                        toggleTask(task)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Completed Tasks Section

    private var completedTasksSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showingCompletedTasks.toggle()
                }
            } label: {
                HStack {
                    Text("Completed (\(bulletinService.completedTasks.count))")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(.secondary)
                        .textCase(.uppercase)
                        .tracking(0.5)

                    Spacer()

                    Image(systemName: showingCompletedTasks ? "chevron.up" : "chevron.down")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 20)
            }

            if showingCompletedTasks {
                VStack(spacing: 0) {
                    ForEach(Array(bulletinService.completedTasks.enumerated()), id: \.element.id) { index, task in
                        BulletinTaskRow(
                            task: task,
                            isLast: index == bulletinService.completedTasks.count - 1
                        ) {
                            toggleTask(task)
                        }
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Toggle Task

    private func toggleTask(_ task: BulletinService.BulletinTask) {
        Task {
            do {
                let newStatus: BulletinService.BulletinTask.TaskStatus = task.isCompleted ? .pending : .completed
                try await bulletinService.updateStatus(
                    hallId: hallId,
                    taskId: task.id,
                    status: newStatus
                )
            } catch {
                #if DEBUG
                print("📋 TASKS: Error toggling task: \(error)")
                #endif
            }
        }
    }
}

// MARK: - Bulletin Task Row

struct BulletinTaskRow: View {
    let task: BulletinService.BulletinTask
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(alignment: .top, spacing: 12) {
                    // Checkbox
                    ZStack {
                        Circle()
                            .stroke(task.isCompleted ? Color.green : priorityColor, lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if task.isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }
                    .padding(.top, 2)

                    // Task details
                    VStack(alignment: .leading, spacing: 4) {
                        Text(task.title)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(task.isCompleted ? .secondary : .primary)
                            .strikethrough(task.isCompleted, color: .secondary)
                            .multilineTextAlignment(.leading)

                        if !task.description.isEmpty {
                            Text(task.description)
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                                .lineLimit(2)
                        }

                        HStack(spacing: 8) {
                            // Priority badge
                            if !task.isCompleted {
                                priorityBadge
                            }

                            // Deadline
                            if let deadlineText = task.deadlineText {
                                HStack(spacing: 4) {
                                    Image(systemName: "clock")
                                        .font(.system(size: 11))
                                    Text(deadlineText)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(task.isOverdue ? .red : (task.isDeadlineApproaching ? .orange : .secondary))
                            }

                            // Assignee
                            if !task.assignee.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "person")
                                        .font(.system(size: 11))
                                    Text(task.assignee)
                                        .font(.system(size: 12))
                                }
                                .foregroundColor(.secondary)
                            }
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .contentShape(Rectangle())
            }
            .buttonStyle(PlainButtonStyle())

            if !isLast {
                Divider()
                    .padding(.leading, 52)
            }
        }
    }

    private var priorityColor: Color {
        switch task.priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    private var priorityBadge: some View {
        Text(task.priority.rawValue.capitalized)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(priorityColor)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(priorityColor.opacity(0.15))
            .cornerRadius(4)
    }
}

#Preview {
    NavigationStack {
        RATasksView()
    }
}
