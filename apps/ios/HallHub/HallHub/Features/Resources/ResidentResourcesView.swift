import SwiftUI

struct ResidentResourcesView: View {
    @EnvironmentObject private var resourceStore: ResourceStore
    @State private var showingEmergencySheet: Bool = false
    @State private var showingLinkSheet: QuickLink?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Emergency contacts (top priority)
                    emergencyContactsSection

                    // Your RA info
                    raInfoSection

                    // Campus Resources
                    campusResourcesSection

                    // Policies Basics
                    policiesSection

                    // Quick Links
                    linksSection
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(Color.appBackground)
            .navigationTitle("Resources")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text("Resident")
                        .appStyle(.label, color: .textSecondary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(AppRadius.chip)
                }
            }
            .sheet(isPresented: $showingEmergencySheet) {
                EmergencyContactsSheet()
            }
            .sheet(item: $showingLinkSheet) { link in
                QuickLinkSheet(link: link)
            }
        }
    }

    // MARK: - Emergency Contacts Section

    private var emergencyContactsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Emergency Contacts")
                .appStyle(.titleSmall)
                .padding(.horizontal, AppSpacing.md)

            AppCard {
                VStack(spacing: AppSpacing.md) {
                    // 911 Emergency
                    EmergencyContactRow(
                        icon: "phone.fill",
                        iconColor: .appError,
                        title: "Emergency (911)",
                        subtitle: "Police, Fire, Medical Emergency",
                        phoneNumber: "911"
                    )

                    Divider()

                    // Campus Security
                    EmergencyContactRow(
                        icon: "shield.fill",
                        iconColor: .appPrimary,
                        title: "Campus Security",
                        subtitle: "24/7 Safety & Assistance",
                        phoneNumber: "651-962-5100"
                    )

                    Divider()

                    // RA On Duty
                    EmergencyContactRow(
                        icon: "person.badge.key.fill",
                        iconColor: .appSecondary,
                        title: "RA On Duty",
                        subtitle: "Your building's duty phone",
                        phoneNumber: "651-962-6000"
                    )
                }
            }
            .padding(.horizontal, AppSpacing.md)

            // View all contacts button
            Button {
                showingEmergencySheet = true
            } label: {
                HStack {
                    Text("View All Emergency Contacts")
                        .appStyle(.body, color: .appPrimary)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 12))
                        .foregroundColor(.appPrimary)
                }
                .padding(AppSpacing.md)
                .background(Color.appPrimary.opacity(0.05))
                .cornerRadius(AppRadius.card)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - RA Info Section

    private var raInfoSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Your RA")
                .appStyle(.titleSmall)
                .padding(.horizontal, AppSpacing.md)

            AppCard {
                HStack(spacing: AppSpacing.md) {
                    Circle()
                        .fill(Color.appPrimary.opacity(0.2))
                        .frame(width: 50, height: 50)
                        .overlay(
                            Image(systemName: "person.fill")
                                .foregroundColor(.appPrimary)
                        )

                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Alex Martinez")
                            .appStyle(.titleSmall)
                        Text("Ireland 2 South")
                            .appStyle(.caption, color: .textSecondary)
                        Text("Office hours: Mon/Wed 7-9 PM")
                            .appStyle(.caption, color: .textSecondary)
                    }

                    Spacer()

                    VStack(spacing: AppSpacing.xs) {
                        Button {
                            // Mock action
                        } label: {
                            Image(systemName: "message.fill")
                                .foregroundColor(.appPrimary)
                                .frame(width: 36, height: 36)
                                .background(Color.appPrimary.opacity(0.1))
                                .cornerRadius(8)
                        }
                        .buttonStyle(.plain)

                        Text("Message")
                            .appStyle(.label, color: .textSecondary)
                    }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Campus Resources Section

    private var campusResourcesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Campus Resources")
                .appStyle(.titleSmall)
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: AppSpacing.sm) {
                CampusResourceRow(
                    icon: "heart.fill",
                    iconColor: .pink,
                    title: "Counseling & Psychological Services",
                    subtitle: "Mental health support"
                )

                CampusResourceRow(
                    icon: "cross.case.fill",
                    iconColor: .appError,
                    title: "Student Health Services",
                    subtitle: "Medical care on campus"
                )

                CampusResourceRow(
                    icon: "book.fill",
                    iconColor: .appPrimary,
                    title: "Academic Support Center",
                    subtitle: "Tutoring & study help"
                )

                CampusResourceRow(
                    icon: "fork.knife",
                    iconColor: .orange,
                    title: "Dining Services",
                    subtitle: "Meal plans & locations"
                )

                CampusResourceRow(
                    icon: "bus.fill",
                    iconColor: .green,
                    title: "Transportation",
                    subtitle: "Shuttle & parking info"
                )
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Policies Section

    private var policiesSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Policies & Guidelines")
                .appStyle(.titleSmall)
                .padding(.horizontal, AppSpacing.md)

            VStack(spacing: AppSpacing.sm) {
                PolicyRow(
                    icon: "clock.fill",
                    title: "Quiet Hours",
                    description: "Sun-Thu: 10 PM - 8 AM, Fri-Sat: 12 AM - 10 AM"
                )

                PolicyRow(
                    icon: "person.2.fill",
                    title: "Guest Policy",
                    description: "Guests must be registered. Max 2 overnight guests."
                )

                PolicyRow(
                    icon: "nosign",
                    title: "Prohibited Items",
                    description: "No candles, hot plates, or unapproved appliances."
                )

                PolicyRow(
                    icon: "key.fill",
                    title: "Lockout Procedure",
                    description: "Contact RA on duty. ID required."
                )
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }

    // MARK: - Links Section

    private var linksSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            Text("Quick Links")
                .appStyle(.titleSmall)
                .padding(.horizontal, AppSpacing.md)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.sm) {
                ForEach(resourceStore.quickLinks(for: .resident)) { link in
                    QuickLinkCard(link: link)
                        .onTapGesture { showingLinkSheet = link }
                }
            }
            .padding(.horizontal, AppSpacing.md)
        }
    }
}

