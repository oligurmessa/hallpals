import SwiftUI
import WebKit

struct ScheduleView: View {
    @StateObject private var scheduleService = RoompactScheduleService.shared
    @StateObject private var scheduleStore = ScheduleStore.shared
    @State private var showingWebView = false
    @State private var showingLogoutAlert = false

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Header
                headerSection
                    .padding(.horizontal, 20)

                // Status card
                statusCard
                    .padding(.horizontal, 20)

                // Schedule content
                if scheduleStore.shifts.isEmpty {
                    connectCard
                        .padding(.horizontal, 20)
                } else {
                    // This week section
                    if !scheduleStore.thisWeekShifts.isEmpty {
                        thisWeekSection
                    }

                    // All upcoming shifts
                    if !scheduleStore.upcomingShifts.isEmpty {
                        upcomingSection
                    }
                }
            }
            .padding(.vertical, 16)
        }
        .background(Color(UIColor.systemBackground))
        .navigationTitle("Schedule")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Menu {
                    Button {
                        showingWebView = true
                    } label: {
                        Label("Sync with Roompact", systemImage: "arrow.triangle.2.circlepath")
                    }

                    if scheduleStore.hasSyncedSchedule {
                        Button(role: .destructive) {
                            showingLogoutAlert = true
                        } label: {
                            Label("Clear Schedule", systemImage: "trash")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.system(size: 17))
                }
            }
        }
        .sheet(isPresented: $showingWebView) {
            RoompactWebViewSheet()
        }
        .alert("Clear Schedule?", isPresented: $showingLogoutAlert) {
            Button("Cancel", role: .cancel) {}
            Button("Clear", role: .destructive) {
                Task {
                    await scheduleService.logout()
                }
            }
        } message: {
            Text("This will remove your schedule data. You can sync again anytime.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Schedule")
                .font(.system(size: 34, weight: .bold))
                .foregroundColor(.primary)

            if let nextShift = scheduleStore.nextShift {
                Text("Next shift: \(nextShift.formattedDate)")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            } else {
                Text("View your duty schedule")
                    .font(.system(size: 15))
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Status Card

    private var statusCard: some View {
        HStack(spacing: 16) {
            // Current status
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(scheduleStore.isOnDuty ? Color.green : Color.orange)
                        .frame(width: 8, height: 8)

                    Text(scheduleStore.isOnDuty ? "On Duty" : "Off Duty")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(scheduleStore.isOnDuty ? .green : .orange)
                }

                if let active = scheduleStore.activeShift {
                    Text("Until \(active.formattedEndTime)")
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                } else if let next = scheduleStore.nextShift {
                    Text(next.isToday ? "Today at \(next.formattedStartTime)" :
                         next.isTomorrow ? "Tomorrow at \(next.formattedStartTime)" :
                         next.formattedDate)
                        .font(.system(size: 13))
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Stats
            HStack(spacing: 20) {
                VStack(spacing: 2) {
                    Text("\(scheduleStore.thisWeekShifts.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.blue)
                    Text("This Week")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }

                VStack(spacing: 2) {
                    Text("\(scheduleStore.upcomingShifts.count)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundColor(.purple)
                    Text("Total")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }

    // MARK: - Connect Card

    private var connectCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 44))
                .foregroundColor(.blue)

            Text("Sync Your Schedule")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.primary)

            Text("Sign in to Roompact to import your duty schedule automatically.")
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

            if case .error(let message) = scheduleService.state {
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

    // MARK: - This Week Section

    private var thisWeekSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("This Week")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if scheduleService.state.isLoading {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(scheduleStore.thisWeekShifts.enumerated()), id: \.element.id) { index, shift in
                    ShiftRow(
                        shift: shift,
                        isLast: index == scheduleStore.thisWeekShifts.count - 1
                    )
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)
        }
    }

    // MARK: - Upcoming Section

    private var upcomingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("All Upcoming")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.5)

                Spacer()

                if let lastUpdated = scheduleStore.lastUpdated {
                    Text("Updated \(lastUpdated.formatted(.relative(presentation: .named)))")
                        .font(.system(size: 12))
                        .foregroundColor(Color(UIColor.systemGray3))
                }
            }
            .padding(.horizontal, 20)

            VStack(spacing: 0) {
                ForEach(Array(scheduleStore.upcomingShifts.prefix(10).enumerated()), id: \.element.id) { index, shift in
                    ShiftRow(
                        shift: shift,
                        isLast: index == min(9, scheduleStore.upcomingShifts.count - 1)
                    )
                }
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .padding(.horizontal, 20)

            if scheduleStore.upcomingShifts.count > 10 {
                Text("+ \(scheduleStore.upcomingShifts.count - 10) more shifts")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 4)
            }
        }
    }
}

// MARK: - Shift Row

