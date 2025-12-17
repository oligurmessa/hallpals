import SwiftUI

// MARK: - Knowledge Base Models
struct KBEntry: Codable, Identifiable {
    let id: String
    let topic: String
    let section: String
    let text: String
    let sources: [KBSource]
    
    enum CodingKeys: String, CodingKey {
        case id = "canonical_id"
        case topic
        case section
        case text
        case sources
    }
}

struct KBSource: Codable {
    let sourceDocId: String
    let path: String
    let location: String
    
    enum CodingKeys: String, CodingKey {
        case sourceDocId = "source_doc_id"
        case path
        case location
    }
}

enum KBTopic: String, CaseIterable, Identifiable {
    case duty = "Duty & On-Call"
    case emergencies = "Emergencies"
    case facilities = "Facilities"
    case general = "General"
    case housing = "Housing"
    case incidents = "Incidents"
    case moveInOut = "Move-in/out"
    case policies = "Policies"
    case procedures = "Procedures"
    case safety = "Safety"
    case studentConduct = "Student Conduct"
    case training = "Training"
    
    var id: String { rawValue }
    
    var icon: String {
        switch self {
        case .duty: return "phone.badge.plus"
        case .emergencies: return "exclamationmark.triangle.fill"
        case .facilities: return "wrench.and.screwdriver.fill"
        case .general: return "info.circle.fill"
        case .housing: return "house.fill"
        case .incidents: return "notebook.fill"
        case .moveInOut: return "box.truck.fill"
        case .policies: return "scroll.fill"
        case .procedures: return "list.bullet.clipboard.fill"
        case .safety: return "shield.fill"
        case .studentConduct: return "gavel.fill"
        case .training: return "graduationcap.fill"
        }
    }
    
    var color: Color {
        switch self {
        case .duty: return .blue
        case .emergencies: return .red
        case .facilities: return .orange
        case .general: return .gray
        case .housing: return .purple
        case .incidents: return .pink
        case .moveInOut: return .green
        case .policies: return .blue
        case .procedures: return .indigo
        case .safety: return .mint
        case .studentConduct: return .brown
        case .training: return .cyan
        }
    }
    
    var slug: String {
        switch self {
        case .duty: return "duty_&_on-call"
        case .emergencies: return "emergencies"
        case .facilities: return "facilities"
        case .general: return "general"
        case .housing: return "housing"
        case .incidents: return "incidents"
        case .moveInOut: return "move-in_out"
        case .policies: return "policies"
        case .procedures: return "procedures"
        case .safety: return "safety"
        case .studentConduct: return "student_conduct"
        case .training: return "training"
        }
    }
}

// MARK: - SLED Category

enum SLEDCategory: String, CaseIterable, Identifiable {
    case emergency = "Emergency"
    case lockout = "Lockout"
    case wellness = "Wellness"
    case communityStandard = "Community Standard"
    case facilities = "Facilities"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .emergency: return "exclamationmark.triangle.fill"
        case .lockout: return "key.fill"
        case .wellness: return "heart.fill"
        case .communityStandard: return "person.2.fill"
        case .facilities: return "wrench.fill"
        }
    }

    var color: Color {
        switch self {
        case .emergency: return .appError
        case .lockout: return .appSecondary
        case .wellness: return .appSuccess
        case .communityStandard: return .appPrimary
        case .facilities: return .textSecondary
        }
    }
}

// MARK: - Protocol Category

enum ProtocolCategory: String, CaseIterable, Identifiable {
    case emergency = "Emergency"
    case alcohol = "Alcohol & Substances"
    case noise = "Noise & Quiet Hours"
    case roommateConflict = "Roommate Conflict"
    case mentalHealth = "Mental Health"
    case facilities = "Facilities"
    case communityStandard = "Community Standards"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .emergency: return "exclamationmark.shield.fill"
        case .alcohol: return "drop.triangle.fill"
        case .noise: return "speaker.wave.3.fill"
        case .roommateConflict: return "person.2.slash.fill"
        case .mentalHealth: return "brain.head.profile"
        case .facilities: return "hammer.fill"
        case .communityStandard: return "person.2.fill"
        }
    }
}

// MARK: - Priority Level

