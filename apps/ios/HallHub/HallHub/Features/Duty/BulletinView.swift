import SwiftUI

struct BulletinView: View {
    @StateObject private var service = BulletinService.shared
    @State private var showingAddTask = false
    @State private var newTaskTitle = ""
    @State private var newTaskDeadline = Date()
    @State private var hasDeadline = true

    private let hallId = FirestoreService.devHallId

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Pending Tasks
                if !service.pendingTasks.isEmpty {
                    tasksSection(
                        title: "Pending",
                        tasks: service.pendingTasks,
                        emptyMessage: nil
                    )
                }

                // Completed Tasks
                if !service.completedTasks.isEmpty {
                    tasksSection(
                        title: "Completed",
                        tasks: service.completedTasks,
                        emptyMessage: nil
                    )
                }

                // Empty state
                if service.tasks.isEmpty && !service.isLoading {
                    emptyStateView
                        .padding(.horizontal, 20)
                }

                // Loading state
                if service.isLoading && service.tasks.isEmpty {
                    ProgressView()
                        .padding(.vertical, 40)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Bulletin Board")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    showingAddTask = true
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 17, weight: .medium))
                }
            }
        }
        .sheet(isPresented: $showingAddTask) {
            addTaskSheet
        }
        .onAppear {
            service.startListening(hallId: hallId)
        }
        .onDisappear {
            service.stopListening()
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 48, height: 48)
                    Image(systemName: "list.clipboard.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.blue)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Bulletin Tasks")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)

                    Text(service.statusText)
                        .font(.system(size: 14))
                        .foregroundColor(service.hasOverdueTasks ? .red : .secondary)
                }

                Spacer()

                if service.isSyncing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
        }
    }

    // MARK: - Tasks Section

    private func tasksSection(title: String, tasks: [BulletinService.FirebaseBulletinTask], emptyMessage: String?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(tasks.enumerated()), id: \.element.id) { index, task in
                    FirebaseBulletinTaskRow(
                        task: task,
                        isLast: index == tasks.count - 1,
                        onToggle: {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                toggleTask(task)
                            }
                        },
                        onDelete: {
                            withAnimation {
                                deleteTask(task)
                            }
                        }
                    )
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    private func toggleTask(_ task: BulletinService.FirebaseBulletinTask) {
        Task {
            try? await service.toggleCompletion(
                hallId: hallId,
                taskId: task.id,
                isCompleted: !task.isCompleted
            )
        }
    }

    private func deleteTask(_ task: BulletinService.FirebaseBulletinTask) {
        Task {
            try? await service.deleteTask(hallId: hallId, taskId: task.id)
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.blue.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.blue)
            }

            VStack(spacing: 4) {
                Text("All caught up!")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text("No bulletin tasks to complete")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Button {
                showingAddTask = true
            } label: {
                Text("Add Task")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.blue)
                    .cornerRadius(10)
            }
        }
        .padding(.vertical, 40)
    }

    // MARK: - Add Task Sheet

    private var addTaskSheet: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Task title", text: $newTaskTitle)
                }

                Section {
                    Toggle("Set deadline", isOn: $hasDeadline)

                    if hasDeadline {
                        DatePicker(
                            "Deadline",
                            selection: $newTaskDeadline,
                            in: Date()...,
                            displayedComponents: [.date, .hourAndMinute]
                        )
                    }
                }

                Section {
                    Button {
                        addNewTask()
                    } label: {
                        HStack {
                            Spacer()
                            Text("Add Task")
                                .font(.system(size: 17, weight: .semibold))
                            Spacer()
                        }
                    }
                    .disabled(newTaskTitle.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .navigationTitle("New Task")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        resetAddTaskForm()
                        showingAddTask = false
                    }
                }
            }
        }
        .presentationDetents([.medium])
    }

    private func addNewTask() {
        let title = newTaskTitle.trimmingCharacters(in: .whitespaces)
        guard !title.isEmpty else { return }

        Task {
            try? await service.createTask(
                hallId: hallId,
                title: title,
                deadline: hasDeadline ? newTaskDeadline : nil
            )
        }

        resetAddTaskForm()
        showingAddTask = false
    }

    private func resetAddTaskForm() {
        newTaskTitle = ""
        newTaskDeadline = Date()
        hasDeadline = true
    }
}

// MARK: - Firebase Bulletin Task Row

struct FirebaseBulletinTaskRow: View {
    let task: BulletinService.FirebaseBulletinTask
    let isLast: Bool
    let onToggle: () -> Void
    let onDelete: () -> Void

    @State private var showingDeleteConfirm = false

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Checkbox
                Button(action: onToggle) {
                    Image(systemName: task.isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 24))
                        .foregroundColor(task.isCompleted ? .green : (task.isOverdue ? .red : .gray))
                }

                // Task details
                VStack(alignment: .leading, spacing: 4) {
                    Text(task.title)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(task.isCompleted ? .secondary : .primary)
                        .strikethrough(task.isCompleted)

                    if let deadlineText = task.deadlineText {
                        HStack(spacing: 4) {
                            Image(systemName: task.isOverdue ? "exclamationmark.circle.fill" : "clock")
                                .font(.system(size: 12))
                            Text(deadlineText)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(deadlineColor)
                    }

                    if task.isCompleted, let completedAt = task.completedAt {
                        Text("Completed \(completedAt.formatted(date: .abbreviated, time: .shortened))")
                            .font(.system(size: 12))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Delete button
                Button {
                    showingDeleteConfirm = true
                } label: {
                    Image(systemName: "trash")
                        .font(.system(size: 14))
                        .foregroundColor(.red.opacity(0.7))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 54)
            }
        }
        .confirmationDialog("Delete Task", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
            Button("Delete", role: .destructive, action: onDelete)
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Are you sure you want to delete this task?")
        }
    }

    private var deadlineColor: Color {
        if task.isCompleted {
            return .secondary
        } else if task.isOverdue {
            return .red
        } else if task.isDeadlineApproaching {
            return .orange
        } else {
            return .secondary
        }
    }
}

#Preview {
    NavigationStack {
        BulletinView()
    }
}
