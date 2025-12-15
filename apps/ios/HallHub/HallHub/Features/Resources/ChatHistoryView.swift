import SwiftUI

struct ChatHistoryView: View {
    @EnvironmentObject var chatStore: ChatStore
    @Environment(\.dismiss) private var dismiss
    
    var onSelectSession: (ChatSession) -> Void
    
    var body: some View {
        NavigationStack {
            List {
                if chatStore.sessions.isEmpty {
                    emptyState
                } else {
                    ForEach(chatStore.sessions) { session in
                        Button {
                            onSelectSession(session)
                            dismiss()
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(session.title)
                                    .font(.headline)
                                    .lineLimit(1)
                                    .foregroundColor(.primary)
                                
                                HStack {
                                    Text(session.messages.last?.text ?? "No messages")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                    
                                    Spacer()
                                    
                                    Text(session.dateString)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete(perform: chatStore.deleteSession)
                }
            }
            .navigationTitle("History")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button {
                        chatStore.startNewSession()
                        dismiss()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                }
            }
        }
    }
    
    private var emptyState: some View {
        VStack(spacing: 20) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text("No past conversations")
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .listRowBackground(Color.clear)
    }
}
