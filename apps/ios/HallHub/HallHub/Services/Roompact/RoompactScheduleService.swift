import Foundation
import WebKit

// MARK: - Roompact Schedule URL Builder

/// Polls the webview for user_id from window.feed.posts and builds the download URL
final class RoompactScheduleURLBuilder: NSObject {

    private weak var webView: WKWebView?
    private var completion: ((URL?, String?) -> Void)?
    private var attempts = 0
    private let maxAttempts = 30   // ~60 seconds

    func start(in webView: WKWebView, completion: @escaping (URL?, String?) -> Void) {
        self.webView = webView
        self.completion = completion
        self.attempts = 0
        pollForUserID()
    }

    private func pollForUserID() {
        guard attempts < maxAttempts else {
            completion?(nil, nil)
            cleanup()
            return
        }

        attempts += 1
        print("🔍 Polling attempt \(attempts)/\(maxAttempts) for user_id...")

        let js = """
        (function() {
            try {
                if (window.feed && window.feed.posts && Object.keys(window.feed.posts).length > 0) {
                    const counts = {};
                    for (const k in window.feed.posts) {
                        const uid = window.feed.posts[k].uid;
                        if (uid) counts[uid] = (counts[uid] || 0) + 1;
                    }
                    let maxUid = null;
                    let maxCount = 0;
                    for (const uid in counts) {
                        if (counts[uid] > maxCount) {
                            maxUid = uid;
                            maxCount = counts[uid];
                        }
                    }
                    return maxUid;
                }
            } catch(e) {
                console.log('Error extracting userId:', e);
            }
            return null;
        })();
        """

        webView?.evaluateJavaScript(js) { [weak self] result, error in
            guard let self = self else { return }

            if let error = error {
                print("🔍 JS Error: \(error.localizedDescription)")
            }

            if let userId = result as? String {
                print("🔍 Found userId: \(userId)")
                let url = self.buildScheduleURL(userId: userId)
                self.completion?(url, userId)
                self.cleanup()
            } else {
                print("🔍 No userId yet, result was: \(String(describing: result))")
                DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
                    self.pollForUserID()
                }
            }
        }
    }

    private func buildScheduleURL(userId: String) -> URL? {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        let startDate = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 6, to: startDate)!

        let start = formatter.string(from: startDate)
        let end = formatter.string(from: endDate)

        let urlString =
        "https://roompact.com/schedule/download" +
        "?start=\(start)" +
        "&end=\(end)" +
        "&region_id=0" +
        "&user_id=\(userId)" +
        "&tz=-06:00"

        return URL(string: urlString)
    }

    private func cleanup() {
        completion = nil
        webView = nil
    }
}

// MARK: - Roompact Schedule Service

/// Service for extracting schedule data from Roompact
/// Handles CSV download, parsing, and shift conversion
@MainActor
class RoompactScheduleService: ObservableObject {
    static let shared = RoompactScheduleService()

    @Published var state: ScheduleLoadingState = .idle

    private let scheduleStore = ScheduleStore.shared

    private init() {}

    // MARK: - Roompact Login URL

    var roompactHomeURL: URL {
        URL(string: "https://roompact.com/login")!
    }

    // MARK: - CSV Processing

    /// Process downloaded CSV data
    func processCSVData(_ data: Data) {
        state = .parsing

        guard let csvText = String(data: data, encoding: .utf8) else {
            state = .error("Invalid CSV data")
            return
        }

        // Parse the CSV
        let dates = parseScheduleCSV(csvText)

        // Convert to shifts
        let shifts = convertToShifts(dates)

        // Save to store
        scheduleStore.saveShifts(shifts)

        state = .complete
        print("✔️ Parsed \(shifts.count) shifts from Roompact")
    }

    // MARK: - CSV Parsing

    /// Parse Roompact CSV - Column E (index 4) contains dates
    func parseScheduleCSV(_ csv: String) -> [Date] {
        var results: [Date] = []

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Also try other common date formats
        let altFormatter = DateFormatter()
        altFormatter.dateFormat = "MM/dd/yyyy"

        let rows = csv.components(separatedBy: "\n")

        for row in rows.dropFirst() { // Skip header
            // Handle CSV with quoted fields
            let cols = parseCSVRow(row)

            guard cols.count > 4 else { continue }

            let dateString = cols[4].trimmingCharacters(in: .whitespacesAndNewlines)
                .replacingOccurrences(of: "\"", with: "")

            if let date = dateFormatter.date(from: dateString) {
                results.append(date)
            } else if let date = altFormatter.date(from: dateString) {
                results.append(date)
            }
        }

        return results
    }

    /// Parse a CSV row, handling quoted fields
    private func parseCSVRow(_ row: String) -> [String] {
        var result: [String] = []
        var current = ""
        var inQuotes = false

        for char in row {
            if char == "\"" {
                inQuotes.toggle()
            } else if char == "," && !inQuotes {
                result.append(current)
                current = ""
            } else {
                current.append(char)
            }
        }
        result.append(current)

        return result
    }

    // MARK: - Shift Conversion

    /// Convert dates to shift objects (4:30 PM - 8:00 AM next day)
    func convertToShifts(_ dates: [Date]) -> [Shift] {
        let calendar = Calendar.current

        return dates.compactMap { day -> Shift? in
            // Start at 4:30 PM same day
            guard let start = calendar.date(bySettingHour: 16, minute: 30, second: 0, of: day) else {
                return nil
            }

            // End at 8:00 AM next day
            guard let endDay = calendar.date(byAdding: .day, value: 1, to: day),
                  let end = calendar.date(bySettingHour: 8, minute: 0, second: 0, of: endDay) else {
                return nil
            }

            return Shift(start: start, end: end)
        }
    }

    // MARK: - Reset

    /// Clear all Roompact data (logout)
    func logout() async {
        await WebContext.shared.clearRoompactCookies()
        scheduleStore.clearAll()
        state = .idle
    }
}
