import SwiftUI

struct SLEDDetailView: View {
    let item: SLEDItem

    var body: some View {
        ScrollView {
            VStack(spacing: AppSpacing.lg) {
                // Header card
                headerCard

                // Quick action (if phone available)
                if let phone = item.phoneNumber {
                    quickCallCard(phone: phone)
                }

                // Steps card
                stepsCard

                // Tags card
                if !item.tags.isEmpty {
                    tagsCard
                }
            }
            .padding(AppSpacing.md)
        }
        .background(Color.appBackground)
        .navigationTitle("SLED Reference")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - Header Card

    private var headerCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                // Icon and category
                HStack {
                    Image(systemName: item.category.icon)
                        .font(.system(size: 28))
                        .foregroundColor(item.category.color)
                        .frame(width: 44, height: 44)
                        .background(item.category.color.opacity(0.1))
                        .cornerRadius(10)

                    Spacer()

                    PriorityPill(level: item.priorityLevel)
                }

                // Title
                Text(item.title)
                    .appStyle(.titleMedium)

                // Category pill
                CategoryPill(category: item.category)

                Divider()

                // Summary
                Text(item.summary)
                    .appStyle(.body, color: .textSecondary)
            }
        }
    }

    // MARK: - Quick Call Card

    private func quickCallCard(phone: String) -> some View {
        AppCard {
            VStack(spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "phone.fill")
                        .foregroundColor(.appSuccess)
                    Text("Quick Contact")
                        .appStyle(.titleSmall)
                    Spacer()
                }

                Button {
                    // Mock call action
                    print("Would call: \(phone)")
                } label: {
                    HStack {
                        Image(systemName: "phone.arrow.up.right.fill")
                        Text("Call \(phone)")
                    }
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(Color.appSuccess)
                    .cornerRadius(AppRadius.button)
                }
                .buttonStyle(.plain)

                Text("Tap to call (mock)")
                    .appStyle(.caption, color: .textSecondary)
            }
        }
    }

    // MARK: - Steps Card

    private var stepsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.md) {
                HStack {
                    Image(systemName: "list.number")
                        .foregroundColor(.appPrimary)
                    Text("Steps to Follow")
                        .appStyle(.titleSmall)
                }

                VStack(alignment: .leading, spacing: AppSpacing.sm) {
                    ForEach(Array(item.steps.enumerated()), id: \.offset) { index, step in
                        StepRow(number: index + 1, text: step)
                    }
                }
            }
        }
    }

    // MARK: - Tags Card

    private var tagsCard: some View {
        AppCard {
            VStack(alignment: .leading, spacing: AppSpacing.sm) {
                HStack {
                    Image(systemName: "tag.fill")
                        .foregroundColor(.appPrimary)
                    Text("Related Topics")
                        .appStyle(.titleSmall)
                }

                FlowLayout(spacing: AppSpacing.xs) {
                    ForEach(item.tags, id: \.self) { tag in
                        Text(tag)
                            .appStyle(.label, color: .appPrimary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(AppRadius.chip)
                    }
                }
            }
        }
    }
}

// MARK: - Step Row

struct StepRow: View {
    let number: Int
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.md) {
            Text("\(number)")
                .appStyle(.label, color: .white)
                .frame(width: 24, height: 24)
                .background(Color.appPrimary)
                .cornerRadius(12)

            Text(text)
                .appStyle(.body)
                .fixedSize(horizontal: false, vertical: true)

            Spacer()
        }
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(in: proposal.width ?? 0, subviews: subviews, spacing: spacing)
        return CGSize(width: proposal.width ?? 0, height: result.height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(in: bounds.width, subviews: subviews, spacing: spacing)

        for (index, subview) in subviews.enumerated() {
            let point = result.positions[index]
            subview.place(at: CGPoint(x: bounds.minX + point.x, y: bounds.minY + point.y), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var positions: [CGPoint] = []
        var height: CGFloat = 0

        init(in width: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > width && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                positions.append(CGPoint(x: x, y: y))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            height = y + lineHeight
        }
    }
}

#Preview {
    NavigationStack {
        SLEDDetailView(item: SLEDItem(
            id: UUID(),
            title: "Alcohol Emergency",
            summary: "When a resident shows signs of alcohol poisoning or severe intoxication requiring medical attention.",
            category: .emergency,
            priorityLevel: .critical,
            phoneNumber: "911",
            tags: ["alcohol", "emergency", "medical", "poisoning"],
            steps: [
                "Assess the situation and check if the person is responsive",
                "Call 911 immediately if signs of alcohol poisoning present",
                "Do not leave the person alone",
                "Turn them on their side to prevent choking",
                "Contact your supervisor/HD on duty",
                "Document the incident after the situation is stabilized"
            ]
        ))
    }
}
