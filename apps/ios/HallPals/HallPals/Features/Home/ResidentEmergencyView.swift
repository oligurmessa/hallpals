import SwiftUI

// MARK: - Locked Out Sheet

struct LockedOutSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.orange.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "key.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.orange)
                        }

                        Text("Locked Out?")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)

                    // Resources
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Resources")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            LockedOutContactRow(
                                title: "Residence Life",
                                number: "(651) 962-6470",
                                subtitle: "Koch Commons",
                                icon: "building.2.fill",
                                color: .purple,
                                isLast: false
                            )
                            LockedOutContactRow(
                                title: "Public Safety",
                                number: "651-962-5555",
                                subtitle: "Non-Emergency",
                                icon: "shield.fill",
                                color: .blue,
                                isLast: false
                            )
                            LockedOutContactRow(
                                title: "Public Safety",
                                number: "651-962-5555",
                                subtitle: "Emergency",
                                icon: "exclamationmark.triangle.fill",
                                color: .red,
                                isLast: true
                            )
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                }
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
        .presentationDetents([.medium])
    }
}

// MARK: - Contact Row

struct LockedOutContactRow: View {
    let title: String
    let number: String
    let subtitle: String
    let icon: String
    let color: Color
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(color)
                    .frame(width: 32, height: 32)
                    .background(color.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    // Format number for tel: URL
                    let cleanNumber = number.replacingOccurrences(of: "[^0-9]", with: "", options: .regularExpression)
                    if let url = URL(string: "tel://\(cleanNumber)") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    HStack(spacing: 4) {
                        Text(number)
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(color)
                        Image(systemName: "phone.fill")
                            .font(.system(size: 12))
                            .foregroundColor(color)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(color.opacity(0.12))
                    .cornerRadius(8)
                }
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

// MARK: - Preview

#Preview {
    LockedOutSheet()
}
