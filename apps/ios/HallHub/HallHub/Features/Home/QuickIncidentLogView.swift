import SwiftUI

// MARK: - Mock Data

struct IncidentType: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let color: Color
}

// MARK: - QuickIncidentLogView

struct QuickIncidentLogView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var selectedType: IncidentType?
    @State private var notes: String = ""
    @State private var showConfirmation = false

    private let incidentTypes: [IncidentType] = [
        IncidentType(name: "Noise Complaint", icon: "speaker.wave.3.fill", color: .appWarning),
        IncidentType(name: "Lockout", icon: "key.fill", color: .appSecondary),
        IncidentType(name: "Maintenance", icon: "wrench.fill", color: .textSecondary),
        IncidentType(name: "Safety Concern", icon: "exclamationmark.shield.fill", color: .appError),
        IncidentType(name: "Wellness Check", icon: "heart.fill", color: .appPrimary),
        IncidentType(name: "Other", icon: "ellipsis.circle.fill", color: .textSecondary)
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Incident Type Selection
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Incident Type")
                        .appStyle(.titleSmall)
                        .padding(.horizontal, AppSpacing.xs)

                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: AppSpacing.sm) {
                        ForEach(incidentTypes) { type in
                            IncidentTypeCard(
                                type: type,
                                isSelected: selectedType?.id == type.id
                            ) {
                                selectedType = type
                            }
                        }
                    }
                }

                // Notes
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Quick Notes")
                        .appStyle(.titleSmall)
                        .padding(.horizontal, AppSpacing.xs)

                    AppCard {
                        TextField("Add notes (optional)...", text: $notes, axis: .vertical)
                            .appFont(.body)
                            .lineLimit(3...6)
                    }
                }

                // Info Card
                AppCard {
                    HStack(spacing: AppSpacing.sm) {
                        Image(systemName: "info.circle.fill")
                            .foregroundColor(.appPrimary)

                        Text("In the full version, this would create an incident report and notify appropriate staff.")
                            .appStyle(.caption, color: .textSecondary)
                    }
                }

                Spacer(minLength: AppSpacing.lg)

                // Submit Button
                PrimaryButton(title: "Log Incident") {
                    showConfirmation = true
                }
                .disabled(selectedType == nil)
                .opacity(selectedType == nil ? 0.5 : 1)
            }
            .padding(AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle("Log Incident")
        .navigationBarTitleDisplayMode(.inline)
        .alert("Incident Logged", isPresented: $showConfirmation) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("This is a mock confirmation. In the full app, the incident would be saved and relevant parties notified.")
        }
    }
}

struct IncidentTypeCard: View {
    let type: IncidentType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: AppSpacing.sm) {
                Image(systemName: type.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isSelected ? .white : type.color)
                    .frame(width: 48, height: 48)
                    .background(isSelected ? type.color : type.color.opacity(0.1))
                    .cornerRadius(AppRadius.card)

                Text(type.name)
                    .appStyle(.caption, color: isSelected ? .appPrimary : .textPrimary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity)
            .padding(AppSpacing.md)
            .background(Color.appSurface)
            .cornerRadius(AppRadius.card)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.card)
                    .stroke(isSelected ? Color.appPrimary : Color.clear, lineWidth: 2)
            )
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        QuickIncidentLogView()
    }
}
