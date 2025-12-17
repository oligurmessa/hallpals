import SwiftUI
import WebKit

struct RAResourcesView: View {
    @EnvironmentObject private var resourceStore: ResourceStore
    @State private var searchText: String = ""
    @State private var selectedSLED: SLEDItem?
    @State private var selectedProtocol: ProtocolItem?
    @State private var selectedDoc: DocMeta?
    @State private var navigateToAI: Bool = false
    @FocusState private var isSearchFocused: Bool

    private var isSearching: Bool {
        !searchText.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var searchResults: [DocMeta] {
        let query = searchText.lowercased()
        return resourceStore.docMetas.filter { 
            $0.title.lowercased().contains(query) || 
            $0.category.lowercased().contains(query)
        }
    }
    
    // Group docs by category for the main list if not searching
    private var groupedDocs: [String: [DocMeta]] {
        Dictionary(grouping: resourceStore.docMetas, by: { $0.category })
    }
    
    // Sorted categories
    private var sortedCategories: [String] {
        groupedDocs.keys.sorted()
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .padding(.horizontal, 20)

                    // Search Bar with AI Button
                    searchBarWithAI
                        .padding(.horizontal, 20)

                    // Reference Topics
                    if isSearching {
                        searchResultsSection
                    } else {
                        referenceSection
                    }
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationDestination(item: $selectedDoc) { doc in
                DocDetailView(doc: doc)
            }
            .fullScreenCover(isPresented: $navigateToAI) {
                AIChatView()
            }
            .onTapGesture {
                isSearchFocused = false
            }
            .task {
                await resourceStore.fetchDocs()
            }
            .refreshable {
                await resourceStore.fetchDocs()
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Resources")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text("Policies, procedures & reference guides")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Search Bar with AI Button

    private var searchBarWithAI: some View {
        HStack(spacing: 12) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 16))
                    .foregroundColor(.secondary)

                TextField("Search topics...", text: $searchText)
                    .font(.system(size: 16))
                    .focused($isSearchFocused)

                if !searchText.isEmpty {
                    Button {
                        searchText = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundColor(Color(UIColor.systemGray3))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)

            // Ask AI Button
            Button {
                navigateToAI = true
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .medium))
                    Text("Ask AI")
                        .font(.system(size: 14, weight: .medium))
                }
                .foregroundColor(.white)
                .padding(.horizontal, 14)
                .padding(.vertical, 12)
                .background(Color.blue)
                .cornerRadius(12)
            }
        }
    }

    // MARK: - Search Results

    private var searchResultsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Results")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            if searchResults.isEmpty {
                HStack {
                    Text("No topics found for \"\(searchText)\"")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                VStack(spacing: 0) {
                    ForEach(searchResults) { doc in
                        docRow(doc: doc, isLast: doc.id == searchResults.last?.id)
                    }
                }
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)
            }
        }
    }

    // MARK: - Reference Section

    private var referenceSection: some View {
        VStack(alignment: .leading, spacing: 24) {
            if let error = resourceStore.docsError {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.orange)
                    Text(error)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    Button("Retry") {
                        Task {
                            await resourceStore.fetchDocs()
                        }
                    }
                    .buttonStyle(.bordered)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else if resourceStore.docMetas.isEmpty {
                VStack(spacing: 16) {
                   ProgressView()
                   Text("Loading resources...")
                       .font(.caption)
                       .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 40)
            } else {
                ForEach(sortedCategories, id: \.self) { category in
                    VStack(alignment: .leading, spacing: 12) {
                        Text(category)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)
                        
                        VStack(spacing: 0) {
                            let docs = groupedDocs[category] ?? []
                            ForEach(docs) { doc in
                                docRow(doc: doc, isLast: doc.id == docs.last?.id)
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }
            }
        }
    }

    // MARK: - Doc Row

    private func docRow(doc: DocMeta, isLast: Bool) -> some View {
        Button {
            selectedDoc = doc
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    // Icon
                    let iconInfo = getIconInfo(category: doc.category)
                    
                    Image(systemName: iconInfo.icon)
                        .font(.system(size: 18))
                        .foregroundColor(iconInfo.color)
                        .frame(width: 32, height: 32)
                        .background(iconInfo.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    // Title
                    Text(doc.title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)

                    Spacer()

                    // Chevron
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)

                if !isLast {
                    Divider()
                        .padding(.leading, 62)
                }
            }
        }
    }
    
    private func getIconInfo(category: String) -> (icon: String, color: Color) {
        switch category.lowercased() {
        case "emergency": return ("exclamationmark.triangle.fill", .red)
        case "procedures": return ("list.bullet.clipboard.fill", .indigo)
        case "policies": return ("scroll.fill", .blue)
        case "housing": return ("house.fill", .purple)
        case "duty & on-call": return ("phone.badge.plus", .blue)
        case "facilities": return ("wrench.and.screwdriver.fill", .orange)
        case "general": return ("info.circle.fill", .gray)
        case "student conduct": return ("gavel.fill", .brown)
        case "training": return ("graduationcap.fill", .cyan)
        case "safety": return ("shield.fill", .mint)
        default: return ("doc.text.fill", .gray)
        }
    }
}