struct ShiftRow: View {
    let shift: Shift
    let isLast: Bool

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 14) {
                // Date circle
                VStack(spacing: 2) {
                    Text(dayOfWeek)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.secondary)
                    Text(dayNumber)
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(shift.isToday ? .blue : .primary)
                }
                .frame(width: 44, height: 44)
                .background(shift.isToday ? Color.blue.opacity(0.12) : Color(UIColor.systemGray5))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                // Shift details
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(shift.formattedDate)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.primary)

                        if shift.isToday {
                            Text("Today")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.blue)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.blue.opacity(0.12))
                                .cornerRadius(4)
                        } else if shift.isTomorrow {
                            Text("Tomorrow")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(.orange)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Color.orange.opacity(0.12))
                                .cornerRadius(4)
                        }
                    }

                    Text("\(shift.formattedStartTime) - \(shift.formattedEndTime)")
                        .font(.system(size: 14))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Duration
                VStack(alignment: .trailing, spacing: 2) {
                    Text(String(format: "%.1fh", shift.durationHours))
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.primary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if !isLast {
                Divider()
                    .padding(.leading, 74)
            }
        }
    }

    private var dayOfWeek: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEE"
        return formatter.string(from: shift.start).uppercased()
    }

    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: shift.start)
    }
}

// MARK: - Roompact WebView Sheet

struct RoompactWebViewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var scheduleService = RoompactScheduleService.shared
    @State private var isLoading = true
    @State private var loadProgress: Double = 0
    @State private var errorMessage: String?
    @State private var statusMessage: String = "Loading Roompact..."
    @State private var syncComplete = false
    @State private var shiftCount = 0

    // DEBUG: Show crafted URL
    @State private var debugURL: String?
    @State private var debugUserId: String?

    var body: some View {
        NavigationStack {
            ZStack {
                RoompactDownloadWebView(
                    isLoading: $isLoading,
                    loadProgress: $loadProgress,
                    errorMessage: $errorMessage,
                    statusMessage: $statusMessage,
                    debugURL: $debugURL,
                    debugUserId: $debugUserId,
                    onCSVDownloaded: { data in
                        scheduleService.processCSVData(data)
                        shiftCount = ScheduleStore.shared.shifts.count
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

                        Text("Schedule Synced!")
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)

                        Text("\(shiftCount) shifts imported")
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    .padding(32)
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(16)
                }

            }
            .navigationTitle("Sync Schedule")
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

// MARK: - WKWebView for CSV Download

struct RoompactDownloadWebView: UIViewRepresentable {
    @Binding var isLoading: Bool
    @Binding var loadProgress: Double
    @Binding var errorMessage: String?
    @Binding var statusMessage: String
    @Binding var debugURL: String?
    @Binding var debugUserId: String?
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

        // Load Roompact homepage - user will login and see feed
        let homeURL = RoompactScheduleService.shared.roompactHomeURL
        print("📥 Loading Roompact home: \(homeURL)")
        webView.load(URLRequest(url: homeURL))

        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Retry loading if error was cleared
        if errorMessage == nil && webView.url == nil {
            let homeURL = RoompactScheduleService.shared.roompactHomeURL
            webView.load(URLRequest(url: homeURL))
        }
    }

    class Coordinator: NSObject, WKNavigationDelegate, WKDownloadDelegate {
        var parent: RoompactDownloadWebView
        var progressObservation: NSKeyValueObservation?
        var hasReceivedCSV = false
        var tempFileURL: URL?
        var urlBuilder: RoompactScheduleURLBuilder?
        var hasStartedPolling = false

        init(_ parent: RoompactDownloadWebView) {
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
                return
            }

            // We're on the main Roompact page (feed) - start polling for user_id
            if urlString.contains("roompact.com") && !urlString.contains("schedule/download") && !hasStartedPolling && !hasReceivedCSV {
                hasStartedPolling = true
                DispatchQueue.main.async {
                    self.parent.statusMessage = "Finding your schedule..."
                }

                // Start polling for user ID
                urlBuilder = RoompactScheduleURLBuilder()
                urlBuilder?.start(in: webView) { [weak self] url, userId in
                    guard let self = self else { return }

                    DispatchQueue.main.async {
                        self.parent.debugUserId = userId
                        self.parent.debugURL = url?.absoluteString

                        if let downloadURL = url {
                            self.parent.statusMessage = "Downloading schedule..."
                            print("📥 User ID: \(userId ?? "nil")")
                            print("📥 Download URL: \(downloadURL)")

                            // Navigate to download URL
                            webView.load(URLRequest(url: downloadURL))
                        } else {
                            self.parent.statusMessage = "Could not find user ID. Please try again."
                            self.parent.debugUserId = "FAILED - no userId found"
                        }
                    }
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
                    self.parent.statusMessage = "Downloading schedule..."
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
               url.absoluteString.contains("schedule/download") {
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
                    self.parent.statusMessage = "Processing schedule..."
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
        ScheduleView()
    }
}
