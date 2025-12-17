import SwiftUI
import WebKit

struct MainTabView: View {
    @EnvironmentObject private var roleManager: RoleManager
    @State private var selectedTab: Tab = .home

    enum Tab: String, CaseIterable {
        case home = "Home"
        case community = "Community"
        case duty = "Duty"
        case living = "Living"
        case tools = "Tools"
        case resources = "Resources"

        var icon: String {
            switch self {
            case .home: return "house.fill"
            case .resources: return "book.closed.fill"
            case .duty: return "shield.lefthalf.filled"
            case .living: return "building.2.fill"
            case .community: return "person.3.fill"
            case .tools: return "wrench.and.screwdriver.fill"
            }
        }
    }

    private var isResident: Bool {
        roleManager.selectedRole == .resident
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Label(Tab.home.rawValue, systemImage: Tab.home.icon)
                }
                .tag(Tab.home)

            ConversationsListView()
                .tabItem {
                    Label(Tab.community.rawValue, systemImage: Tab.community.icon)
                }
                .tag(Tab.community)

            if isResident {
                ResidentLivingView()
                    .tabItem {
                        Label(Tab.living.rawValue, systemImage: Tab.living.icon)
                    }
                    .tag(Tab.living)
            } else {
                DutyView()
                    .tabItem {
                        Label(Tab.duty.rawValue, systemImage: Tab.duty.icon)
                    }
                    .tag(Tab.duty)
            }

            // Show different Tools view based on role
            if isResident {
                ResidentToolsView()
                    .tabItem {
                        Label(Tab.tools.rawValue, systemImage: Tab.tools.icon)
                    }
                    .tag(Tab.tools)
            } else {
                RAToolsView()
                    .tabItem {
                        Label(Tab.tools.rawValue, systemImage: Tab.tools.icon)
                    }
                    .tag(Tab.tools)
            }

            if !isResident {
                ResourcesView()
                    .tabItem {
                        Label(Tab.resources.rawValue, systemImage: Tab.resources.icon)
                    }
                    .tag(Tab.resources)
            }
        }
        .tint(.blue)
    }
}

#Preview {
    MainTabView()
        .environmentObject(RoleManager())
        .environmentObject(ResourceStore())
}

// MARK: - RA Tools View

struct RAToolsView: View {
    @State private var selectedWebLink: QuickLink?
    @State private var showingCampusSafety = false

    // RA-specific tools
    private let essentialTools: [RATool] = [
        RATool(title: "Tommie Link", subtitle: "Events and Clubs", icon: "link.circle.fill", color: .blue, url: "https://tommielink.stthomas.edu"),
        RATool(title: "Advocate", subtitle: "Incident reporting", icon: "exclamationmark.bubble.fill", color: .indigo, url: "https://stthomas-advocate.symplicity.com"),
        RATool(title: "Roompact", subtitle: "Community standards", icon: "doc.text.fill", color: .cyan, url: "https://roompact.com"),
        RATool(title: "Murphy Online", subtitle: "Student Portal", icon: "fork.knife", color: .purple, url: "https://experience.elluciancloud.com/uofstthomasmn/"),
        RATool(title: "One St. Thomas", subtitle: "University hub", icon: "building.columns.fill", color: .teal, url: "https://one.stthomas.edu")
    ]

