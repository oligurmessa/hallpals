import SwiftUI

struct ResidentsView: View {
    // OPTIMIZED: Observe UserManager directly for reactive updates
    // UserManager loads residents in parallel with shifts on RA login
    @StateObject private var userManager = UserManager.shared
    @State private var searchText = ""

    // Backward compatibility alias
    private var residentService: ResidentService { ResidentService.shared }

    // Filtered residents based on search
    var filteredResidents: [HallResident] {
        if searchText.isEmpty {
            return userManager.sortedResidents
        }
        return userManager.searchResidents(searchText)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Content
                contentSection
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Residents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    userManager.refreshRAData()
                } label: {
                    Image(systemName: "arrow.clockwise")
                        .font(.system(size: 17))
                }
                .disabled(userManager.isLoadingRAData)
            }
        }
        .onAppear {
            // Data is already loaded by UserManager on RA login
            // Only refresh if explicitly empty and not loading
            if userManager.myResidents.isEmpty && !userManager.isLoadingRAData && userManager.residentsLoaded {
                userManager.refreshRAData()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Residents")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            if userManager.myResidents.isEmpty {
                Text("Your assigned residents")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            } else {
                Text("\(userManager.residentCount) residents in your section")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Content Section

    @ViewBuilder
    private var contentSection: some View {
        // Loading state
        if userManager.isLoadingRAData && !userManager.residentsLoaded {
            loadingView
        }
        // Error state
        else if let error = userManager.residentsError, userManager.myResidents.isEmpty {
            emptyStateCard(message: error)
                .padding(.horizontal, 20)
        }
        // Empty state
        else if userManager.myResidents.isEmpty {
            emptyStateCard(message: "No residents assigned to your section yet.")
                .padding(.horizontal, 20)
        }
        // Residents list
        else {
            // Stats card
            statsCard
                .padding(.horizontal, 20)

            // Search bar
            searchBar
                .padding(.horizontal, 20)

            // Residents list
            residentsListSection
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading residents...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    // MARK: - Empty State Card

    private func emptyStateCard(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 44))
                .foregroundColor(.purple)

            Text("My Residents")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            // Assignment info
            if let floor = userManager.currentUser?.floor {
                let wingText = userManager.currentUser?.wing
                HStack(spacing: 8) {
                    Image(systemName: "location.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.blue)

                    if let wing = wingText {
                        Text("Floor \(floor), \(wing)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    } else {
                        Text("Floor \(floor)")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 8)
            }

            Button {
                userManager.refreshRAData()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
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
                Text("\(userManager.residentCount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.purple)
                Text("Residents")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Show floor/wing assignment
            if let floor = userManager.currentUser?.floor {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("My Section")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)

                    if let wing = userManager.currentUser?.wing {
                        Text("Floor \(floor), \(wing)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.purple)
                    } else {
                        Text("Floor \(floor)")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.purple)
                    }
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search residents...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Residents List Section

    private var residentsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !searchText.isEmpty {
                Text("\(filteredResidents.count) results")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 20)
            }

            if filteredResidents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("No residents found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Group by letter
                let grouped = Dictionary(grouping: filteredResidents) { resident in
                    String(resident.lastName.prefix(1)).uppercased()
                }
                let sortedKeys = grouped.keys.sorted()

                ForEach(sortedKeys, id: \.self) { letter in
                    VStack(alignment: .leading, spacing: 0) {
                        // Letter header
                        Text(letter)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // Residents in this letter group
                        VStack(spacing: 0) {
                            let residentsInGroup = grouped[letter] ?? []
                            ForEach(Array(residentsInGroup.enumerated()), id: \.element.id) { index, resident in
                                HallResidentRow(
                                    resident: resident,
                                    isLast: index == residentsInGroup.count - 1
                                )
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Hall Resident Row

struct HallResidentRow: View {
    let resident: HallResident
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(avatarColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(resident.initials)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(resident.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text("Room \(resident.roomNumber)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        if let wing = resident.wing, !wing.isEmpty {
                            Text("• \(wing)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Email button
                if !resident.email.isEmpty {
                    Button {
                        if let url = URL(string: "mailto:\(resident.email)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "envelope")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 68)
            }
        }
    }

    private var avatarColor: Color {
        // Generate consistent color from name
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        let hash = abs(resident.fullName.hashValue)
        return colors[hash % colors.count]
    }
}

#Preview {
    NavigationStack {
        ResidentsView()
    }
}