// MARK: - SLED Card

struct SLEDCard: View {
    let item: SLEDItem

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.sm) {
            HStack {
                Image(systemName: item.category.icon)
                    .font(.system(size: 16))
                    .foregroundColor(item.category.color)
                CategoryPill(category: item.category)
                Spacer()
                PriorityPill(level: item.priorityLevel)
            }

            Text(item.title)
                .appStyle(.body)
                .lineLimit(2)

            Text(item.summary)
                .appStyle(.caption, color: .textSecondary)
                .lineLimit(2)
        }
        .padding(AppSpacing.md)
        .frame(width: 200)
        .background(Color.appSurface)
        .cornerRadius(AppRadius.card)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
}

struct SLEDCardCompact: View {
    let item: SLEDItem

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: item.category.icon)
                    .font(.system(size: 20))
                    .foregroundColor(item.category.color)
                    .frame(width: 32)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    Text(item.title)
                        .appStyle(.body)
                    Text(item.summary)
                        .appStyle(.caption, color: .textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                PriorityPill(level: item.priorityLevel)
            }
        }
    }
}

// MARK: - Protocol Row Card

struct ProtocolRowCard: View {
    let item: ProtocolItem
    let showStaffBadge: Bool

    var body: some View {
        AppCard {
            HStack(spacing: AppSpacing.md) {
                Image(systemName: item.category.icon)
                    .font(.system(size: 18))
                    .foregroundColor(.appPrimary)
                    .frame(width: 28)

                VStack(alignment: .leading, spacing: AppSpacing.xs) {
                    HStack {
                        Text(item.title)
                            .appStyle(.body)
                        if showStaffBadge && item.isStaffOnly {
                            Text("Staff")
                                .appStyle(.label, color: .appPrimary)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.appPrimary.opacity(0.1))
                                .cornerRadius(4)
                        }
                    }
                    Text(item.shortDescription)
                        .appStyle(.caption, color: .textSecondary)
                        .lineLimit(1)
                }

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.system(size: 12))
                    .foregroundColor(.textSecondary)
            }
        }
    }
}





// MARK: - Supporting Pills

struct PriorityPill: View {
    let level: PriorityLevel

    var body: some View {
        Text(level.displayName)
            .appStyle(.label, color: .white)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(level.color)
            .cornerRadius(4)
    }
}

struct CategoryPill: View {
    let category: SLEDCategory

    var body: some View {
        Text(category.rawValue)
            .appStyle(.label, color: category.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(category.color.opacity(0.1))
            .cornerRadius(4)
    }
}

#Preview {
    RAResourcesView()
        .environmentObject(ResourceStore())
}





