import SwiftUI

// MARK: - Group Chat Model

struct GroupChat: Identifiable {
    let id = UUID()
    let name: String
    let icon: String
    let iconColor: Color
    let iconBackground: Color
    let lastMessage: String
    let timestamp: String
    var unreadCount: Int = 0
}

// MARK: - Direct Message Model

struct DirectMessage: Identifiable {
    let id = UUID()
    let personName: String
    let profileImage: String? // Asset name or nil for placeholder
    let lastMessage: String
    let timestamp: String
    var unreadCount: Int = 0
    var isOnline: Bool = false
}

// MARK: - Mock Data

extension GroupChat {
    static let mockGroups: [GroupChat] = [
        GroupChat(
            name: "Residents",
            icon: "figure.2.arms.open",
            iconColor: .white,
            iconBackground: Color(red: 0.4, green: 0.6, blue: 0.9),
            lastMessage: "Thanks for the advice!",
            timestamp: "11:17 AM"
        ),
        GroupChat(
            name: "Basketball Team",
            icon: "basketball.fill",
            iconColor: Color(red: 0.4, green: 0.5, blue: 0.85),
            iconBackground: Color(red: 0.85, green: 0.88, blue: 0.98),
            lastMessage: "It starts at 6.00.",
            timestamp: "9:42 AM"
        ),
        GroupChat(
            name: "Study Group",
            icon: "book.fill",
            iconColor: Color(red: 0.3, green: 0.7, blue: 0.75),
            iconBackground: Color(red: 0.82, green: 0.95, blue: 0.95),
            lastMessage: "Got it, see you all soon",
            timestamp: "Yesterday"
        ),
        GroupChat(
            name: "Book Club",
            icon: "book.closed.fill",
            iconColor: Color(red: 0.85, green: 0.65, blue: 0.4),
            iconBackground: Color(red: 1.0, green: 0.95, blue: 0.85),
            lastMessage: "Which book next?",
            timestamp: "Monday"
        )
    ]
}

extension DirectMessage {
    static let mockDMs: [DirectMessage] = [
        DirectMessage(
            personName: "Hannah",
            profileImage: "hannah",
            lastMessage: "Sure, works for me!",
            timestamp: "11:30 AM"
        ),
        DirectMessage(
            personName: "Jason",
            profileImage: "jason",
            lastMessage: "Are you coming to the bbg?",
            timestamp: "Yesterday"
        ),
        DirectMessage(
            personName: "Sarah",
            profileImage: "sarah",
            lastMessage: "Yes, good luck!",
            timestamp: "Sunday"
        ),
        DirectMessage(
            personName: "Daniel",
            profileImage: "daniel",
            lastMessage: "Nice meeting you too!",
            timestamp: "Saturday"
        )
    ]
}