enum PriorityLevel: Int, CaseIterable, Identifiable {
    case low = 1
    case medium = 2
    case high = 3
    case critical = 4

    var id: Int { rawValue }

    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        case .critical: return "Critical"
        }
    }

    var color: Color {
        switch self {
        case .low: return .textSecondary
        case .medium: return .appSecondary
        case .high: return .appWarning
        case .critical: return .appError
        }
    }
}

// MARK: - SLED Item

struct SLEDItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let summary: String
    let category: SLEDCategory
    let priorityLevel: PriorityLevel
    let phoneNumber: String?
    let tags: [String]
    let steps: [String]
}

// MARK: - Protocol Item

struct ProtocolItem: Identifiable, Hashable {
    let id: UUID
    let title: String
    let category: ProtocolCategory
    let shortDescription: String
    let steps: [String]
    let isStaffOnly: Bool
}

// MARK: - Quick Link

struct QuickLink: Identifiable, Hashable {
    let id: UUID
    let title: String
    let subtitle: String
    let systemImageName: String
    let urlString: String
    let visibleToRoles: [UserRole]
}

// MARK: - Roster Entry

struct RosterEntry: Identifiable, Hashable {
    let id: UUID
    let name: String
    let room: String
    let status: ResidentStatus
    let notes: String
    let isFlagged: Bool
    let raName: String

    enum ResidentStatus: String {
        case onCampus = "On Campus"
        case abroad = "Abroad"
        case commuter = "Commuter"
        case quietConcern = "Quiet Concern"
        case awayThisWeek = "Away This Week"

        var color: Color {
            switch self {
            case .onCampus: return .appSuccess
            case .abroad, .commuter, .awayThisWeek: return .textSecondary
            case .quietConcern: return .appWarning
            }
        }
    }
}

// MARK: - Resource Store

@MainActor
class ResourceStore: ObservableObject {
    @Published var sledItems: [SLEDItem]
    @Published var protocols: [ProtocolItem]
    @Published var quickLinks: [QuickLink]
    @Published var rosterEntries: [RosterEntry]
    @Published var docMetas: [DocMeta] = []
    @Published var docsError: String?

