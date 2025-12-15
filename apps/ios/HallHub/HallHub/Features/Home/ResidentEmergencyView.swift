import SwiftUI

// MARK: - Mock Data

struct EmergencyContact: Identifiable {
    let id = UUID()
    let name: String
    let phone: String
    let description: String
    let icon: String
    let isEmergency: Bool
}

// MARK: - ResidentEmergencyView

struct ResidentEmergencyView: View {
    private let contacts: [EmergencyContact] = [
        EmergencyContact(
            name: "Campus Safety",
            phone: "(651) 962-5555",
            description: "24/7 emergency response",
            icon: "shield.fill",
            isEmergency: true
        ),
        EmergencyContact(
            name: "911 Emergency",
            phone: "911",
            description: "Police, Fire, Ambulance",
            icon: "phone.fill",
            isEmergency: true
        ),
        EmergencyContact(
            name: "RA Duty Phone",
            phone: "(651) 555-0199",
            description: "After hours RA assistance",
            icon: "person.fill",
            isEmergency: false
        ),
        EmergencyContact(
            name: "Health Services",
            phone: "(651) 962-6750",
            description: "Student health & wellness",
            icon: "cross.case.fill",
            isEmergency: false
        ),
        EmergencyContact(
            name: "Counseling Center",
            phone: "(651) 962-6780",
            description: "Mental health support",
            icon: "heart.fill",
            isEmergency: false
        )
    ]

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Emergency Banner
                AppCard {
                    HStack(spacing: AppSpacing.md) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.appError)

                        VStack(alignment: .leading, spacing: AppSpacing.xs) {
                            Text("In an Emergency")
                                .appStyle(.titleSmall)

                            Text("Call 911 or Campus Safety immediately for life-threatening situations.")
                                .appStyle(.caption, color: .textSecondary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                // Emergency Contacts
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Emergency Numbers")
                        .appStyle(.titleSmall)
                        .padding(.horizontal, AppSpacing.xs)

                    VStack(spacing: AppSpacing.sm) {
                        ForEach(contacts.filter { $0.isEmergency }) { contact in
                            EmergencyContactCard(contact: contact, isHighlighted: true)
                        }
                    }
                }

                // Other Contacts
                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    Text("Support Resources")
                        .appStyle(.titleSmall)
                        .padding(.horizontal, AppSpacing.xs)

                    VStack(spacing: AppSpacing.sm) {
                        ForEach(contacts.filter { !$0.isEmergency }) { contact in
                            EmergencyContactCard(contact: contact, isHighlighted: false)
                        }
                    }
                }

                // Info Card
                AppCard {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        HStack {
                            Image(systemName: "info.circle.fill")
                                .foregroundColor(.appPrimary)
                            Text("Need to talk?")
                                .appStyle(.titleSmall)
                        }

                        Text("Your RA and Residence Life staff are here to help with any concerns, big or small. Don't hesitate to reach out.")
                            .appStyle(.body, color: .textSecondary)
                    }
                }
            }
            .padding(AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle("Emergency Contacts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct EmergencyContactCard: View {
    let contact: EmergencyContact
    let isHighlighted: Bool

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: contact.icon)
                    .font(.system(size: 24))
                    .foregroundColor(isHighlighted ? .appError : .appPrimary)
                    .frame(width: 44, height: 44)
                    .background((isHighlighted ? Color.appError : Color.appPrimary).opacity(0.1))
                    .cornerRadius(AppRadius.card)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(contact.name)
                        .appStyle(.body)

                    Text(contact.phone)
                        .appStyle(.titleSmall, color: isHighlighted ? .appError : .appPrimary)

                    Text(contact.description)
                        .appStyle(.caption, color: .textSecondary)
                }

                Spacer()

                Button {
                    // Mock call action
                    print("Calling \(contact.phone)")
                } label: {
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(isHighlighted ? .appError : .appPrimary)
                }
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationStack {
        ResidentEmergencyView()
    }
}
