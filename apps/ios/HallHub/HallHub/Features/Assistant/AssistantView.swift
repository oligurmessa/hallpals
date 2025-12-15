import SwiftUI

struct AssistantView: View {
    @EnvironmentObject private var roleManager: RoleManager

    var body: some View {
        Group {
            if let role = roleManager.selectedRole {
                switch role {
                case .ra:
                    ChatAssistantView(role: role)
                case .resident:
                    ResidentAssistantView()
                }
            } else {
                // Brief loading while role syncs from AppState
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}

// MARK: - Chat Assistant View (RA)

struct ChatAssistantView: View {
    @StateObject private var viewModel: AssistantViewModel
    @FocusState private var isInputFocused: Bool

    init(role: UserRole) {
        _viewModel = StateObject(wrappedValue: AssistantViewModel(role: role))
    }

    private var subtitle: String {
        switch viewModel.role {
        case .ra:
            return "Quick guidance for duty situations (mock)"
        case .resident:
            return "Help with hall life questions"
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Subtitle header
                HStack {
                    Text(subtitle)
                        .appStyle(.caption, color: .textSecondary)
                    Spacer()
                }
                .padding(.horizontal, AppSpacing.md)
                .padding(.vertical, AppSpacing.sm)
                .background(Color.appSurface)

                // Messages area
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: AppSpacing.md) {
                            ForEach(viewModel.messages) { message in
                                AssistantMessageBubble(message: message)
                                    .id(message.id)
                            }
                        }
                        .padding(AppSpacing.md)
                    }
                    .background(Color.appBackground)
                    .onChange(of: viewModel.messages.count) { _, _ in
                        if let lastMessage = viewModel.messages.last {
                            withAnimation(.easeOut(duration: 0.3)) {
                                proxy.scrollTo(lastMessage.id, anchor: .bottom)
                            }
                        }
                    }
                }

                // Suggested prompts
                suggestedPromptsBar

                // Input area
                inputBar
            }
            .navigationTitle("Assistant")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Text(viewModel.role.shortName)
                        .appStyle(.label, color: .textSecondary)
                        .padding(.horizontal, AppSpacing.sm)
                        .padding(.vertical, AppSpacing.xs)
                        .background(Color.appPrimary.opacity(0.1))
                        .cornerRadius(AppRadius.chip)
                }
            }
        }
    }

    private var suggestedPromptsBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: AppSpacing.sm) {
                ForEach(viewModel.suggestedPrompts) { prompt in
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            viewModel.sendMessage(prompt.text)
                        }
                    } label: {
                        Text(prompt.text)
                            .appStyle(.label, color: .appPrimary)
                            .padding(.horizontal, AppSpacing.sm)
                            .padding(.vertical, AppSpacing.xs)
                            .background(Color.appPrimary.opacity(0.1))
                            .cornerRadius(AppRadius.chip)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, AppSpacing.md)
            .padding(.vertical, AppSpacing.sm)
        }
        .background(Color.appSurface.opacity(0.5))
    }

    private var inputBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack(spacing: AppSpacing.sm) {
                TextField("Ask a question...", text: $viewModel.inputText)
                    .textFieldStyle(.plain)
                    .appFont(.body)
                    .padding(AppSpacing.sm)
                    .background(Color.appBackground)
                    .cornerRadius(AppRadius.input)
                    .focused($isInputFocused)
                    .onSubmit {
                        sendCurrentMessage()
                    }

                Button {
                    sendCurrentMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty ? .textSecondary : .appPrimary)
                }
                .disabled(viewModel.inputText.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding(AppSpacing.md)
            .background(Color.appSurface)
        }
    }

    private func sendCurrentMessage() {
        let text = viewModel.inputText.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        withAnimation(.easeInOut(duration: 0.2)) {
            viewModel.sendMessage(text)
        }
    }
}

// MARK: - Message Bubble

struct AssistantMessageBubble: View {
    let message: AssistantMessage

    private var isUser: Bool {
        message.sender == .user
    }

    var body: some View {
        HStack {
            if isUser { Spacer(minLength: 60) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: AppSpacing.xs) {
                Text(message.text)
                    .appStyle(.body, color: isUser ? .white : .textPrimary)
                    .padding(AppSpacing.md)
                    .background(isUser ? Color.appPrimary : Color.appSurface)
                    .cornerRadius(AppRadius.card)

                Text(message.timestamp, style: .time)
                    .appStyle(.label, color: .textSecondary)
            }

            if !isUser { Spacer(minLength: 60) }
        }
    }
}

#Preview("RA Assistant") {
    AssistantView()
        .environmentObject({
            let rm = RoleManager()
            rm.selectRole(.ra)
            return rm
        }())
}

#Preview("Resident Assistant") {
    AssistantView()
        .environmentObject({
            let rm = RoleManager()
            rm.selectRole(.resident)
            return rm
        }())
}
