import SwiftUI

struct ResidentMoveOutChecklistView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = MoveOutChecklistService.shared
    @StateObject private var userManager = UserManager.shared

    private var hallId: String {
        userManager.hallId ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    if service.isLoading {
                        loadingView
                    } else if let template = service.currentTemplate {
                        // Header
                        headerSection(template: template)
                            .padding(.horizontal, 20)

                        // Progress
                        progressSection
                            .padding(.horizontal, 20)

                        // Checklist Items
                        checklistSection(template: template)
                            .padding(.horizontal, 20)
                    } else {
                        noChecklistView
                            .padding(.horizontal, 20)
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Move-Out Checklist")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
            .onAppear {
                if !hallId.isEmpty {
                    service.startListening(hallId: hallId)
                }
            }
            .onDisappear {
                service.stopListening()
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading checklist...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - No Checklist View

    private var noChecklistView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checklist")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Move-Out Checklist")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Text("Your hall staff hasn't published a move-out checklist yet. Check back later or contact your RA for more information.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(32)
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Header Section

    private func headerSection(template: MoveOutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(template.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            if let description = template.description, !description.isEmpty {
                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Progress Section

    private var progressSection: some View {
        VStack(spacing: 12) {
            HStack {
                Text("Your Progress")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if service.residentChecklist?.isComplete == true {
                    HStack(spacing: 4) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("Complete!")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.green)
                    }
                } else {
                    Text("\(Int(service.completionProgress * 100))%")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.blue)
                }
            }

            // Progress Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(UIColor.systemGray5))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(service.residentChecklist?.isComplete == true ? Color.green : Color.blue)
                        .frame(width: geo.size.width * service.completionProgress, height: 8)
                        .animation(.spring(response: 0.3), value: service.completionProgress)
                }
            }
            .frame(height: 8)

            // Stats
            HStack {
                let completed = service.residentChecklist?.completedItems.count ?? 0
                let total = service.currentTemplate?.items.count ?? 0

                Text("\(completed) of \(total) items completed")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                Spacer()
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Checklist Section

    private func checklistSection(template: MoveOutTemplate) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Checklist Items")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(template.items.sorted(by: { $0.order < $1.order }).enumerated()), id: \.element.id) { index, item in
                    MoveOutChecklistItemRow(
                        item: item,
                        isCompleted: service.residentChecklist?.completedItems.contains(item.id) ?? false,
                        isLast: index == template.items.count - 1
                    ) {
                        Task {
                            await service.toggleItem(hallId: hallId, itemId: item.id)
                        }
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }
}

// MARK: - Move-Out Checklist Item Row

struct MoveOutChecklistItemRow: View {
    let item: MoveOutChecklistItem
    let isCompleted: Bool
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Checkbox
                    ZStack {
                        Circle()
                            .stroke(isCompleted ? Color.green : Color(UIColor.systemGray3), lineWidth: 2)
                            .frame(width: 24, height: 24)

                        if isCompleted {
                            Circle()
                                .fill(Color.green)
                                .frame(width: 24, height: 24)

                            Image(systemName: "checkmark")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundColor(.white)
                        }
                    }

                    // Text
                    VStack(alignment: .leading, spacing: 2) {
                        HStack(spacing: 4) {
                            Text(item.text)
                                .font(.system(size: 16))
                                .foregroundColor(isCompleted ? .secondary : .primary)
                                .strikethrough(isCompleted, color: .secondary)

                            if item.isRequired {
                                Text("*")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(.red)
                            }
                        }

                        if item.isRequired {
                            Text("Required")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if !isLast {
                    Divider()
                        .padding(.leading, 54)
                }
            }
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ResidentMoveOutChecklistView()
}
