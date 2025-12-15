import SwiftUI

struct DocDetailView: View {
    let doc: DocMeta
    @StateObject private var docsService = DocsService.shared
    
    @State private var entries: [DocEntry] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    
    private var iconName: String {
        // Simple mapping based on category or default
        switch doc.category.lowercased() {
        case "emergency": return "exclamationmark.triangle.fill"
        case "procedures": return "list.bullet.clipboard.fill"
        case "policies": return "scroll.fill"
        case "housing": return "house.fill"
        case "duty & on-call": return "phone.badge.plus"
        default: return "doc.text.fill"
        }
    }
    
    private var iconColor: Color {
        switch doc.category.lowercased() {
        case "emergency": return .red
        case "procedures": return .indigo
        case "policies": return .blue
        case "housing": return .purple
        case "duty & on-call": return .blue
        default: return .gray
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header card
                HStack(spacing: 16) {
                    Image(systemName: iconName)
                        .font(.system(size: 28, weight: .medium))
                        .foregroundColor(iconColor)
                        .frame(width: 56, height: 56)
                        .background(iconColor.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 14))

                    VStack(alignment: .leading, spacing: 4) {
                        Text(doc.title)
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                        
                        if let updated = doc.updatedAt {
                            Text("Updated \(updated.formatted(date: .abbreviated, time: .shortened))")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        } else {
                            Text("Loading...")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }

                    Spacer()
                }
                .padding(16)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)

                if isLoading {
                    ProgressView()
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 40)
                } else if let error = errorMessage {
                    VStack(spacing: 12) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 32))
                            .foregroundColor(.orange)
                        Text("Error: \(error)")
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                } else if entries.isEmpty {
                    // Empty state - no entries for this doc
                    VStack(spacing: 16) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary.opacity(0.5))
                        Text("No content yet")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        Text("This document doesn't have any entries. Add content via the web dashboard.")
                            .font(.subheadline)
                            .foregroundColor(.secondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 60)
                } else {
                    // Group entries by Section (if available) or just list them
                    let grouped = Dictionary(grouping: entries) { $0.section ?? "General" }
                    let sortedSections = grouped.keys.sorted()

                    ForEach(sortedSections, id: \.self) { sectionName in
                        VStack(alignment: .leading, spacing: 12) {
                            if sectionName != "General" {
                                Text(sectionName)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(.secondary)
                                    .textCase(.uppercase)
                                    .tracking(0.5)
                            }

                            VStack(spacing: 0) {
                                let sectionEntries = grouped[sectionName] ?? []
                                ForEach(Array(sectionEntries.enumerated()), id: \.element.id) { index, entry in
                                    DocEntryRow(
                                        entry: entry,
                                        isLast: index == sectionEntries.count - 1
                                    )
                                }
                            }
                            .background(Color(UIColor.secondarySystemBackground))
                            .cornerRadius(12)
                        }
                    }
                }
            }
            .padding(20)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle(doc.title)
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            loadDoc()
        }
    }

    private func loadDoc() {
        isLoading = true
        let slug = doc.slug
        
        Task {
            do {
                // Just fetch entries since we already have doc meta
                let fetchedEntries = try await docsService.fetchEntries(docId: slug)
                self.entries = fetchedEntries
                self.isLoading = false
            } catch {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
            }
        }
    }
}

struct DocEntryRow: View {
    let entry: DocEntry
    let isLast: Bool

    @State private var isExpanded: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                Text(entry.text)
                    .font(.system(size: 15))
                    .foregroundColor(.primary)
                    .lineSpacing(4)
                    .lineLimit(isExpanded ? nil : 3)

                if entry.text.count > 100 {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isExpanded.toggle()
                        }
                    } label: {
                        Text(isExpanded ? "Show less" : "Read more")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            if !isLast {
                Divider()
                    .padding(.leading, 16)
            }
        }
    }
}