    private let reportingTools: [RATool] = [
        RATool(title: "Title IX Reporting", subtitle: "Report incidents", icon: "exclamationmark.triangle.fill", color: .orange, url: "https://stthomas.edu/title-ix")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tools")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)

                        Text("RA tools and university systems")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Essential Tools Section
                    raToolsSection(title: "Essential Tools", tools: essentialTools)

                    // Safety Section
                    safetySection

                    // Reporting Tools Section
                    raToolsSection(title: "Reporting", tools: reportingTools)
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .sheet(isPresented: $showingCampusSafety) {
                CampusSafetySheet()
            }
            .navigationDestination(item: $selectedWebLink) { link in
                InAppBrowserView(url: URL(string: link.urlString)!, title: link.title)
            }
        }
    }

    // MARK: - Tools Section

    private func raToolsSection(title: String, tools: [RATool]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                    raToolRow(tool: tool, isLast: index == tools.count - 1)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Safety Section

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            Button {
                showingCampusSafety = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campus Safety")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Text("Emergency/Non-Emergency & CD")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Tool Row

    private func raToolRow(tool: RATool, isLast: Bool) -> some View {
        Button {
            selectedWebLink = QuickLink(
                id: tool.id,
                title: tool.title,
                subtitle: tool.subtitle,
                systemImageName: tool.icon,
                urlString: tool.url,
                visibleToRoles: [.ra]
            )
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundColor(tool.color)
                        .frame(width: 32, height: 32)
                        .background(tool.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.title)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Text(tool.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
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
}

// MARK: - RA Tool Model

struct RATool: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let url: String
}

// MARK: - Resident Tools View

struct ResidentToolsView: View {
    @State private var showingCampusSafety = false
    @State private var selectedWebLink: QuickLink?

    // Resident-specific tools
    private let essentialTools: [ResidentTool] = [
        ResidentTool(title: "Tommie Link", subtitle: "Student portal", icon: "link.circle.fill", color: .blue, url: "https://tommielink.stthomas.edu"),
        ResidentTool(title: "RFS / Maintenance", subtitle: "Submit work orders", icon: "wrench.and.screwdriver.fill", color: .green, url: "https://rmsstudent.stthomas.edu/page/HousingPortal"),
        ResidentTool(title: "Murphy Online", subtitle: "Central Toll", icon: "fork.knife", color: .purple, url: "https://experience.elluciancloud.com/uofstthomasmn/"),
        ResidentTool(title: "One St. Thomas", subtitle: "University hub", icon: "building.columns.fill", color: .teal, url: "https://one.stthomas.edu")
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Tools")
                            .font(.system(size: 34, weight: .bold))
                            .foregroundColor(.primary)

                        Text("Quick access to campus resources")
                            .font(.system(size: 15))
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 20)

                    // Essential Tools Section
                    toolsSection(title: "Essential Tools", tools: essentialTools)

                    // Safety Section
                    safetySection
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .sheet(isPresented: $showingCampusSafety) {
                ResidentCampusSafetySheet()
            }
            .navigationDestination(item: $selectedWebLink) { link in
                InAppBrowserView(url: URL(string: link.urlString)!, title: link.title)
            }
        }
    }

    // MARK: - Tools Section

    private func toolsSection(title: String, tools: [ResidentTool]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(tools.enumerated()), id: \.element.id) { index, tool in
                    residentToolRow(tool: tool, isLast: index == tools.count - 1)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Safety Section

    private var safetySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Safety")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)
                .padding(.horizontal, 20)

            Button {
                showingCampusSafety = true
            } label: {
                HStack(spacing: 14) {
                    Image(systemName: "shield.fill")
                        .font(.system(size: 18))
                        .foregroundColor(.red)
                        .frame(width: 32, height: 32)
                        .background(Color.red.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Campus Safety")
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Text("Emergency & non-emergency contacts")
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Tool Row

    private func residentToolRow(tool: ResidentTool, isLast: Bool) -> some View {
        Button {
            selectedWebLink = QuickLink(
                id: tool.id,
                title: tool.title,
                subtitle: tool.subtitle,
                systemImageName: tool.icon,
                urlString: tool.url,
                visibleToRoles: [.resident]
            )
        } label: {
            VStack(spacing: 0) {
                HStack(spacing: 14) {
                    Image(systemName: tool.icon)
                        .font(.system(size: 18))
                        .foregroundColor(tool.color)
                        .frame(width: 32, height: 32)
                        .background(tool.color.opacity(0.12))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tool.title)
                            .font(.system(size: 16))
                            .foregroundColor(.primary)
                        Text(tool.subtitle)
                            .font(.system(size: 13))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(Color(UIColor.systemGray3))
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
}

// MARK: - Resident Tool Model

struct ResidentTool: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let url: String
}

// MARK: - Campus Safety Sheet (RA version - includes CD/GSA)

struct CampusSafetySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "shield.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        }

                        Text("Campus Safety")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)

                    // Contact cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact Lines")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ContactRow(
                                title: "Emergency",
                                number: "651-962-5555",
                                icon: "exclamationmark.triangle.fill",
                                color: .red,
                                isLast: false
                            )
                            ContactRow(
                                title: "Non-Emergency",
                                number: "651-962-5100",
                                icon: "shield.fill",
                                color: .blue,
                                isLast: false
                            )
                            ContactRow(
                                title: "CD/GSA Duty Phone",
                                number: "612-801-8484",
                                icon: "phone.fill",
                                color: .green,
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
        .presentationDetents([.medium, .large])
    }
}

// MARK: - Campus Safety Sheet (Resident version - no CD/GSA)

struct ResidentCampusSafetySheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.red.opacity(0.1))
                                .frame(width: 72, height: 72)
                            Image(systemName: "shield.fill")
                                .font(.system(size: 32))
                                .foregroundColor(.red)
                        }

                        Text("Campus Safety")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.primary)
                    }
                    .padding(.top, 20)

                    // Contact cards
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Contact Lines")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .textCase(.uppercase)
                            .tracking(0.5)
                            .padding(.horizontal, 20)

                        VStack(spacing: 0) {
                            ContactRow(
                                title: "Emergency",
                                number: "651-962-5555",
                                icon: "exclamationmark.triangle.fill",
                                color: .red,
                                isLast: false
                            )
                            ContactRow(
                                title: "Non-Emergency",
                                number: "651-962-5100",
                                icon: "shield.fill",
                                color: .blue,
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
        .presentationDetents([.medium, .large])
    }
}

