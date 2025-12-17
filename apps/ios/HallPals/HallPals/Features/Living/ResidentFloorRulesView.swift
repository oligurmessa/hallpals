import SwiftUI
import FirebaseFirestore

/// Resident view for displaying floor rules and expectations set by their RA
struct ResidentFloorRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = FloorRulesService.shared
    @StateObject private var userManager = UserManager.shared

    var body: some View {
        NavigationStack {
            Group {
                if service.isLoading {
                    loadingView
                } else if let rules = service.currentRules {
                    rulesContent(rules)
                } else {
                    noRulesView
                }
            }
            .navigationTitle("Floor Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.blue)
                }
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text("Loading rules...")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, minHeight: 300)
    }

    // MARK: - No Rules View

    private var noRulesView: some View {
        VStack(spacing: 16) {
            Image(systemName: "list.bullet.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)

            Text("No Floor Rules Yet")
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.primary)

            Text("Your RA hasn't posted any floor rules or expectations yet. Check back later!")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
        .padding(32)
    }

    // MARK: - Rules Content

    private func rulesContent(_ rules: FloorRules) -> some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection(rules)
                    .padding(.horizontal, 20)

                // Rules Section
                if !rules.rules.isEmpty {
                    rulesSection(rules.rules)
                        .padding(.horizontal, 20)
                }

                // Expectations Section
                if !rules.expectations.isEmpty {
                    expectationsSection(rules.expectations)
                        .padding(.horizontal, 20)
                }

                // Last Updated
                if let updatedAt = rules.updatedAt {
                    lastUpdatedSection(updatedAt)
                        .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
    }

    // MARK: - Header Section

    private func headerSection(_ rules: FloorRules) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(rules.title)
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.primary)

            HStack(spacing: 8) {
                if let raName = rules.raName {
                    HStack(spacing: 4) {
                        Image(systemName: "person.fill")
                            .font(.system(size: 12))
                        Text("From \(raName)")
                    }
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                }

                if let floor = rules.floor {
                    Text("Floor \(floor)")
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.blue)
                        .cornerRadius(4)
                }

                if let wing = rules.wing, !wing.isEmpty {
                    Text(wing)
                        .font(.system(size: 12))
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.purple)
                        .cornerRadius(4)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Rules Section

    private func rulesSection(_ rules: [FloorRules.RuleItem]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Rules")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                ForEach(Array(rules.sorted(by: { $0.order < $1.order }).enumerated()), id: \.element.id) { index, rule in
                    VStack(spacing: 0) {
                        HStack(alignment: .top, spacing: 14) {
                            // Rule number
                            Text("\(index + 1)")
                                .font(.system(size: 14, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 28, height: 28)
                                .background(Color.green)
                                .clipShape(Circle())

                            VStack(alignment: .leading, spacing: 4) {
                                Text(rule.text)
                                    .font(.system(size: 16))
                                    .foregroundColor(.primary)

                                if let category = rule.category, !category.isEmpty {
                                    Text(category)
                                        .font(.system(size: 12))
                                        .foregroundColor(.secondary)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 2)
                                        .background(Color(UIColor.systemGray5))
                                        .cornerRadius(4)
                                }
                            }

                            Spacer()
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 14)

                        if index < rules.count - 1 {
                            Divider()
                                .padding(.leading, 58)
                        }
                    }
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Expectations Section

    private func expectationsSection(_ expectations: [String]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Expectations")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 12) {
                ForEach(Array(expectations.enumerated()), id: \.offset) { _, expectation in
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 14))
                            .foregroundColor(.orange)

                        Text(expectation)
                            .font(.system(size: 15))
                            .foregroundColor(.primary)

                        Spacer()
                    }
                }
            }
            .padding(16)
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Last Updated Section

    private func lastUpdatedSection(_ timestamp: Timestamp) -> some View {
        HStack {
            Image(systemName: "clock")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Text("Last updated \(timestamp.dateValue().formatted(date: .abbreviated, time: .shortened))")
                .font(.system(size: 12))
                .foregroundColor(.secondary)

            Spacer()
        }
        .padding(.top, 8)
    }
}

#Preview {
    ResidentFloorRulesView()
}
