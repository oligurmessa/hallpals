import SwiftUI
import PhotosUI

struct AIChatView: View {
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isInputFocused: Bool
    
    // Use ChatStore for persistence
    @StateObject private var chatStore = ChatStore()
    
    @State private var messageText: String = ""
    @State private var isTyping: Bool = false
    
    // Attachment states
    @State private var showingAttachmentOptions: Bool = false
    @State private var showingPhotoPicker: Bool = false
    @State private var showingCamera: Bool = false
    @State private var showingFilePicker: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var attachedImage: UIImage?
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background - tap to dismiss keyboard
                Color(UIColor.systemBackground)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isInputFocused = false
                    }

                VStack(spacing: 0) {
                    // Chat messages
                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(spacing: 20) {
                                if let messages = chatStore.currentSession?.messages {
                                    ForEach(messages) { message in
                                        chatBubble(message: message)
                                    }
                                }

                                // Typing indicator
                                if isTyping {
                                    typingIndicator
                                }
                            }
                            .padding(.horizontal, 20)
                            .padding(.top, 20)
                            .padding(.bottom, 120)
                        }
                        .scrollDismissesKeyboard(.interactively)
                        .onChange(of: chatStore.currentSession?.messages.count) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                        .onChange(of: isTyping) { _ in
                            scrollToBottom(proxy: proxy)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                chatInputBar
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .font(.system(size: 17))
                    .foregroundColor(.primary)
                }

                ToolbarItem(placement: .principal) {
                    Text(chatStore.currentSession?.title ?? "Ask AI")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                }

            }
            .onAppear {
                // Start a new session if none exists
                if chatStore.currentSession == nil {
                    chatStore.startNewSession()
                }
            }
            .confirmationDialog("Add Attachment", isPresented: $showingAttachmentOptions, titleVisibility: .hidden) {
                Button("Photo Library") {
                    showingPhotoPicker = true
                }
                Button("Take Photo") {
                    showingCamera = true
                }
                Button("Choose File") {
                    showingFilePicker = true
                }
                Button("Cancel", role: .cancel) { }
            }
            .photosPicker(isPresented: $showingPhotoPicker, selection: $selectedPhotoItem, matching: .images)
            .onChange(of: selectedPhotoItem) { newItem in
                Task {
                    if let data = try? await newItem?.loadTransferable(type: Data.self),
                       let image = UIImage(data: data) {
                        await MainActor.run {
                            attachedImage = image
                        }
                    }
                }
            }
            .sheet(isPresented: $showingFilePicker) {
                DocumentPickerView { url in
                    // Handle file selection
                    print("Selected file: \(url)")
                }
            }
            .fullScreenCover(isPresented: $showingCamera) {
                CameraView { image in
                    attachedImage = image
                }
            }
        }
    }

    // MARK: - Chat Bubble

    @ViewBuilder
    private func chatBubble(message: ChatMessage) -> some View {
        if message.isUser {
            // User message - right aligned, subtle warm gray card
            HStack {
                Spacer(minLength: 60)

                VStack(alignment: .trailing, spacing: 8) {
                    // Show attached image if present
                    if let image = message.image {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(maxWidth: 200, maxHeight: 150)
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                    }

                    Text(message.text)
                        .font(.system(size: 16))
                        .foregroundColor(.primary)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 18))
            }
            .id(message.id)
        } else {
            // AI message - full width, no background
            VStack(alignment: .leading, spacing: 0) {
                Text(message.text)
                    .font(.system(size: 16, weight: .regular))
                    .foregroundColor(.primary)
                    .lineSpacing(5)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .id(message.id)
        }
    }

    // MARK: - Typing Indicator

    private var typingIndicator: some View {
        HStack(spacing: 5) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                .fill(Color(UIColor.systemGray3))
                .frame(width: 8, height: 8)
                .scaleEffect(1.0)
                .animation(
                    Animation.easeInOut(duration: 0.5)
                        .repeatForever()
                        .delay(Double(index) * 0.15),
                    value: isTyping
                )
            }
            Spacer()
        }
        .padding(.top, 4)
        .id("typing")
    }

    // MARK: - Chat Input Bar

    private var chatInputBar: some View {
        VStack(spacing: 0) {
            // Attached image preview
            if let image = attachedImage {
                HStack {
                    ZStack(alignment: .topTrailing) {
                        Image(uiImage: image)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        Button {
                            attachedImage = nil
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18))
                                .foregroundColor(.white)
                                .background(Circle().fill(Color.black.opacity(0.6)))
                        }
                        .offset(x: 6, y: -6)
                    }
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 12)
                .padding(.bottom, 8)
            }

            // Divider
            Rectangle()
                .fill(Color(UIColor.separator).opacity(0.2))
                .frame(height: 0.5)

            HStack(alignment: .center, spacing: 12) {
                // Attach button
                Button {
                    showingAttachmentOptions = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(Color(UIColor.systemGray3))
                }

                // Input field container
                HStack(alignment: .center, spacing: 0) {
                    TextField("Message", text: $messageText, axis: .vertical)
                        .font(.system(size: 16))
                        .lineLimit(1...6)
                        .textFieldStyle(.plain)
                        .focused($isInputFocused)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                }
                .background(Color(UIColor.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 20))

                // Send button
                Button {
                    sendMessage()
                } label: {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 32))
                        .foregroundColor(canSend ? .primary : Color(UIColor.systemGray4))
                }
                .disabled(!canSend)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(UIColor.systemBackground))
        }
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || attachedImage != nil
    }

    // MARK: - Actions

    private func sendMessage() {
        let sentText = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sentText.isEmpty || attachedImage != nil else { return }

        // Add user message via Store
        chatStore.addMessage(sentText, isUser: true, image: attachedImage)

        messageText = ""
        attachedImage = nil

        // Show typing indicator
        isTyping = true

        // Call AI service (system prompt is configured in backend)
        Task {
            do {
                let response = try await CloudFunctionsService.shared.askAI(
                    prompt: sentText.isEmpty ? "The user shared an image without text." : sentText
                )

                await MainActor.run {
                    isTyping = false
                    chatStore.addMessage(response.response, isUser: false)
                }
            } catch {
                await MainActor.run {
                    isTyping = false
                    let errorMessage = "Sorry, I couldn't process your request. Please try again later.\n\nError: \(error.localizedDescription)"
                    chatStore.addMessage(errorMessage, isUser: false)
                }
            }
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        withAnimation(.easeOut(duration: 0.25)) {
            if isTyping {
                proxy.scrollTo("typing", anchor: .bottom)
            } else if let lastId = chatStore.currentSession?.messages.last?.id {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

// MARK: - Document Picker

struct DocumentPickerView: UIViewControllerRepresentable {
    var onPick: (URL) -> Void

    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forOpeningContentTypes: [.item])
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onPick: onPick)
    }

    class Coordinator: NSObject, UIDocumentPickerDelegate {
        var onPick: (URL) -> Void

        init(onPick: @escaping (URL) -> Void) {
            self.onPick = onPick
        }

        func documentPicker(_ controller: UIDocumentPickerViewController, didPickDocumentsAt urls: [URL]) {
            if let url = urls.first {
                onPick(url)
            }
        }
    }
}

// MARK: - Camera View

struct CameraView: UIViewControllerRepresentable {
    @Environment(\.dismiss) private var dismiss
    var onCapture: (UIImage) -> Void

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(dismiss: dismiss, onCapture: onCapture)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        var dismiss: DismissAction
        var onCapture: (UIImage) -> Void

        init(dismiss: DismissAction, onCapture: @escaping (UIImage) -> Void) {
            self.dismiss = dismiss
            self.onCapture = onCapture
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onCapture(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}

#Preview {
    AIChatView()
}