struct ContactRow: View {
    let title: String
    let number: String
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
                    Text(number)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    if let url = URL(string: "tel://\(number.replacingOccurrences(of: "-", with: ""))") {
                        UIApplication.shared.open(url)
                    }
                } label: {
                    Image(systemName: "phone.circle.fill")
                        .font(.system(size: 28))
                        .foregroundColor(.green)
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

// MARK: - Quick Link Components

struct QuickLinkCard: View {
    let link: QuickLink

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: link.systemImageName)
                .font(.system(size: 24))
                .foregroundColor(.blue)

            Text(link.title)
                .font(.system(size: 15))
                .foregroundColor(.primary)
                .lineLimit(1)

            Text(link.subtitle)
                .font(.system(size: 12))
                .foregroundColor(.secondary)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct QuickLinkSheet: View {
    let link: QuickLink
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                // Icon
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.1))
                        .frame(width: 88, height: 88)
                    Image(systemName: link.systemImageName)
                        .font(.system(size: 36))
                        .foregroundColor(.blue)
                }

                // Title and subtitle
                VStack(spacing: 8) {
                    Text(link.title)
                        .font(.system(size: 22, weight: .bold))
                        .foregroundColor(.primary)

                    Text(link.subtitle)
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }

                // URL card
                VStack(spacing: 8) {
                    Text("Link URL")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                    Text(link.urlString)
                        .font(.system(size: 14))
                        .foregroundColor(.blue)
                        .multilineTextAlignment(.center)
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                .padding(.horizontal, 20)

                Spacer()

                // Open button
                Button {
                    if let url = URL(string: link.urlString) {
                        UIApplication.shared.open(url)
                    }
                    dismiss()
                } label: {
                    Text("Open Link")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(Color.blue)
                        .cornerRadius(14)
                }
                .padding(.horizontal, 20)
            }
            .padding(.vertical, 24)
            .background(Color(UIColor.systemBackground))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { dismiss() }
                        .font(.system(size: 17, weight: .semibold))
                }
            }
        }
    }
}

// MARK: - In-App Browser Components

struct InAppBrowserView: View {
    let url: URL
    let title: String
    @State private var isLoading = true
    @State private var webView = DetailedWebView()

    var body: some View {
        ZStack {
            WebViewWrapper(webView: webView, url: url, isLoading: $isLoading)
                .edgesIgnoringSafeArea(.bottom)

            if isLoading {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle())
                    .scaleEffect(1.5)
            }

            if let error = webView.error {
                VStack(spacing: 16) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 40))
                        .foregroundColor(.red)
                    Text("Failed to load page")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.primary)
                    Text(error.localizedDescription)
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Button {
                        webView.reload()
                    } label: {
                        Text("Retry")
                            .font(.system(size: 15, weight: .medium))
                            .foregroundColor(.blue)
                    }
                }
                .padding(24)
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(16)
            }
        }
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                if isLoading {
                    EmptyView()
                } else {
                    Button {
                        webView.reload()
                    } label: {
                        Image(systemName: "arrow.clockwise")
                    }
                }
            }
        }
    }
}

