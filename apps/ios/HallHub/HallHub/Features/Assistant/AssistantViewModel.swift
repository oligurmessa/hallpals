import Foundation
import SwiftUI

final class AssistantViewModel: ObservableObject {
    @Published var messages: [AssistantMessage] = []
    @Published var inputText: String = ""

    let role: UserRole

    var suggestedPrompts: [SuggestedPrompt] {
        switch role {
        case .ra:
            return [
                SuggestedPrompt(text: "What do I do for an alcohol incident?"),
                SuggestedPrompt(text: "How do I handle a lockout?"),
                SuggestedPrompt(text: "What should I say during rounds?"),
                SuggestedPrompt(text: "How do I respond to a noise complaint?"),
                SuggestedPrompt(text: "What if a resident seems depressed?")
            ]
        case .resident:
            return [
                SuggestedPrompt(text: "What do I do if I'm locked out?"),
                SuggestedPrompt(text: "Who do I call in an emergency?"),
                SuggestedPrompt(text: "What are quiet hours?")
            ]
        }
    }

    init(role: UserRole) {
        self.role = role
        seedWelcomeMessage()
    }

    private func seedWelcomeMessage() {
        let welcomeText: String
        switch role {
        case .ra:
            welcomeText = "Hi! I'm your RA Assistant. I can help you with duty situations, protocols, and quick guidance. Try asking about lockouts, alcohol incidents, rounds, or mental health concerns. What can I help you with?"
        case .resident:
            welcomeText = "Hi there! I can help answer common questions about hall life. Ask me about lockouts, quiet hours, emergencies, or how to reach your RA."
        }

        messages.append(AssistantMessage(
            sender: .assistant,
            text: welcomeText
        ))
    }

    func sendMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Add user message
        let userMessage = AssistantMessage(sender: .user, text: trimmed)
        messages.append(userMessage)

        // Clear input
        inputText = ""