    init() {
        // Initialize properties first
        self.docMetas = []

        // SLED Items
        self.sledItems = [
            SLEDItem(
                id: UUID(),
                title: "Medical Emergency",
                summary: "Life-threatening situations requiring immediate medical attention. Call 911 first, then Campus Safety.",
                category: .emergency,
                priorityLevel: .critical,
                phoneNumber: "911",
                tags: ["medical", "ambulance", "injury"],
                steps: [
                    "Ensure the scene is safe for you to approach",
                    "Call 911 immediately for life-threatening emergencies",
                    "Call Campus Safety at (651) 962-5555",
                    "Stay with the person and provide basic first aid if trained",
                    "Send someone to meet emergency responders",
                    "Document the incident after the situation is stable"
                ]
            ),
            SLEDItem(
                id: UUID(),
                title: "Fire Alarm / Fire",
                summary: "Evacuate immediately. Do not use elevators. Meet at designated assembly point.",
                category: .emergency,
                priorityLevel: .critical,
                phoneNumber: "(651) 962-5555",
                tags: ["fire", "evacuation", "alarm"],
                steps: [
                    "Activate the fire alarm if not already sounding",
                    "Evacuate the building using stairs only",
                    "Close doors behind you (do not lock)",
                    "Meet at designated assembly area",
                    "Account for all residents on your floor",
                    "Report to Campus Safety and await instructions"
                ]
            ),
            SLEDItem(
                id: UUID(),
                title: "Student Lockout",
                summary: "Verify student identity before providing access. Document all lockouts.",
                category: .lockout,
                priorityLevel: .low,
                phoneNumber: nil,
                tags: ["lockout", "key", "access"],
                steps: [
                    "Verify student identity with TommieCard",
                    "Confirm room assignment in system",
                    "Provide temporary access",
                    "Document lockout in daily log",
                    "First 2 lockouts per semester are free",
                    "After 2: Inform student of $25 fee"
                ]
            ),
            SLEDItem(
                id: UUID(),
                title: "Wellness Check",
                summary: "When concerned about a student's wellbeing. Document observations and follow up.",
                category: .wellness,
                priorityLevel: .high,
                phoneNumber: "(651) 962-6780",
                tags: ["wellness", "concern", "mental health"],
                steps: [
                    "Knock and identify yourself as the RA",
                    "Express care and concern without judgment",
                    "Ask open-ended questions",
                    "Offer campus resources (Counseling Center)",
                    "Document observations in incident report",
                    "Follow up within 24-48 hours"
                ]
            ),
            SLEDItem(
                id: UUID(),
                title: "Noise Complaint",
                summary: "Address noise violations during quiet hours. Use progressive response.",
                category: .communityStandard,
                priorityLevel: .medium,
                phoneNumber: nil,
                tags: ["noise", "quiet hours", "party"],
                steps: [
                    "Approach the door calmly",
                    "Knock and identify yourself",
                    "Request they lower the volume",
                    "First offense: Verbal warning",
                    "Second offense: Document and report",
                    "Continued violation: Contact duty phone"
                ]
            ),
            SLEDItem(
                id: UUID(),
                title: "Maintenance Emergency",
                summary: "Flooding, power outage, or safety hazard. Contact facilities immediately.",
                category: .facilities,
                priorityLevel: .high,
                phoneNumber: "(651) 962-6500",
                tags: ["maintenance", "flooding", "power"],
                steps: [
                    "Assess immediate safety risks",
                    "Evacuate affected area if necessary",
                    "Call Facilities emergency line",
                    "Notify Campus Safety if after hours",
                    "Document damage with photos",
                    "Assist affected residents with relocation if needed"
                ]
            )
        ]

        // Protocols
        self.protocols = [
            ProtocolItem(
                id: UUID(),
                title: "Active Threat Response",
                category: .emergency,
                shortDescription: "Run, Hide, Fight protocol for active threat situations",
                steps: [
                    "RUN: If there is an escape path, attempt to evacuate",
                    "Leave belongings behind",
                    "Help others escape if possible",
                    "Prevent others from entering the area",
                    "HIDE: If evacuation is not possible, find a hiding place",
                    "Lock and blockade doors",
                    "Silence your phone",
                    "FIGHT: As a last resort, attempt to incapacitate the threat",
                    "Call 911 when safe"
                ],
                isStaffOnly: false
            ),
            ProtocolItem(
                id: UUID(),
                title: "Alcohol Policy Violation",
                category: .alcohol,
                shortDescription: "Response to underage drinking or alcohol policy violations",
                steps: [
                    "Assess the situation for medical emergencies first",
                    "If medical concern, call for help immediately",
                    "Document names and room numbers of those involved",
                    "Request all alcohol be disposed of properly",
                    "Do not confiscate alcohol yourself",
                    "Complete incident report within 24 hours",
                    "Submit report to Residence Life"
                ],
                isStaffOnly: false
            ),
            ProtocolItem(
                id: UUID(),
                title: "Medical Amnesty Guidelines",
                category: .alcohol,
                shortDescription: "When and how medical amnesty applies",
                steps: [
                    "Medical amnesty applies when student seeks help for themselves or others",
                    "Student must cooperate with staff and medical personnel",
                    "Document that amnesty was requested",
                    "Still complete incident report",
                    "Student must complete follow-up meeting with Residence Life",
                    "Amnesty does not apply to other policy violations"
                ],
                isStaffOnly: true
            ),
            ProtocolItem(
                id: UUID(),
                title: "Quiet Hours Enforcement",
                category: .noise,
                shortDescription: "Progressive response to quiet hours violations",
                steps: [
                    "Quiet Hours: Sun-Thu 10PM-8AM, Fri-Sat 12AM-10AM",
                    "Courtesy Hours are 24/7",
                    "First violation: Verbal warning and documentation",
                    "Second violation: Written warning",
                    "Third violation: Referral to Residence Life",
                    "Repeated violations may result in housing probation"
                ],
                isStaffOnly: false
            ),
            ProtocolItem(
                id: UUID(),
                title: "Roommate Mediation",
                category: .roommateConflict,
                shortDescription: "Facilitating productive roommate conversations",
                steps: [
                    "Meet with each roommate individually first",
                    "Identify specific issues and concerns",
                    "Schedule joint mediation at neutral time",
                    "Set ground rules: respectful language, active listening",
                    "Focus on behaviors, not personalities",
                    "Help create written roommate agreement",
                    "Schedule follow-up check-in",
                    "Escalate to Residence Life if unresolved"
                ],
                isStaffOnly: false
            ),
            ProtocolItem(
                id: UUID(),
                title: "Suicide Risk Assessment",
                category: .mentalHealth,
                shortDescription: "Recognizing warning signs and appropriate response",
                steps: [
                    "Take all mentions of suicide seriously",
                    "Ask directly: 'Are you thinking about hurting yourself?'",
                    "Listen without judgment",
                    "Do not leave the person alone if at immediate risk",
                    "Call Counseling Center: (651) 962-6780",
                    "After hours: Call Campus Safety for crisis response",
                    "Complete incident report",
                    "Self-care: Debrief with supervisor after incident"
                ],
                isStaffOnly: true
            ),
            ProtocolItem(
                id: UUID(),
                title: "Work Order Submission",
                category: .facilities,
                shortDescription: "How to submit and track maintenance requests",
                steps: [
                    "Log into TommieLink portal",
                    "Navigate to Facilities > Work Order",
                    "Select building and room",
                    "Describe issue in detail",
                    "Mark urgency level appropriately",
                    "Emergency issues: Call Facilities directly",
                    "Follow up if not addressed within 48 hours"
                ],
                isStaffOnly: false
            )
        ]

        // Quick Links
        self.quickLinks = [
            QuickLink(
                id: UUID(),
                title: "Roompact",
                subtitle: "Community standards",
                systemImageName: "doc.text.fill",
                urlString: "https://roompact.com",
                visibleToRoles: [.ra]
            ),
            QuickLink(
                id: UUID(),
                title: "Advocate",
                subtitle: "Incident reporting system",
                systemImageName: "exclamationmark.bubble.fill",
                urlString: "https://services.stthomas.edu/TDClient/1898/ClientPortal/KB/ArticleDet?ID=106674#CallTechDesk",
                visibleToRoles: [.ra]
            ),
            QuickLink(
                id: UUID(),
                title: "RFS / Maintenance",
                subtitle: "Request facility service",
                systemImageName: "hammer.fill",
                urlString: "https://rmsstudent.stthomas.edu/page/HousingPortal",
                visibleToRoles: [.ra, .resident]
            ),
            QuickLink(
                id: UUID(),
                title: "Tommie Link",
                subtitle: "Campus portal",
                systemImageName: "link.circle.fill",
                urlString: "https://tommielink.stthomas.edu",
                visibleToRoles: [.ra, .resident]
            ),
            QuickLink(
                id: UUID(),
                title: "Murphy Online",
                subtitle: "Student information system",
                systemImageName: "graduationcap.fill",
                urlString: "https://experience.elluciancloud.com/uofstthomasmn",
                visibleToRoles: [.ra, .resident]
            ),
            QuickLink(
                id: UUID(),
                title: "One St. Thomas",
                subtitle: "University portal",
                systemImageName: "person.crop.circle.fill",
                urlString: "https://one.stthomas.edu",
                visibleToRoles: [.ra, .resident]
            ),
            QuickLink(
                id: UUID(),
                title: "Campus Safety",
                subtitle: "Security & escort services",
                systemImageName: "shield.fill",
                urlString: "tel:6519625555",
                visibleToRoles: [.ra, .resident]
            ),

            QuickLink(
                id: UUID(),
                title: "Roompact",
                subtitle: "Community standards",
                systemImageName: "doc.text.fill",
                urlString: "https://roompact.com",
                visibleToRoles: [.ra]
            ),
            QuickLink(
                id: UUID(),
                title: "Conduct Board",
                subtitle: "Student conduct resources",
                systemImageName: "person.badge.shield.checkmark.fill",
                urlString: "https://stthomas.edu/conduct",
                visibleToRoles: [.ra]
            ),
            QuickLink(
                id: UUID(),
                title: "Academic Support",
                subtitle: "Tutoring & study resources",
                systemImageName: "book.fill",
                urlString: "https://stthomas.edu/academic-support",
                visibleToRoles: [.resident]
            ),
            QuickLink(
                id: UUID(),
                title: "Title IX Reporting",
                subtitle: "Report discrimination",
                systemImageName: "hand.raised.fill",
                urlString: "https://stthomas-advocate.symplicity.com/titleix_report/index.php/pid946796?rep_type=2",
                visibleToRoles: [.ra, .resident]
            )
        ]

        // Roster Entries
        self.rosterEntries = [
            RosterEntry(
                id: UUID(),
                name: "Jordan Williams",
                room: "214",
                status: .onCampus,
                notes: "First-year student, adjusting well",
                isFlagged: false,
                raName: "Alex Martinez"
            ),
            RosterEntry(
                id: UUID(),
                name: "Casey Thompson",
                room: "216",
                status: .onCampus,
                notes: "On the swim team, often at practice",
                isFlagged: false,
                raName: "Alex Martinez"
            ),
            RosterEntry(
                id: UUID(),
                name: "Morgan Lee",
                room: "218",
                status: .quietConcern,
                notes: "Has been isolated recently. Check in this week.",
                isFlagged: true,
                raName: "Alex Martinez"
            ),
            RosterEntry(
                id: UUID(),
                name: "Taylor Chen",
                room: "220",
                status: .abroad,
                notes: "Studying in London this semester",
                isFlagged: false,
                raName: "Alex Martinez"
            ),
            RosterEntry(
                id: UUID(),
                name: "Riley Johnson",
                room: "222",
                status: .onCampus,
                notes: "Very engaged, helps with floor events",
                isFlagged: false,
                raName: "Alex Martinez"
            ),
            RosterEntry(
                id: UUID(),
                name: "Sam Rodriguez",
                room: "224",
                status: .awayThisWeek,
                notes: "Home for family event, returns Sunday",
                isFlagged: false,
                raName: "Alex Martinez"
            ),
            RosterEntry(
                id: UUID(),
                name: "Alex Kim",
                room: "226",
                status: .onCampus,
                notes: "Roommate conflict resolved last month",
                isFlagged: false,
                raName: "Alex Martinez"
            ),
            RosterEntry(
                id: UUID(),
                name: "Jamie Parker",
                room: "228",
                status: .quietConcern,
                notes: "Missed several floor meetings. Follow up needed.",
                isFlagged: true,
                raName: "Alex Martinez"
            )
        ]
    }