// Detailed WebView with delegates
class DetailedWebView: WKWebView {
    var error: Error? = nil
}

struct WebViewWrapper: UIViewRepresentable {
    let webView: WKWebView
    let url: URL
    @Binding var isLoading: Bool
    
    // Create a specific subclass or configure the passed one
    func makeUIView(context: Context) -> WKWebView {
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator // Critical for createWebViewWith
        
        // Configuration
        if let detailedView = webView as? DetailedWebView {
            detailedView.error = nil
        }
        
        // Pull to refresh
        let refreshControl = UIRefreshControl()
        refreshControl.addTarget(context.coordinator, action: #selector(Coordinator.handleRefresh), for: .valueChanged)
        webView.scrollView.refreshControl = refreshControl
        
        return webView
    }
    
    func updateUIView(_ uiView: WKWebView, context: Context) {
        if uiView.url == nil {
            let request = URLRequest(url: url)
            uiView.load(request)
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate {
        var parent: WebViewWrapper
        
        init(_ parent: WebViewWrapper) {
            self.parent = parent
        }
        
        @objc func handleRefresh(_ sender: UIRefreshControl) {
            parent.webView.reload()
            sender.endRefreshing()
        }
        
        // MARK: - Navigation Delegate
        
        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = true
                if let detailed = self.parent.webView as? DetailedWebView {
                    detailed.error = nil
                }
            }
        }
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
            }
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            handleError(error)
        }
        
        private func handleError(_ error: Error) {
            DispatchQueue.main.async {
                self.parent.isLoading = false
                 if let detailed = self.parent.webView as? DetailedWebView {
                    detailed.error = error
                }
            }
        }
        
        // MARK: - UI Delegate (Handling New Windows/Tabs for SSO)
        
        func webView(_ webView: WKWebView, createWebViewWith configuration: WKWebViewConfiguration, for navigationAction: WKNavigationAction, windowFeatures: WKWindowFeatures) -> WKWebView? {
            // Force open in the same web view if trying to open new window (common in SSO)
            if navigationAction.targetFrame == nil {
                webView.load(navigationAction.request)
            }
            return nil
        }
    }
}

// MARK: - Duty View

/// RA Duty View - Central hub for RA duty-related tasks
/// Features: Quick actions, management tools, and tracking
struct DutyView: View {
    @StateObject private var scheduleService = DutyScheduleService.shared
    @StateObject private var roomCheckService = RoomCheckService.shared
    @StateObject private var residentService = ResidentService.shared
    @StateObject private var userManager = UserManager.shared

    @State private var showingRounds = false
    @State private var selectedWebLink: QuickLink?
    @State private var showingCampusSafety = false
    @State private var showingSettings = false
    @State private var showingDutyLog = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerSection
                        .padding(.horizontal, 20)

                    // Quick Actions Section
                    quickActionsSection
                        .padding(.horizontal, 20)

                    // Management Section
                    managementSection
                        .padding(.horizontal, 20)

