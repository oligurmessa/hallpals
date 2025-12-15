import SwiftUI
import WebKit

struct ResidentsView: View {
    // Firebase-based service (primary)
    @StateObject private var firebaseResidentService = ResidentService.shared

    // Roompact-based services (fallback)
    @StateObject private var roompactService = RoompactResidentService.shared
    @StateObject private var roompactStore = ResidentStore.shared

    @State private var showingWebView = false
    @State private var showingClearAlert = false
    @State private var searchText = ""
    @State private var dataSource: DataSource = .firebase

    enum DataSource: String, CaseIterable {
        case firebase = "My Residents"
        case roompact = "Roompact"
    }

    // Firebase filtered residents
    var filteredFirebaseResidents: [HallResident] {
        if searchText.isEmpty {
            return firebaseResidentService.sortedResidents
        }
        return firebaseResidentService.search(searchText)
    }

    // Roompact filtered residents
    var filteredRoompactResidents: [RoompactResident] {
        if searchText.isEmpty {
            return roompactStore.sortedResidents
        }
        return roompactStore.search(searchText)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Data source picker
                dataSourcePicker
                    .padding(.horizontal, 20)

                // Content based on data source
                if dataSource == .firebase {
                    firebaseContent
                } else {
                    roompactContent
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Residents")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    if dataSource == .firebase {
                        Button {
                            firebaseResidentService.fetchMyResidents()
                        } label: {
                            Label("Refresh", systemImage: "arrow.clockwise")
                        }
                    } else {
                        Button {
                            showingWebView = true
                        } label: {
                            Label("Sync with Roompact", systemImage: "arrow.triangle.2.circlepath")
                        }

                        if roompactStore.hasSyncedResidents {
                            Button(role: .destructive) {
                                showingClearAlert = true
                            } label: {
                                Label("Clear Residents", systemImage: "trash")
                            }
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            RoompactResidentsWebViewSheet()
        }
        .alert("Clear Residents?", isPresented: $showingClearAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                roompactService.clearData()
            }
        } message: {
            Text("This will remove all Roompact resident data. You can sync again anytime.")
        }
        .onAppear {
            // Auto-fetch Firebase residents on appear
            if dataSource == .firebase && firebaseResidentService.myResidents.isEmpty {
                firebaseResidentService.fetchMyResidents()
            }
        }
    }

    // MARK: - Data Source Picker

    private var dataSourcePicker: some View {
        Picker("Data Source", selection: $dataSource) {
            ForEach(DataSource.allCases, id: \.self) { source in
                Text(source.rawValue).tag(source)
            }
        }
        .pickerStyle(.segmented)
        .onChange(of: dataSource) { _, newSource in
            if newSource == .firebase && firebaseResidentService.myResidents.isEmpty {
                firebaseResidentService.fetchMyResidents()
            }
        }
    }

    // MARK: - Firebase Content

    @ViewBuilder
    private var firebaseContent: some View {
        // Loading state
        if firebaseResidentService.isLoading {
            VStack(spacing: 16) {
                ProgressView()
                    .scaleEffect(1.2)
                Text("Loading residents...")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 60)
        }
        // Error state
        else if let error = firebaseResidentService.errorMessage, firebaseResidentService.myResidents.isEmpty {
            firebaseEmptyCard(message: error)
                .padding(.horizontal, 20)
        }
        // Empty state
        else if firebaseResidentService.myResidents.isEmpty {
            firebaseEmptyCard(message: "No residents assigned to your section yet.")
                .padding(.horizontal, 20)
        }
        // Residents list
        else {
            // Stats card
            firebaseStatsCard
                .padding(.horizontal, 20)

            // Search bar
            searchBar
                .padding(.horizontal, 20)

            // Residents list
            firebaseResidentsListSection
        }
    }