    // MARK: - Search

    func searchSLED(text: String) -> [SLEDItem] {
        guard !text.isEmpty else { return sledItems }
        let lowercased = text.lowercased()
        return sledItems.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.summary.lowercased().contains(lowercased) ||
            $0.tags.contains { $0.lowercased().contains(lowercased) }
        }
    }

    func searchProtocols(text: String) -> [ProtocolItem] {
        guard !text.isEmpty else { return protocols }
        let lowercased = text.lowercased()
        return protocols.filter {
            $0.title.lowercased().contains(lowercased) ||
            $0.shortDescription.lowercased().contains(lowercased)
        }
    }

    func quickLinks(for role: UserRole) -> [QuickLink] {
        quickLinks.filter { $0.visibleToRoles.contains(role) }
    }

    func protocols(for role: UserRole) -> [ProtocolItem] {
        return protocols.filter { !$0.isStaffOnly }
    }

    func flaggedResidents() -> [RosterEntry] {
        rosterEntries.filter { $0.isFlagged }
    }

    func fetchDocs() async {
        docsError = nil
        do {
            #if DEBUG
            print("📚 ResourceStore: Fetching docs from Firestore...")
            // Debug: Check user's role first
            await DocsService.shared.debugCheckUserRole()
            #endif
            let docs = try await DocsService.shared.fetchAllDocs()
            #if DEBUG
            print("📚 ResourceStore: Fetched \(docs.count) docs")
            for doc in docs {
                print("   - \(doc.title) (\(doc.slug)) - category: \(doc.category)")
            }
            #endif
            self.docMetas = docs.sorted { $0.title < $1.title }
        } catch {
            print("❌ ResourceStore: Error fetching docs: \(error)")
            // Check if it's a permission error
            let errorString = error.localizedDescription
            if errorString.contains("permission") || errorString.contains("PERMISSION_DENIED") {
                docsError = "Permission denied. Your account may not have access to docs. Try signing out and signing in again with the RA code."
            } else {
                docsError = errorString
            }
        }
    }
}