                    // Tracking Section
                    trackingSection
                        .padding(.horizontal, 20)
                }
                .padding(.vertical, 16)
            }
            .background(Color(UIColor.systemBackground))
            .navigationBarHidden(true)
            .fullScreenCover(isPresented: $showingRounds) {
                RoundsTrackerView()
            }
            .fullScreenCover(isPresented: $showingSettings) {
                SettingsView()
            }
            .sheet(isPresented: $showingCampusSafety) {
                CampusSafetySheet()
            }
            .fullScreenCover(isPresented: $showingDutyLog) {
                DutyLogView()
            }
            .navigationDestination(item: $selectedWebLink) { link in
                InAppBrowserView(url: URL(string: link.urlString)!, title: link.title)
            }
            .onAppear {
                // Start listening for inspection data when view appears
                if let hallId = userManager.hallId, !hallId.isEmpty {
                    roomCheckService.startListening(hallId: hallId)
                }
            }
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Duty")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            Text("RA tools and tasks")
                .font(.system(size: 15))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                // Start Rounds
                Button {
                    showingRounds = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 18))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(Color.blue)
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Start Rounds")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Track your duty rounds with GPS")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 62)

                // Report Incident
                Button {
                    selectedWebLink = QuickLink(
                        id: UUID(),
                        title: "Report Incident",
                        subtitle: "Advocate",
                        systemImageName: "exclamationmark.triangle.fill",
                        urlString: "https://stthomas-advocate.symplicity.com/index.php/pid652835?s=incident&mode=form&tab=core&_do_edit=1&id=",
                        visibleToRoles: [.ra]
                    )
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.orange)
                            .frame(width: 32, height: 32)
                            .background(Color.orange.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Report Incident")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("File via Advocate system")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 62)

                // Duty Log
                Button {
                    showingDutyLog = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "doc.text.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.indigo)
                            .frame(width: 32, height: 32)
                            .background(Color.indigo.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Duty Log")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Submit via Roompact")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }

                Divider()
                    .padding(.leading, 62)

                // Campus Safety
                Button {
                    showingCampusSafety = true
                } label: {
                    HStack(spacing: 14) {
                        Image(systemName: "shield.fill")
                            .font(.system(size: 18))
                            .foregroundColor(.red)
                            .frame(width: 32, height: 32)
                            .background(Color.red.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 8))

                        VStack(alignment: .leading, spacing: 2) {
                            Text("Campus Safety")
                                .font(.system(size: 16))
                                .foregroundColor(.primary)
                            Text("Emergency/Non-Emergency & CD")
                                .font(.system(size: 13))
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        Image(systemName: "chevron.right")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Color(UIColor.systemGray3))
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Management Section

    private var managementSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Management")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                // Tasks
                NavigationLink {
                    RATasksView()
                } label: {
                    dutyRow(
                        icon: "checklist",
                        title: "Tasks",
                        subtitle: RATaskService.shared.statusText,
                        color: .orange,
                        highlight: RATaskService.shared.hasOverdueTasks
                    )
                }

                Divider()
                    .padding(.leading, 62)

                // Residents
                NavigationLink {
                    ResidentsView()
                } label: {
                    dutyRow(
                        icon: "person.3.fill",
                        title: "Residents",
                        subtitle: residentService.residentCount > 0 ? "\(residentService.residentCount) residents" : "View residents",
                        color: .purple
                    )
                }

                Divider()
                    .padding(.leading, 62)

                // Schedule
                NavigationLink {
                    ScheduleView()
                } label: {
                    dutyRow(
                        icon: "calendar",
                        title: "Schedule",
                        subtitle: scheduleService.thisWeekShifts.isEmpty ? "View your schedule" : "\(scheduleService.thisWeekShifts.count) shifts this week",
                        color: .cyan
                    )
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Tracking Section

    private var trackingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tracking")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.secondary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(spacing: 0) {
                // Room Check / Inspections
                NavigationLink {
                    RoomCheckView()
                } label: {
                    dutyRow(
                        icon: "checkmark.circle.fill",
                        title: "Inspections",
                        subtitle: roomCheckService.statusText,
                        color: .green
                    )
                }

                Divider()
                    .padding(.leading, 62)

                // 1:1 Meetings
                NavigationLink {
                    OneOnOneMeetingsView()
                } label: {
                    dutyRow(
                        icon: "person.2.fill",
                        title: "1:1 Meetings",
                        subtitle: "Track resident meetings",
                        color: .orange
                    )
                }

                Divider()
                    .padding(.leading, 62)

                // Community Meetings
                NavigationLink {
                    CommunityMeetingsView()
                } label: {
                    dutyRow(
                        icon: "person.3.sequence.fill",
                        title: "Community Meetings",
                        subtitle: CommunityMeetingsService.shared.statusText,
                        color: .indigo
                    )
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
    }

    // MARK: - Duty Row Helper

    private func dutyRow(icon: String, title: String, subtitle: String, color: Color, highlight: Bool = false) -> some View {
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
                    .foregroundColor(highlight ? .red : .secondary)
            }

            Spacer()

            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(Color(UIColor.systemGray3))
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
    }
}
