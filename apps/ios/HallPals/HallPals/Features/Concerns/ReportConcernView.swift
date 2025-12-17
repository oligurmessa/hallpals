import SwiftUI

/// Simple view for residents to report a concern to the on-duty RA
struct ReportConcernView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var concernService = ConcernService.shared
    @StateObject private var userManager = UserManager.shared

    let hallId: String
    let onDutyRAUid: String
    let onDutyRAName: String

    @State private var selectedCategory: ConcernService.ConcernCategory = .noise
    @State private var message = ""
    @State private var showingSuccess = false
    @State private var errorMessage: String?

    var body: some View {
        NavigationStack {
            Form {
                // On-Duty RA Info
                Section {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color.green.opacity(0.2))
                            .frame(width: 44, height: 44)
                            .overlay(
                                Text(String(onDutyRAName.prefix(1)).uppercased())
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundColor(.green)
                            )

                        VStack(alignment: .leading, spacing: 2) {
                            Text("On Duty Now")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(onDutyRAName)
                                .font(.headline)
                        }

                        Spacer()

                        Circle()
                            .fill(Color.green)
                            .frame(width: 10, height: 10)
                    }
                } header: {
                    Text("Sending to")
                }

                // Category Selection
                Section {
                    Picker("Category", selection: $selectedCategory) {
                        ForEach(ConcernService.ConcernCategory.allCases, id: \.self) { category in
                            Label(category.displayName, systemImage: category.icon)
                                .tag(category)
                        }
                    }
                    .pickerStyle(.menu)
                } header: {
                    Text("What's this about?")
                }

                // Message
                Section {
                    TextEditor(text: $message)
                        .frame(minHeight: 120)
                        .overlay(
                            Group {
                                if message.isEmpty {
                                    Text("Describe your concern...")
                                        .foregroundColor(.secondary)
                                        .padding(.leading, 4)
                                        .padding(.top, 8)
                                        .allowsHitTesting(false)
                                }
                            },
                            alignment: .topLeading
                        )
                } header: {
                    Text("Details")
                } footer: {
                    Text("Your name and room will be shared with the RA.")
                        .font(.caption)
                }

                // Error message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.caption)
                    }
                }
            }
            .navigationTitle("Report Concern")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Send") {
                        submitConcern()
                    }
                    .fontWeight(.semibold)
                    .disabled(message.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || concernService.isSubmitting)
                }
            }
            .interactiveDismissDisabled(concernService.isSubmitting)
            .alert("Concern Submitted", isPresented: $showingSuccess) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your concern has been sent to \(onDutyRAName). They will follow up with you soon.")
            }
        }
    }

    private func submitConcern() {
        errorMessage = nil
        let trimmedMessage = message.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmedMessage.isEmpty else {
            errorMessage = "Please describe your concern"
            return
        }

        Task {
            do {
                try await concernService.submitConcern(
                    hallId: hallId,
                    category: selectedCategory,
                    message: trimmedMessage,
                    residentName: userManager.currentUser?.displayName ?? "Resident",
                    residentRoom: userManager.roomNumber,
                    onDutyRAUid: onDutyRAUid,
                    onDutyRAName: onDutyRAName
                )
                showingSuccess = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    ReportConcernView(
        hallId: "ireland",
        onDutyRAUid: "ra123",
        onDutyRAName: "John Smith"
    )
}