// MARK: - Emergency Contact Row

struct EmergencyContactRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String
    let phoneNumber: String

    var body: some View {
        HStack(spacing: AppSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(iconColor)
                .frame(width: 36, height: 36)
                .background(iconColor.opacity(0.1))
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .appStyle(.body)
                Text(subtitle)
                    .appStyle(.caption, color: .textSecondary)
            }

            Spacer()

            Button {
                // Mock call action
                print("Would call: \(phoneNumber)")
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.appPrimary)
                    Text(phoneNumber)
                        .appStyle(.label, color: .appPrimary)
                }
                .padding(.horizontal, AppSpacing.sm)
                .padding(.vertical, AppSpacing.xs)
                .background(Color.appPrimary.opacity(0.1))
                .cornerRadius(AppRadius.chip)
            }
            .buttonStyle(.plain)
        }
    }
}

// MARK: - Campus Resource Row

struct CampusResourceRow: View {
    let icon: String
    let iconColor: Color
    let title: String
    let subtitle: String

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
                    .frame(width: 32, height: 32)
                    .background(iconColor.opacity(0.1))
                    .cornerRadius(6)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .appStyle(.body)
                    Text(subtitle)
                        .appStyle(.caption, color: .textSecondary)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}

// MARK: - Policy Row

struct PolicyRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack(spacing: AppSpacing.sm) {
                    Image(systemName: icon)
                        .foregroundColor(.appPrimary)
                    Text(title)
                        .appStyle(.body)
                }

                Text(description)
                    .appStyle(.caption, color: .textSecondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Emergency Contacts Sheet

struct EmergencyContactsSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Critical emergency
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Critical Emergency")
                            .appStyle(.titleSmall, color: .appError)
                            .padding(.horizontal, AppSpacing.md)

                        AppCard {
                            VStack(spacing: AppSpacing.md) {
                                EmergencyContactRow(
                                    icon: "phone.fill",
                                    iconColor: .appError,
                                    title: "911 Emergency",
                                    subtitle: "Police, Fire, Medical",
                                    phoneNumber: "911"
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Campus safety
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Campus Safety")
                            .appStyle(.titleSmall)
                            .padding(.horizontal, AppSpacing.md)

                        AppCard {
                            VStack(spacing: AppSpacing.md) {
                                EmergencyContactRow(
                                    icon: "shield.fill",
                                    iconColor: .appPrimary,
                                    title: "Public Safety",
                                    subtitle: "24/7 Campus Security",
                                    phoneNumber: "651-962-5100"
                                )

                                Divider()

                                EmergencyContactRow(
                                    icon: "exclamationmark.triangle.fill",
                                    iconColor: .appWarning,
                                    title: "Anonymous Tip Line",
                                    subtitle: "Report concerns",
                                    phoneNumber: "651-962-5099"
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Residence Life
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Residence Life")
                            .appStyle(.titleSmall)
                            .padding(.horizontal, AppSpacing.md)

                        AppCard {
                            VStack(spacing: AppSpacing.md) {
                                EmergencyContactRow(
                                    icon: "person.badge.key.fill",
                                    iconColor: .appSecondary,
                                    title: "RA On Duty",
                                    subtitle: "Building duty phone",
                                    phoneNumber: "651-962-6000"
                                )

                                Divider()

                                EmergencyContactRow(
                                    icon: "building.2.fill",
                                    iconColor: .appPrimary,
                                    title: "Residence Life Office",
                                    subtitle: "Main office (business hours)",
                                    phoneNumber: "651-962-6100"
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }

                    // Health & Wellness
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        Text("Health & Wellness")
                            .appStyle(.titleSmall)
                            .padding(.horizontal, AppSpacing.md)

                        AppCard {
                            VStack(spacing: AppSpacing.md) {
                                EmergencyContactRow(
                                    icon: "heart.fill",
                                    iconColor: .pink,
                                    title: "Counseling Center",
                                    subtitle: "Mental health crisis line",
                                    phoneNumber: "651-962-6780"
                                )

                                Divider()

                                EmergencyContactRow(
                                    icon: "cross.case.fill",
                                    iconColor: .appError,
                                    title: "Student Health",
                                    subtitle: "Medical concerns",
                                    phoneNumber: "651-962-6750"
                                )

                                Divider()

                                EmergencyContactRow(
                                    icon: "phone.bubble.fill",
                                    iconColor: .appSuccess,
                                    title: "988 Suicide Hotline",
                                    subtitle: "24/7 Crisis Support",
                                    phoneNumber: "988"
                                )
                            }
                        }
                        .padding(.horizontal, AppSpacing.md)
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(Color.appBackground)
            .navigationTitle("Emergency Contacts")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .foregroundColor(.appPrimary)
                }
            }
        }
    }
}

#Preview {
    ResidentResourcesView()
        .environmentObject(ResourceStore())
}
