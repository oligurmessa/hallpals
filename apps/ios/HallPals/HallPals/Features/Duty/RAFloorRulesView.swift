import SwiftUI

/// RA view for creating and managing floor rules and expectations
struct RAFloorRulesView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject private var service = FloorRulesService.shared
    @StateObject private var userManager = UserManager.shared

    @State private var title = ""
    @State private var rules: [FloorRules.RuleItem] = []
    @State private var expectations: [String] = []
    @State private var newRuleText = ""
    @State private var newRuleCategory = ""
    @State private var newExpectation = ""
    @State private var showingAddRule = false
    @State private var showingAddExpectation = false
    @State private var showingSaveConfirmation = false
    @State private var showingPublishConfirmation = false
    @State private var errorMessage: String?

    private var hallId: String {
        userManager.hallId ?? ""
    }

    private var floor: Int? {
        userManager.floor
    }

    private var wing: String? {
        userManager.wing
    }

    var body: some View {
        NavigationStack {
            List {
                // Title Section
                Section {
                    TextField("e.g., Floor 2 South Community Guidelines", text: $title)
                } header: {
                    Text("Title")
                } footer: {
                    Text("Give your rules a descriptive title")
                }

                // Floor/Wing Info
                Section {
                    HStack {
                        Text("Floor")
                        Spacer()
                        Text(floor != nil ? "Floor \(floor!)" : "Not assigned")
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Wing")
                        Spacer()
                        Text(wing ?? "Not assigned")
                            .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Assignment")
                } footer: {
                    Text("Rules will be visible to residents on your floor/wing")
                }

                // Rules Section
                Section {
                    ForEach(rules) { rule in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(rule.text)
                                .font(.system(size: 15))

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
                        .padding(.vertical, 4)
                    }
                    .onDelete(perform: deleteRule)
                    .onMove(perform: moveRule)

                    Button {
                        showingAddRule = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.green)
                            Text("Add Rule")
                                .foregroundColor(.green)
                        }
                    }
                } header: {
                    HStack {
                        Text("Rules")
                        Spacer()
                        Text("\(rules.count)")
                            .foregroundColor(.secondary)
                    }
                }

                // Expectations Section
                Section {
                    ForEach(Array(expectations.enumerated()), id: \.offset) { index, expectation in
                        Text(expectation)
                    }
                    .onDelete(perform: deleteExpectation)

                    Button {
                        showingAddExpectation = true
                    } label: {
                        HStack {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(.orange)
                            Text("Add Expectation")
                                .foregroundColor(.orange)
                        }
                    }
                } header: {
                    HStack {
                        Text("Expectations")
                        Spacer()
                        Text("\(expectations.count)")
                            .foregroundColor(.secondary)
                    }
                } footer: {
                    Text("General expectations for community living")
                }

                // Publish Status
                if service.myRules != nil {
                    Section {
                        HStack {
                            Text("Status")
                            Spacer()
                            if service.myRules?.isPublished == true {
                                HStack(spacing: 4) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                    Text("Published")
                                        .foregroundColor(.green)
                                }
                            } else {
                                HStack(spacing: 4) {
                                    Image(systemName: "pencil.circle.fill")
                                        .foregroundColor(.orange)
                                    Text("Draft")
                                        .foregroundColor(.orange)
                                }
                            }
                        }

                        if service.myRules?.isPublished == true {
                            Button(role: .destructive) {
                                unpublishRules()
                            } label: {
                                HStack {
                                    Image(systemName: "eye.slash")
                                    Text("Unpublish Rules")
                                }
                            }
                        } else {
                            Button {
                                showingPublishConfirmation = true
                            } label: {
                                HStack {
                                    Image(systemName: "eye")
                                    Text("Publish to Residents")
                                }
                            }
                            .disabled(rules.isEmpty && expectations.isEmpty)
                        }
                    } header: {
                        Text("Visibility")
                    }
                }

                // Error Message
                if let error = errorMessage {
                    Section {
                        Text(error)
                            .foregroundColor(.red)
                            .font(.system(size: 14))
                    }
                }
            }
            .navigationTitle("Floor Rules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveRules()
                    }
                    .fontWeight(.semibold)
                    .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty || service.isSaving)
                }

                ToolbarItem(placement: .keyboard) {
                    HStack {
                        Spacer()
                        Button("Done") {
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                    }
                }
            }
            .onAppear {
                loadExistingRules()
                service.startListeningForRA(hallId: hallId)
            }
            .onDisappear {
                service.stopListening()
            }
            .alert("Add Rule", isPresented: $showingAddRule) {
                TextField("Rule text", text: $newRuleText)
                TextField("Category (optional)", text: $newRuleCategory)
                Button("Cancel", role: .cancel) {
                    newRuleText = ""
                    newRuleCategory = ""
                }
                Button("Add") {
                    addRule()
                }
            }
            .alert("Add Expectation", isPresented: $showingAddExpectation) {
                TextField("Expectation text", text: $newExpectation)
                Button("Cancel", role: .cancel) {
                    newExpectation = ""
                }
                Button("Add") {
                    addExpectation()
                }
            }
            .alert("Rules Saved", isPresented: $showingSaveConfirmation) {
                Button("OK") {
                    dismiss()
                }
            } message: {
                Text("Your floor rules have been saved successfully.")
            }
            .alert("Publish Rules?", isPresented: $showingPublishConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Publish") {
                    publishRules()
                }
            } message: {
                Text("This will make your rules visible to all residents on your floor/wing.")
            }
        }
    }

    // MARK: - Load Existing Rules

    private func loadExistingRules() {
        if let existing = service.myRules {
            title = existing.title
            rules = existing.rules
            expectations = existing.expectations
        } else {
            // Default title
            if let floor = floor {
                title = "Floor \(floor) Community Guidelines"
            } else {
                title = "Community Guidelines"
            }
        }
    }

    // MARK: - Rule Management

    private func addRule() {
        guard !newRuleText.trimmingCharacters(in: .whitespaces).isEmpty else { return }

        let newRule = FloorRules.RuleItem(
            id: UUID().uuidString,
            text: newRuleText.trimmingCharacters(in: .whitespaces),
            order: rules.count,
            category: newRuleCategory.isEmpty ? nil : newRuleCategory.trimmingCharacters(in: .whitespaces)
        )

        rules.append(newRule)
        newRuleText = ""
        newRuleCategory = ""
    }

    private func deleteRule(at offsets: IndexSet) {
        rules.remove(atOffsets: offsets)
        // Re-order remaining rules
        for i in 0..<rules.count {
            rules[i] = FloorRules.RuleItem(
                id: rules[i].id,
                text: rules[i].text,
                order: i,
                category: rules[i].category
            )
        }
    }

    private func moveRule(from source: IndexSet, to destination: Int) {
        rules.move(fromOffsets: source, toOffset: destination)
        // Re-order
        for i in 0..<rules.count {
            rules[i] = FloorRules.RuleItem(
                id: rules[i].id,
                text: rules[i].text,
                order: i,
                category: rules[i].category
            )
        }
    }

    // MARK: - Expectation Management

    private func addExpectation() {
        guard !newExpectation.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        expectations.append(newExpectation.trimmingCharacters(in: .whitespaces))
        newExpectation = ""
    }

    private func deleteExpectation(at offsets: IndexSet) {
        expectations.remove(atOffsets: offsets)
    }

    // MARK: - Save Rules

    private func saveRules() {
        errorMessage = nil

        Task {
            do {
                try await service.saveRules(
                    hallId: hallId,
                    title: title.trimmingCharacters(in: .whitespaces),
                    rules: rules,
                    expectations: expectations,
                    floor: floor,
                    wing: wing
                )
                showingSaveConfirmation = true
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: - Publish/Unpublish

    private func publishRules() {
        errorMessage = nil

        Task {
            do {
                try await service.publishRules(hallId: hallId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func unpublishRules() {
        errorMessage = nil

        Task {
            do {
                try await service.unpublishRules(hallId: hallId)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }
}

#Preview {
    RAFloorRulesView()
}
