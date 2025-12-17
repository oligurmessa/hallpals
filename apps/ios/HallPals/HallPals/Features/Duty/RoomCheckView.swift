import SwiftUI

struct RoomCheckView: View {
    @StateObject private var service = RoomCheckService.shared
    @StateObject private var userManager = UserManager.shared
    @State private var selectedRoom: SelectedRoom?

    private var hallId: String {
        userManager.hallId ?? ""
    }

    struct SelectedRoom: Identifiable {
        let id: String
        let round: RoomCheckService.InspectionRound
        let room: RoomCheckService.RoomInspection

        init(round: RoomCheckService.InspectionRound, room: RoomCheckService.RoomInspection) {
            self.id = "\(round.id)-\(room.roomNumber)"
            self.round = round
            self.room = room
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if service.isLoading {
                    loadingView
                } else if service.rounds.isEmpty {
                    emptyStateView
                        .padding(.horizontal, 20)
                } else {
                    // Show each active round
                    ForEach(service.rounds) { round in
                        RoundSection(
                            round: round,
                            onRoomTap: { room in
                                selectedRoom = SelectedRoom(round: round, room: room)
                            }
                        )
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Room Inspections")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    if !hallId.isEmpty {
                        service.startListening(hallId: hallId)
                    }
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17))
                }
                .disabled(service.isLoading)
            }
        }
        .sheet(item: $selectedRoom) { selected in
            RoomInspectionSheet(
                round: selected.round,
                room: selected.room,
                hallId: hallId
            )
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

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading inspections...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 72, height: 72)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(.green)
            }

            VStack(spacing: 4) {
                Text("No Inspections Assigned")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundColor(.primary)

                Text("You're all caught up! Check back when your staff assigns new inspections.")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                if !hallId.isEmpty {
                    service.startListening(hallId: hallId)
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
}

// MARK: - Round Section

struct RoundSection: View {
    let round: RoomCheckService.InspectionRound
    let onRoomTap: (RoomCheckService.RoomInspection) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Round Header
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(round.name)
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(.primary)

                        HStack(spacing: 12) {
                            if let dueDate = round.dueDateText {
                                HStack(spacing: 4) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 12))
                                    Text("Due: \(dueDate)")
                                        .font(.system(size: 13))
                                }
                                .foregroundColor(round.isOverdue ? .red : .secondary)
                            }

                            if round.isOverdue {
                                Text("OVERDUE")
                                    .font(.system(size: 10, weight: .bold))
                                    .foregroundColor(.red)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(Color.red.opacity(0.15))
                                    .cornerRadius(4)
                            }
                        }
                    }

                    Spacer()

                    // Progress circle
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 6)
                            .frame(width: 50, height: 50)

                        Circle()
                            .trim(from: 0, to: round.progressPercentage)
                            .stroke(Color.green, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                            .frame(width: 50, height: 50)
                            .rotationEffect(.degrees(-90))

                        Text("\(Int(round.progressPercentage * 100))%")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(.primary)
                    }
                }

                // Stats row
                HStack(spacing: 20) {
                    StatBadge(value: "\(round.completedRoomsCount)", label: "Done", color: .green)
                    StatBadge(value: "\(round.totalRoomsCount - round.completedRoomsCount)", label: "Remaining", color: .orange)
                    StatBadge(value: "\(round.totalRoomsCount)", label: "Total", color: .blue)
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)

            // Room List
            Text("Rooms")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(round.rooms.enumerated()), id: \.element.id) { index, room in
                    Button {
                        onRoomTap(room)
                    } label: {
                        RoomRow(
                            room: room,
                            isLast: index == round.rooms.count - 1
                        )
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }
}

// MARK: - Stat Badge

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Room Row

struct RoomRow: View {
    let room: RoomCheckService.RoomInspection
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    if room.isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text(room.roomNumber.prefix(3))
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(statusColor)
                    }
                }

                // Room info
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Room \(room.roomNumber)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        if room.isComplete {
                            Text("Complete")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.green)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.green.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }

                    HStack(spacing: 8) {
                        Text("\(room.completedItemsCount)/\(room.totalItemsCount) items")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        if !room.notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Progress indicator for incomplete rooms
                if !room.isComplete && room.completedItemsCount > 0 {
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.2), lineWidth: 3)
                            .frame(width: 32, height: 32)

                        Circle()
                            .trim(from: 0, to: room.progressPercentage)
                            .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                            .frame(width: 32, height: 32)
                            .rotationEffect(.degrees(-90))
                    }
                }

                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Color(UIColor.systemGray3))
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 70)
            }
        }
    }

    private var statusColor: Color {
        if room.isComplete { return .green }
        if room.completedItemsCount > 0 { return .orange }
        return .gray
    }
}

