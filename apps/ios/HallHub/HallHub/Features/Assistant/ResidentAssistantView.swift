import SwiftUI

struct ResidentAssistantView: View {
    @State private var questionText: String = ""
    @State private var showingResponse: Bool = false

    private let faqItems: [FAQItem] = [
        FAQItem(
            question: "Locked out?",
            icon: "key.fill",
            bulletPoints: [
                "Contact your RA on duty (check your floor's duty board for the number)",
                "If after hours, call Campus Safety at 651-962-5100",
                "Have your student ID ready for verification",
                "Note: Repeated lockouts may incur a fee"
            ]
        ),
        FAQItem(
            question: "Emergency?",
            icon: "exclamationmark.triangle.fill",
            bulletPoints: [
                "Life-threatening: Call 911 immediately",
                "Campus emergency: Call Campus Safety at 651-962-5100",
                "See Emergency Contacts in the Resources tab for more numbers",
                "When in doubt, it's always okay to call for help"
            ]
        ),
        FAQItem(
            question: "Quiet hours?",
            icon: "speaker.slash.fill",
            bulletPoints: [
                "Sunday - Thursday: 10 PM - 8 AM",
                "Friday - Saturday: 12 AM - 10 AM",
                "Courtesy hours are 24/7 (keep noise reasonable)",
                "During finals: Extended quiet hours may apply"
            ]
        ),
        FAQItem(
            question: "Roommate conflict?",
            icon: "person.2.fill",
            bulletPoints: [
                "Try talking directly with your roommate first",
                "Review your roommate agreement together",
                "Contact your RA for mediation help",
                "The goal is finding solutions that work for everyone"
            ]
        ),
        FAQItem(
            question: "Maintenance issue?",
            icon: "wrench.and.screwdriver.fill",
            bulletPoints: [
                "Submit a work order through the housing portal",
                "For urgent issues (flooding, no heat), contact your RA",
                "Emergency maintenance: Campus Safety can dispatch help",
                "Document issues with photos if possible"
            ]
        )
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: AppSpacing.lg) {
                    // Header
                    VStack(alignment: .leading, spacing: AppSpacing.xs) {
                        Text("Common questions & what to do (mock)")
                            .appStyle(.caption, color: .textSecondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.md)

                    // FAQ Cards
                    VStack(spacing: AppSpacing.sm) {
                        ForEach(faqItems) { item in
                            FAQCard(item: item)
                        }
                    }
                    .padding(.horizontal, AppSpacing.md)

                    // Ask a question area
                    askQuestionSection
                        .padding(.horizontal, AppSpacing.md)

                    // Response card (when shown)
                    if showingResponse {
                        responseCard
                            .padding(.horizontal, AppSpacing.md)
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .padding(.vertical, AppSpacing.md)
            }
            .background(Color.appBackground)
            .navigationTitle("Quick Help")
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
        }
    }

    private var askQuestionSection: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "questionmark.bubble.fill")
                        .foregroundColor(.appPrimary)
                    Text("Have another question?")
                        .appStyle(.titleSmall)
                }

                HStack(spacing: AppSpacing.sm) {
                    TextField("Type a question (mock)", text: $questionText)
                        .textFieldStyle(.plain)
                        .appFont(.body)
                        .padding(AppSpacing.sm)
                        .background(Color.appBackground)
                        .cornerRadius(AppRadius.input)
                        .onSubmit {
                            submitQuestion()
                        }

                    Button {
                        submitQuestion()
                    } label: {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(questionText.isEmpty ? .textSecondary : .appPrimary)
                    }
                    .disabled(questionText.isEmpty)
                }
            }
        }
    }

    private var responseCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "sparkles")
                        .foregroundColor(.appSecondary)
                    Text("Response")
                        .appStyle(.titleSmall)
                }

                Text("For detailed questions, we recommend contacting your RA directly or checking the Resources tab for protocols and emergency contacts.")
                    .appStyle(.body, color: .textSecondary)

                HStack(spacing: AppSpacing.md) {
                    Image(systemName: "person.badge.key.fill")
                        .foregroundColor(.appPrimary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Your RA: Alex Martinez")
                            .appStyle(.body)
                        Text("Ireland 2 South")
                            .appStyle(.caption, color: .textSecondary)
                    }
                }
                .padding(AppSpacing.sm)
                .background(Color.appPrimary.opacity(0.05))
                .cornerRadius(AppRadius.card)

                Button {
                    withAnimation {
                        showingResponse = false
                        questionText = ""
                    }
                } label: {
                    Text("Dismiss")
                        .appStyle(.label, color: .appPrimary)
                }
            }
        }
    }

    private func submitQuestion() {
        guard !questionText.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.3)) {
            showingResponse = true
        }
    }
}

// MARK: - FAQ Card

struct FAQCard: View {
    let item: FAQItem
    @State private var isExpanded: Bool = false

    var body: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack {
                        Image(systemName: item.icon)
                            .foregroundColor(.appPrimary)
                            .frame(width: 24)

                        Text(item.question)
                            .appStyle(.titleSmall)

                        Spacer()

                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.textSecondary)
                    }
                }
                .buttonStyle(.plain)

                if isExpanded {
                    VStack(alignment: .leading, spacing: AppSpacing.sm) {
                        ForEach(item.bulletPoints, id: \.self) { point in
                            HStack(alignment: .top, spacing: AppSpacing.sm) {
                                Circle()
                                    .fill(Color.appPrimary)
                                    .frame(width: 6, height: 6)
                                    .padding(.top, 6)

                                Text(point)
                                    .appStyle(.body, color: .textSecondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    .padding(.leading, 32)
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
    }
}

#Preview {
    ResidentAssistantView()
}
