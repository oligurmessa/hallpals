import SwiftUI
import PhotosUI

struct RoomCheckView: View {
    @StateObject private var service = RoomCheckService.shared
    @State private var selectedInspection: RoomCheckService.FirebaseRoomInspection?
    @State private var showingSetupSheet = false
    @State private var showingNewRoundAlert = false

    private let hallId = FirestoreService.devHallId

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Progress Card
                progressCard
                    .padding(.horizontal, 20)

                // Room List
                roomListSection
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Room Check")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingNewRoundAlert = true
                    } label: {
                        Label("Start New Round", systemImage: "arrow.clockwise")
                    }

                    Button {
                        showingSetupSheet = true
                    } label: {
                        Label("Edit Rooms", systemImage: "pencil")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                }
            }
        }
        .sheet(item: $selectedInspection) { inspection in
            FirebaseRoomInspectionSheet(inspection: inspection, hallId: hallId)
        }
        .sheet(isPresented: $showingSetupSheet) {
            FirebaseRoomSetupSheet(hallId: hallId)
        }
        .alert("Start New Round?", isPresented: $showingNewRoundAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Start New Round", role: .destructive) {
                Task {
                    try? await service.startNewRound(hallId: hallId)
                }
            }
        } message: {
            Text("This will reset all room inspections. Your previous inspection data will be cleared.")
        }
        .onAppear {
            service.startListening(hallId: hallId)
        }
        .onDisappear {
            service.stopListening()
        }
    }

    // MARK: - Progress Card

    private var progressCard: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Room Inspections")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.primary)

                    if service.isLoading {
                        Text("Loading...")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Circular progress
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                        .frame(width: 60, height: 60)

                    Circle()
                        .trim(from: 0, to: service.overallProgress)
                        .stroke(Color.green, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                        .frame(width: 60, height: 60)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(service.overallProgress * 100))%")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.primary)
                }
            }

            // Stats row
            HStack(spacing: 24) {
                statItem(value: "\(service.completedCount)", label: "Completed", color: .green)
                statItem(value: "\(service.totalCount - service.completedCount)", label: "Remaining", color: .orange)
                statItem(value: "\(service.totalCount)", label: "Total Rooms", color: .blue)
            }
        }
        .padding(20)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private func statItem(value: String, label: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(color)
            Text(label)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Room List Section

    private var roomListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rooms")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            if service.inspections.isEmpty && !service.isLoading {
                // Empty state
                VStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.1))
                            .frame(width: 72, height: 72)
                        Image(systemName: "house.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.blue)
                    }

                    VStack(spacing: 4) {
                        Text("No Rooms Set Up")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(.primary)

                        Text("Tap 'Edit Rooms' to add rooms for inspection")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }

                    Button {
                        showingSetupSheet = true
                    } label: {
                        Text("Set Up Rooms")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(.white)
                            .padding(.horizontal, 24)
                            .padding(.vertical, 12)
                            .background(Color.blue)
                            .cornerRadius(10)
                    }
                }
                .padding(.vertical, 40)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(service.inspections.enumerated()), id: \.element.id) { index, inspection in
                        Button {
                            selectedInspection = inspection
                        } label: {
                            FirebaseRoomRow(
                                inspection: inspection,
                                isLast: index == service.inspections.count - 1
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
}

// MARK: - Firebase Room Row

struct FirebaseRoomRow: View {
    let inspection: RoomCheckService.FirebaseRoomInspection
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Status icon
                ZStack {
                    Circle()
                        .fill(statusColor.opacity(0.15))
                        .frame(width: 40, height: 40)

                    if inspection.isComplete {
                        Image(systemName: "checkmark")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundColor(.green)
                    } else {
                        Text(inspection.roomNumber)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(statusColor)
                    }
                }

                // Room info
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Room \(inspection.roomNumber)")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        if inspection.isComplete {
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
                        Text("\(inspection.completedItemsCount)/\(inspection.totalItemsCount) items")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)

                        if !inspection.notes.isEmpty {
                            Image(systemName: "note.text")
                                .font(.system(size: 11))
                                .foregroundColor(.secondary)
                        }

                        if !inspection.photoUrls.isEmpty {
                            HStack(spacing: 2) {
                                Image(systemName: "photo")
                                    .font(.system(size: 11))
                                Text("\(inspection.photoUrls.count)")
                                    .font(.system(size: 11))
                            }
                            .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Progress indicator
                if !inspection.isComplete {
                    CircularProgressView(progress: inspection.progressPercentage)
                        .frame(width: 32, height: 32)
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
        if inspection.isComplete { return .green }
        if inspection.completedItemsCount > 0 { return .orange }
        return .gray
    }
}

// MARK: - Circular Progress View

struct CircularProgressView: View {
    let progress: Double

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 3)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(Color.orange, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - Firebase Room Inspection Sheet

struct FirebaseRoomInspectionSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = RoomCheckService.shared

    let inspection: RoomCheckService.FirebaseRoomInspection
    let hallId: String

    @State private var localChecklist: [RoomCheckService.FirebaseChecklistItem]
    @State private var notes: String
    @State private var showingPhotosPicker = false
    @State private var selectedPhotoItems: [PhotosPickerItem] = []
    @State private var isComplete: Bool

    init(inspection: RoomCheckService.FirebaseRoomInspection, hallId: String) {
        self.inspection = inspection
        self.hallId = hallId
        self._localChecklist = State(initialValue: inspection.checklist)
        self._notes = State(initialValue: inspection.notes)
        self._isComplete = State(initialValue: inspection.isComplete)
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

                    // Photos
                    photosSection

                    // Mark Complete Button
                    if !isComplete {
                        markCompleteButton
                    } else {
                        reopenButton
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationTitle("Room \(inspection.roomNumber)")
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
            .photosPicker(isPresented: $showingPhotosPicker, selection: $selectedPhotoItems, maxSelectionCount: 5, matching: .images)
            .onChange(of: selectedPhotoItems) { _, items in
                // Photo upload would go here - for now, just log
                #if DEBUG
                print("🏠 ROOMCHECK: Selected \(items.count) photos - upload not yet implemented")
                #endif
                selectedPhotoItems = []
            }
        }
    }

    // MARK: - Room Header

    private var roomHeader: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Room \(inspection.roomNumber)")
                    .font(.system(size: 24, weight: .bold))

                if let building = inspection.building {
                    Text(building)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }
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
                    FirebaseChecklistItemRow(
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
            try? await service.updateChecklistItem(
                hallId: hallId,
                inspectionId: inspection.id,
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
                    // Debounce notes update
                    Task {
                        try? await Task.sleep(nanoseconds: 500_000_000) // 500ms
                        try? await service.updateNotes(
                            hallId: hallId,
                            inspectionId: inspection.id,
                            notes: newValue
                        )
                    }
                }
        }
    }

    // MARK: - Photos Section

    private var photosSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Photos")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                Button {
                    showingPhotosPicker = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "plus")
                        Text("Add")
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.blue)
                }
            }
            .padding(.horizontal, 20)

            if inspection.photoUrls.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "camera")
                            .font(.system(size: 32))
                            .foregroundColor(.secondary)
                        Text("No photos yet")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 24)
                    Spacer()
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(inspection.photoUrls, id: \.self) { urlString in
                            AsyncImage(url: URL(string: urlString)) { phase in
                                switch phase {
                                case .empty:
                                    ProgressView()
                                        .frame(width: 100, height: 100)
                                case .success(let image):
                                    image
                                        .resizable()
                                        .scaledToFill()
                                        .frame(width: 100, height: 100)
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                case .failure:
                                    Image(systemName: "photo")
                                        .font(.system(size: 32))
                                        .foregroundColor(.secondary)
                                        .frame(width: 100, height: 100)
                                        .background(Color(UIColor.tertiarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 8))
                                @unknown default:
                                    EmptyView()
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)
                }
            }
        }
    }

    // MARK: - Mark Complete Button

    private var markCompleteButton: some View {
        Button {
            isComplete = true
            Task {
                try? await service.markComplete(hallId: hallId, inspectionId: inspection.id)
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
                try? await service.reopenInspection(hallId: hallId, inspectionId: inspection.id)
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

// MARK: - Firebase Checklist Item Row

struct FirebaseChecklistItemRow: View {
    let item: RoomCheckService.FirebaseChecklistItem
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

// MARK: - Firebase Room Setup Sheet

struct FirebaseRoomSetupSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var service = RoomCheckService.shared

    let hallId: String

    @State private var roomNumbersText: String = ""
    @State private var building: String = ""
    @State private var isSubmitting = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Building (optional)", text: $building)
                } header: {
                    Text("Building")
                }

                Section {
                    TextEditor(text: $roomNumbersText)
                        .frame(minHeight: 150)
                } header: {
                    Text("Room Numbers")
                } footer: {
                    Text("Enter room numbers separated by commas or new lines. Example: 101, 102, 103 or one per line.")
                }

                Section {
                    Button {
                        setupRooms()
                    } label: {
                        HStack {
                            if isSubmitting {
                                ProgressView()
                                    .scaleEffect(0.8)
                            }
                            Text("Set Up Rooms")
                        }
                    }
                    .disabled(roomNumbersText.trimmingCharacters(in: .whitespaces).isEmpty || isSubmitting)
                }
            }
            .navigationTitle("Edit Rooms")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                // Pre-fill with existing rooms
                roomNumbersText = service.inspections.map { $0.roomNumber }.joined(separator: ", ")
                building = service.inspections.first?.building ?? ""
            }
        }
    }

    private func setupRooms() {
        let separators = CharacterSet(charactersIn: ",\n")
        let numbers = roomNumbersText
            .components(separatedBy: separators)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !numbers.isEmpty else { return }

        isSubmitting = true

        Task {
            do {
                // Delete existing inspections first
                for inspection in service.inspections {
                    try await service.deleteInspection(hallId: hallId, inspectionId: inspection.id)
                }

                // Create new inspections
                try await service.setupRooms(
                    hallId: hallId,
                    roomNumbers: numbers,
                    building: building.isEmpty ? nil : building
                )

                await MainActor.run {
                    dismiss()
                }
            } catch {
                #if DEBUG
                print("🏠 ROOMCHECK: Setup error: \(error.localizedDescription)")
                #endif
                isSubmitting = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        RoomCheckView()
    }
}
