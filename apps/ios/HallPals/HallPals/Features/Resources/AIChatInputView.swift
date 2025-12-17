import SwiftUI

/// Modern minimal chat input bar - iOS 18 style
/// Clean grayscale design with attach and send buttons
struct AIChatInputView: View {
    @Binding var text: String
    var onSend: () -> Void
    var onAttach: (() -> Void)?
    @FocusState private var isFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Subtle divider
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.2))
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 12) {
                // Attach button
                if let onAttach = onAttach {
                    Button(action: onAttach) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 28))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                }

                // Input field container
                HStack(alignment: .center, spacing: 0) {
                    TextField("Message", text: $text, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...6)
                        .textFieldStyle(.plain)
                        .focused($isFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Send button
                Button {
                    guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
                    onSend()
                    isFocused = false
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? Color(UIColor.systemGray4) : .primary)
                }
                .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }
}

#Preview {
    VStack {
        Spacer()
        AIChatInputView(
            text: .constant(""),
            onSend: { print("Send") },
            onAttach: { print("Attach") }
        )
    }
    .background(Color(UIColor.systemBackground))
}