    private func firebaseEmptyCard(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 44))
                .foregroundColor(.purple)

            Text("My Residents")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text(message)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                firebaseResidentService.fetchMyResidents()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.clockwise")
                    Text("Refresh")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.purple)
                .cornerRadius(12)
            }
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var firebaseStatsCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text("\(firebaseResidentService.residentCount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.purple)
                Text("Residents")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("My Section")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                Text("Live data")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.green)
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    private var firebaseResidentsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !searchText.isEmpty {
                Text("\(filteredFirebaseResidents.count) results")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 20)
            }

            if filteredFirebaseResidents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("No residents found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Group by letter
                let grouped = Dictionary(grouping: filteredFirebaseResidents) { resident in
                    String(resident.lastName.prefix(1)).uppercased()
                }
                let sortedKeys = grouped.keys.sorted()

                ForEach(sortedKeys, id: \.self) { letter in
                    VStack(alignment: .leading, spacing: 0) {
                        // Letter header
                        Text(letter)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // Residents in this letter group
                        VStack(spacing: 0) {
                            let residentsInGroup = grouped[letter] ?? []
                            ForEach(Array(residentsInGroup.enumerated()), id: \.element.id) { index, resident in
                                FirebaseResidentRow(
                                    resident: resident,
                                    isLast: index == residentsInGroup.count - 1
                                )
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }

    // MARK: - Roompact Content

    @ViewBuilder
    private var roompactContent: some View {
        // Stats card
        if !roompactStore.residents.isEmpty {
            statsCard
                .padding(.horizontal, 20)
        }

        // Content
        if roompactStore.residents.isEmpty {
            connectCard
                .padding(.horizontal, 20)
        } else {
            // Search bar
            searchBar
                .padding(.horizontal, 20)

            // Residents list
            roompactResidentsListSection
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Residents")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            if dataSource == .firebase {
                if firebaseResidentService.myResidents.isEmpty {
                    Text("Your assigned residents")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(firebaseResidentService.residentCount) residents in your section")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            } else {
                if roompactStore.residents.isEmpty {
                    Text("Import your resident list")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                } else {
                    Text("\(roompactStore.residentCount) residents")
                        .font(.system(size: 15))
                        .foregroundColor(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Roompact Stats Card

    private var statsCard: some View {
        HStack(spacing: 20) {
            VStack(spacing: 2) {
                Text("\(roompactStore.residentCount)")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.blue)
                Text("Total")
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
            }

            if !roompactStore.buildings.isEmpty {
                Divider()
                    .frame(height: 30)

                VStack(spacing: 2) {
                    Text("\(roompactStore.buildings.count)")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Buildings")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if let lastUpdated = roompactStore.lastUpdated {
                VStack(alignment: .trailing, spacing: 2) {
                    Text("Last synced")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                    Text(lastUpdated.formatted(.relative(presentation: .named)))
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Roompact Connect Card

    private var connectCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3.fill")
                .font(.system(size: 44))
                .foregroundColor(.blue)

            Text("Import Residents")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text("Sign in to Roompact to import your resident list automatically.")
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showingWebView = true
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.triangle.2.circlepath")
                    Text("Sync with Roompact")
                }
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(Color.blue)
                .cornerRadius(12)
            }

            if case .error(let message) = roompactService.state {
                Text(message)
                    .font(.system(size: 13))
                    .foregroundColor(.red)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(24)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)

            TextField("Search residents...", text: $searchText)
                .textFieldStyle(PlainTextFieldStyle())

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }

    // MARK: - Roompact Residents List

    private var roompactResidentsListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            if !searchText.isEmpty {
                Text("\(filteredRoompactResidents.count) results")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)
                    .padding(.horizontal, 20)
            }

            if filteredRoompactResidents.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "person.slash")
                        .font(.system(size: 32))
                        .foregroundColor(.secondary)

                    Text("No residents found")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                // Group by letter
                let grouped = Dictionary(grouping: filteredRoompactResidents) { resident in
                    String(resident.lastName.prefix(1)).uppercased()
                }
                let sortedKeys = grouped.keys.sorted()

                ForEach(sortedKeys, id: \.self) { letter in
                    VStack(alignment: .leading, spacing: 0) {
                        // Letter header
                        Text(letter)
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 20)
                            .padding(.bottom, 8)

                        // Residents in this letter group
                        VStack(spacing: 0) {
                            let residentsInGroup = grouped[letter] ?? []
                            ForEach(Array(residentsInGroup.enumerated()), id: \.element.id) { index, resident in
                                RoompactResidentRow(
                                    resident: resident,
                                    isLast: index == residentsInGroup.count - 1
                                )
                            }
                        }
                        .background(Color(UIColor.secondarySystemBackground))
                        .cornerRadius(12)
                        .padding(.horizontal, 20)
                    }
                    .padding(.bottom, 16)
                }
            }
        }
    }
}

// MARK: - Firebase Resident Row

struct FirebaseResidentRow: View {
    let resident: HallResident
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(avatarColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(resident.initials)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(resident.fullName)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    HStack(spacing: 4) {
                        Text("Room \(resident.roomNumber)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        if let wing = resident.wing, !wing.isEmpty {
                            Text("• \(wing)")
                                .font(.system(size: 14))
                                .foregroundColor(.secondary)
                        }
                    }
                }

                Spacer()

                // Email button
                if !resident.email.isEmpty {
                    Button {
                        if let url = URL(string: "mailto:\(resident.email)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "envelope")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 68)
            }
        }
    }

    private var avatarColor: Color {
        // Generate consistent color from name
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        let hash = abs(resident.fullName.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Roompact Resident Row

struct RoompactResidentRow: View {
    let resident: RoompactResident
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                // Avatar
                Circle()
                    .fill(avatarColor)
                    .frame(width: 40, height: 40)
                    .overlay(
                        Text(initials)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(.white)
                    )

                // Info
                VStack(alignment: .leading, spacing: 2) {
                    Text(resident.name)
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.primary)

                    if let room = resident.room, !room.isEmpty {
                        Text("Room \(room)")
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    } else if let building = resident.building, !building.isEmpty {
                        Text(building)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                // Email button if available
                if let email = resident.email, !email.isEmpty {
                    Button {
                        if let url = URL(string: "mailto:\(email)") {
                            UIApplication.shared.open(url)
                        }
                    } label: {
                        Image(systemName: "envelope")
                            .font(.system(size: 16))
                            .foregroundColor(.blue)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 68)
            }
        }
    }

    private var initials: String {
        let parts = resident.name.components(separatedBy: " ")
        if parts.count >= 2 {
            return "\(parts[0].prefix(1))\(parts[1].prefix(1))".uppercased()
        }
        return String(resident.name.prefix(2)).uppercased()
    }

    private var avatarColor: Color {
        // Generate consistent color from name
        let colors: [Color] = [.blue, .purple, .green, .orange, .pink, .cyan, .indigo]
        let hash = abs(resident.name.hashValue)
        return colors[hash % colors.count]
    }
}

// MARK: - Roompact Residents WebView Sheet

struct RoompactResidentsWebViewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var residentService = RoompactResidentService.shared
    @State private var isLoading = true
    @State private var loadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var statusMessage: String = "Loading Roompact..."
    @State private var syncComplete = false
    @State private var residentCount = 0

    var body: some View {
        NavigationStack {
            ZStack {
                RoompactResidentsDownloadWebView(
                    isLoading: $isLoading,
                    loadProgress: $loadProgress,
                    errorMessage: $errorMessage,
                    statusMessage: $statusMessage,
                    onCSVDownloaded: { data in
                        residentService.processCSVData(data)
                        residentCount = ResidentStore.shared.residents.count
                        syncComplete = true
                        // Auto-dismiss after brief delay
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            dismiss()
                        }
                    }
                )

                // Top status bar
                VStack {
                    if isLoading {
                        ProgressView(value: loadProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .padding(.horizontal)
                    }

                    HStack(spacing: 8) {
                        if !syncComplete && errorMessage == nil {
                            ProgressView()
                                .scaleEffect(0.8)
                        } else if syncComplete {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                        }
                        Text(statusMessage)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(syncComplete ? .green : .primary)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(20)
                    .padding(.top, 8)

                    Spacer()
                }

                // Error overlay
                if let error = errorMessage {
                    VStack(spacing: 20) {
                        Image(systemName: "wifi.exclamationmark")
                            .font(.system(size: 50))
                            .foregroundColor(.red)

                        Text("Connection Failed")
                            .font(.system(size: 20, weight: .semibold))

                        Text(error)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)

                        Button {
                            errorMessage = nil
                            statusMessage = "Retrying..."
                        } label: {
                            Text("Try Again")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .padding(.horizontal, 32)
                                .padding(.vertical, 12)
                                .background(Color.blue)
                                .cornerRadius(10)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color(UIColor.systemBackground))
                }

                // Success overlay
                if syncComplete {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()

                    VStack(spacing: 16) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 50))
                            .foregroundColor(.green)

                        Text("Residents Synced!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("\(residentCount) residents imported")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(32)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                }
            }
            .navigationTitle("Sync Residents")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - WKWebView for Residents CSV Download

struct RoompactResidentsDownloadWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var loadProgress: Double
    @Binding var errorMessage: String?
    @Binding var statusMessage: String
    let onCSVDownloaded: (Data) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero, configuration: WebContext.shared.webViewConfiguration)
        webView.navigationDelegate = context.coordinator
        webView.allowsBackForwardNavigationGestures = true

        // Observe loading progress
        context.coordinator.progressObservation = webView.observe(\.estimatedProgress) { webView, _ in
            DispatchQueue.main.async {
                self.loadProgress = webView.estimatedProgress
            }
        }

        // Load the download URL directly
        let downloadURL = RoompactResidentService.shared.residentsDownloadURL
        print("📥 Loading Roompact residents URL: \(downloadURL)")
        webView.load(URLRequest(url: downloadURL))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Retry loading if error was cleared
        if errorMessage == nil && webView.url == nil {
            let downloadURL = RoompactResidentService.shared.residentsDownloadURL
            webView.load(URLRequest(url: downloadURL))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        var parent: RoompactResidentsDownloadWebView
        var progressObservation: NSKeyValueObservation?
        var hasReceivedCSV = false
        var tempFileURL: URL?

        init(_ parent: RoompactResidentsDownloadWebView) {
            self.parent = parent
        }

        func webView(_ webView: WKWebView, didStartProvisionalNavigation navigation: WKNavigation!) {
            parent.isLoading = true
            parent.errorMessage = nil
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            parent.isLoading = false

            guard let urlString = webView.url?.absoluteString else { return }

            // Check if we're on a login page
            if urlString.contains("login") || urlString.contains("signin") || urlString.contains("auth") {
                DispatchQueue.main.async {
                    self.parent.statusMessage = "Please sign in to continue..."
                }
            }
        }

        // Intercept navigation response to detect CSV and trigger download
        func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {

            guard !hasReceivedCSV else {
                decisionHandler(.cancel)
                return
            }

            // Check if this looks like a CSV download
            let isCSVResponse = isCSVDownload(navigationResponse)

            if isCSVResponse {
                hasReceivedCSV = true
                DispatchQueue.main.async {
                    self.parent.statusMessage = "Downloading residents..."
                }
                // Use .download to handle it as a file download
                decisionHandler(.download)
                return
            }

            decisionHandler(.allow)
        }

        private func isCSVDownload(_ response: WKNavigationResponse) -> Bool {
            // Check URL
            if let url = response.response.url,
               url.absoluteString.contains("summary.csv") || url.absoluteString.contains("agreementSubmissions") {
                return true
            }

            // Check MIME type
            if let mimeType = response.response.mimeType,
               (mimeType.contains("csv") || mimeType == "text/plain" || mimeType == "application/octet-stream") {
                if let url = response.response.url, url.absoluteString.contains("roompact") {
                    return true
                }
            }

            // Check Content-Disposition header
            if let httpResponse = response.response as? HTTPURLResponse,
               let contentDisposition = httpResponse.allHeaderFields["Content-Disposition"] as? String,
               contentDisposition.contains(".csv") {
                return true
            }

            return false
        }

        // WKNavigationDelegate - handle download start
        func webView(_ webView: WKWebView, navigationResponse: WKNavigationResponse, didBecome download: WKDownload) {
            download.delegate = self
        }

        // WKDownloadDelegate - decide where to save
        func download(_ download: WKDownload, decideDestinationUsing response: URLResponse, suggestedFilename: String, completionHandler: @escaping (URL?) -> Void) {
            // Create temp file path
            let tempDir = FileManager.default.temporaryDirectory
            let fileURL = tempDir.appendingPathComponent(suggestedFilename)

            // Remove existing file if any
            try? FileManager.default.removeItem(at: fileURL)

            self.tempFileURL = fileURL
            completionHandler(fileURL)
        }

        // WKDownloadDelegate - download finished
        func downloadDidFinish(_ download: WKDownload) {
            guard let fileURL = tempFileURL else {
                DispatchQueue.main.async {
                    self.parent.errorMessage = "Download failed - no file created"
                }
                return
            }

            do {
                let data = try Data(contentsOf: fileURL)
                // Clean up temp file
                try? FileManager.default.removeItem(at: fileURL)

                DispatchQueue.main.async {
                    self.parent.statusMessage = "Processing residents..."
                    self.parent.onCSVDownloaded(data)
                }
            } catch {
                DispatchQueue.main.async {
                    self.parent.errorMessage = "Failed to read downloaded file: \(error.localizedDescription)"
                }
            }
        }

        // WKDownloadDelegate - download failed
        func download(_ download: WKDownload, didFailWithError error: Error, resumeData: Data?) {
            DispatchQueue.main.async {
                self.parent.errorMessage = "Download failed: \(error.localizedDescription)"
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            handleError(error)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            parent.isLoading = false
            handleError(error)
        }

        private func handleError(_ error: Error) {
            let nsError = error as NSError

            // Ignore cancelled errors (user navigated away or we triggered download)
            if nsError.code == -999 { return }
            // Ignore frame load interrupted (we're handling it as download)
            if nsError.code == 102 { return }

            var message: String
            switch nsError.code {
            case -1003:
                message = "Cannot connect to Roompact. Please check your internet connection."
            case -1009:
                message = "No internet connection. Please connect to WiFi or cellular data."
            case -1001:
                message = "Connection timed out. Please try again."
            case -1200:
                message = "Secure connection failed. Your network may be blocking the connection."
            default:
                message = "Failed to load: \(error.localizedDescription)"
            }

            DispatchQueue.main.async {
                self.parent.errorMessage = message
            }
        }
    }
}

#Preview {
    NavigationStack {
        ResidentsView()
    }
}