        // Generate and add mock response
        let response = generateMockResponse(for: trimmed)
        messages.append(response)
    }

    private func generateMockResponse(for text: String) -> AssistantMessage {
        let lowercased = text.lowercased()

        let responseText: String

        // Lockout keywords
        if lowercased.contains("lockout") || lowercased.contains("locked out") || lowercased.contains("lock out") || lowercased.contains("lost key") || lowercased.contains("forgot key") {
            responseText = """
            For a lockout situation:

            1. Verify the resident's identity with their student ID
            2. Check the roster to confirm they live in that room
            3. Use your master key to let them in (or contact the RA on duty if you're not on duty)
            4. Document the lockout in your log with time and room number
            5. Remind them about the lockout fee policy if this is a repeat occurrence

            You can find more details in the SLED section under "Lockouts" in the Resources tab.
            """
        }
        // Alcohol keywords
        else if lowercased.contains("alcohol") || lowercased.contains("drinking") || lowercased.contains("drunk") || lowercased.contains("intoxicated") {
            responseText = """
            For an alcohol incident:

            1. Stay calm and assess the situation for safety first
            2. If someone appears to have alcohol poisoning (unconscious, difficulty breathing, vomiting while passed out), call 911 immediately
            3. For standard policy violations, document what you observe (not accusations)
            4. Confiscate any visible alcohol and note the type/quantity
            5. Follow up with an incident report and notify your supervisor
            6. Remember: student safety always comes before policy enforcement

            Check the Protocols section for detailed alcohol response procedures.
            """
        }
        // Rounds keywords
        else if lowercased.contains("round") || lowercased.contains("patrol") || lowercased.contains("duty walk") {
            responseText = """
            Tips for effective rounds:

            1. Check all common areas, stairwells, and bathrooms
            2. Listen for excessive noise and address proactively
            3. Look for propped doors, safety hazards, or anything unusual
            4. Greet residents you see - it builds community
            5. Document your rounds with times and any observations
            6. Vary your timing slightly to be less predictable

            Standard rounds are typically every 2 hours during duty hours. Check with your supervisor for your building's specific schedule.
            """
        }
        // Mental health keywords
        else if lowercased.contains("mental health") || lowercased.contains("suicid") || lowercased.contains("self harm") || lowercased.contains("depressed") || lowercased.contains("crisis") || lowercased.contains("harm themselves") {
            responseText = """
            This is a sensitive situation. Here's guidance:

            1. Stay with the resident if it's safe to do so
            2. Listen without judgment - don't try to "fix" or minimize
            3. Do NOT promise confidentiality if there's risk of harm
            4. Contact your professional staff on duty or Hall Director immediately
            5. If there's immediate danger, call Campus Safety (651-962-5100) or 911

            You're not expected to be a counselor. Your role is to connect them with professional help. The Counseling Center crisis line is 651-962-6780.

            Take care of yourself too - debrief with your supervisor after.
            """
        }
        // Noise keywords
        else if lowercased.contains("noise") || lowercased.contains("loud") || lowercased.contains("quiet hour") || lowercased.contains("party") {
            responseText = """
            For noise complaints:

            1. Approach the room calmly and knock
            2. Introduce yourself and explain you received a complaint
            3. Ask them to lower the volume - be friendly but firm
            4. Document the interaction in your log
            5. If noise continues after 30 minutes, follow up again
            6. Escalate to your supervisor after the second visit

            Quiet hours: Sun-Thu 10 PM - 8 AM, Fri-Sat 12 AM - 10 AM. Courtesy hours are 24/7.
            """
        }
        // Roommate conflict keywords
        else if lowercased.contains("roommate") || lowercased.contains("conflict") || lowercased.contains("room mate") {
            responseText = """
            For roommate conflicts:

            1. Meet with each roommate individually first to understand perspectives
            2. Then facilitate a conversation together if appropriate
            3. Help them create or revisit their roommate agreement
            4. Focus on behaviors, not personalities
            5. Document the conversation and any agreements made
            6. Follow up in a week to see how things are going

            If the conflict is serious or ongoing, involve your supervisor for a formal mediation or room change discussion.
            """
        }
        // Emergency keywords
        else if lowercased.contains("emergency") || lowercased.contains("911") || lowercased.contains("fire") || lowercased.contains("medical") {
            responseText = """
            For emergencies:

            • Life-threatening emergency: Call 911 first, then Campus Safety
            • Campus Safety (24/7): 651-962-5100
            • Fire: Pull alarm, evacuate, call 911
            • Medical: Assess scene safety, call 911 if serious, provide basic first aid if trained

            After any emergency, notify your supervisor immediately and complete an incident report.

            Your safety comes first - don't put yourself in danger.
            """
        }
        // Staff-specific: missed rounds
        else if lowercased.contains("missed round") || lowercased.contains("skip round") {
            responseText = """
            Addressing missed rounds with an RA:

            1. Have a private, non-confrontational conversation
            2. Ask about what happened - there may be context you're unaware of
            3. Review expectations and the importance of rounds for safety
            4. Document the conversation
            5. If it's a pattern, follow progressive accountability steps
            6. Offer support - are they overwhelmed? Need schedule adjustments?

            Frame it as coaching, not punishment. RAs perform better with support than criticism.
            """
        }
        // Staff-specific: documentation
        else if lowercased.contains("document") || lowercased.contains("report") || lowercased.contains("pattern") {
            responseText = """
            Documentation best practices:

            1. Record facts, not interpretations or judgments
            2. Include: date, time, location, who was involved, what happened
            3. Use direct quotes when possible
            4. Note any follow-up actions taken or needed
            5. Complete reports within 24 hours while details are fresh
            6. For patterns, cross-reference previous incidents in your notes

            Good documentation protects everyone - the student, you, and the institution.
            """
        }
        // Training/resources
        else if lowercased.contains("training") || lowercased.contains("resource") || lowercased.contains("learn") {
            responseText = """
            Training resources available:

            • SLED Quick Reference in the Resources tab
            • Protocol guides for common situations
            • Your supervisor for 1:1 coaching
            • Weekly staff meetings for case discussions
            • Behind Closed Doors scenarios (ask your HD)

            For specific training requests, talk to your supervisor about professional development opportunities.
            """
        }
        // Generic fallback
        else {
            responseText = """
            I'm not sure about that specific question, but here are some resources:

            • Check the Resources tab for SLED guides and protocols
            • Your supervisor is always available for complex situations
            • Campus Safety (651-962-5100) for urgent matters
            • The Counseling Center for mental health concerns

            Feel free to ask me about lockouts, alcohol incidents, rounds, noise complaints, roommate conflicts, or mental health concerns - I have specific guidance for those topics.
            """
        }

        return AssistantMessage(
            sender: .assistant,
            text: responseText
        )
    }
}