// MARK: - Room Inspection Sheet

struct RoomInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = RoomCheckService.shared

    let round: RoomCheckService.InspectionRound
    let room: RoomCheckService.RoomInspection
    let hallId: String

    @State private var localChecklist: [RoomCheckService.ChecklistItem]
    @State private var notes: String
    @State private var isComplete: Bool

    init(round: RoomCheckService.InspectionRound, room: RoomCheckService.RoomInspection, hallId: String) {
        self.round = round
        self.room = room
        self.hallId = hallId
        self._localChecklist = State(initialValue: room.checklist)
        self._notes = State(initialValue: room.notes)
        self._isComplete = State(initialValue: room.isComplete)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Room header
                    roomHeader

                    // Checklist
                    checklistSection

                    // Notes
                    notesSection

                    // Action button
                    if !isComplete {
                        markCompleteButton
                    } else {
                        reopenButton
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Room \(room.roomNumber)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }

                if service.isSyncing {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
                }
            }
        }
    }

    // MARK: - Room Header

    private var roomHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Room \(room.roomNumber)")
                    .font(.system(size: 24, weight: .bold))

                Text(round.name)
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status badge
            if isComplete {
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Complete")
                }
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.green)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.green.opacity(0.12))
                .cornerRadius(20)
            } else {
                Text("\(completedItemsCount)/\(localChecklist.count)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.orange)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.orange.opacity(0.12))
                    .cornerRadius(20)
            }
        }
        .padding(.horizontal, 20)
    }

    private var completedItemsCount: Int {
        localChecklist.filter { $0.isChecked }.count
    }

    // MARK: - Checklist Section

    private var checklistSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Inspection Checklist")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(localChecklist.enumerated()), id: \.element.id) { index, item in
                    ChecklistItemRow(
                        item: item,
                        isLast: index == localChecklist.count - 1
                    ) {
                        toggleItem(at: index)
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    private func toggleItem(at index: Int) {
        let item = localChecklist[index]
        let newValue = !item.isChecked
        localChecklist[index].isChecked = newValue

        Task {
            try? await service.updateRoomChecklist(
                hallId: hallId,
                roundId: round.id,
                roomNumber: room.roomNumber,
                itemId: item.id,
                isChecked: newValue
            )
        }
    }

    // MARK: - Notes Section

    private var notesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Notes")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            TextEditor(text: $notes)
                .frame(minHeight: 100)
                .padding(12)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .onChange(of: notes) { _, newValue in
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000)
                        try? await service.updateRoomNotes(
                            hallId: hallId,
                            roundId: round.id,
                            roomNumber: room.roomNumber,
                            notes: newValue
                        )
                    }
                }
        }
    }

    // MARK: - Mark Complete Button

    private var markCompleteButton: some View {
        Button {
            isComplete = true
            Task {
                try? await service.markRoomComplete(
                    hallId: hallId,
                    roundId: round.id,
                    roomNumber: room.roomNumber
                )
                dismiss()
            }
        } label: {
            HStack {
                Image(systemName: "checkmark.circle.fill")
                Text("Mark as Complete")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.green)
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }

    // MARK: - Reopen Button

    private var reopenButton: some View {
        Button {
            isComplete = false
            Task {
                try? await service.reopenRoom(
                    hallId: hallId,
                    roundId: round.id,
                    roomNumber: room.roomNumber
                )
            }
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reopen Inspection")
            }
            .font(.system(size: 17, weight: .semibold))
            .foregroundColor(.orange)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(Color.orange.opacity(0.12))
            .cornerRadius(12)
        }
        .padding(.horizontal, 20)
        .padding(.top, 8)
    }
}

// MARK: - Checklist Item Row

struct ChecklistItemRow: View {
    let item: RoomCheckService.ChecklistItem
    let isLast: Bool
    let onToggle: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            Button(action: onToggle) {
                HStack(spacing: 14) {
                    Image(systemName: item.isChecked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 22))
                        .foregroundColor(item.isChecked ? .green : .gray)

                    Text(item.name)
                        .font(.system(size: 16))
                        .foregroundColor(item.isChecked ? .secondary : .primary)
                        .strikethrough(item.isChecked)

                    Spacer()
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }

            if !isLast {
                Divider()
                    .padding(.leading, 52)
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoomCheckView()
    }
}
