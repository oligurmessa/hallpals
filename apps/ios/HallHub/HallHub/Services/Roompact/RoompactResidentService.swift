import Foundation
import WebKit

/// Service for extracting resident data from Roompact
/// Handles CSV download, parsing, and resident conversion
@MainActor
class RoompactResidentService: ObservableObject {
    static let shared = RoompactResidentService()

    @Published var state: ResidentLoadingState = .idle

    private let residentStore = ResidentStore.shared

    private init() {}

    // MARK: - URL

    /// Roompact agreement submissions CSV URL
    let residentsDownloadURL = URL(string: "https://roompact.com/core/agreementSubmissions/summary.csv")!

    // MARK: - CSV Processing

    /// Process downloaded CSV data
    func processCSVData(_ data: Data) {
        state = .parsing

        guard let csvText = String(data: data, encoding: .utf8) else {
            state = .error("Invalid CSV data")
            return
        }

        // Parse the CSV
        let residents = parseResidentsCSV(csvText)

        // Save to store
        residentStore.saveResidents(residents)

        state = .complete
        print("✔️ Parsed \(residents.count) residents from Roompact")
    }

    // MARK: - CSV Parsing

    /// Parse Roompact agreement submissions CSV
    /// Format varies but typically has resident names (comma-separated when multiple in one cell)
    func parseResidentsCSV(_ csv: String) -> [RoompactResident] {
        var results: [RoompactResident] = []
        var seenNames: Set<String> = []

        let rows = csv.components(separatedBy: "\n")

        // Try to detect header row and column indices
        guard let headerRow = rows.first else { return results }
        let headers = parseCSVRow(headerRow).map { $0.lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }

        // Find relevant column indices
        let nameIndex = findColumnIndex(headers: headers, candidates: ["name", "resident", "residents", "student", "students", "occupant", "occupants"])
        let roomIndex = findColumnIndex(headers: headers, candidates: ["room", "room number", "room #", "unit", "space"])
        let buildingIndex = findColumnIndex(headers: headers, candidates: ["building", "hall", "residence hall", "property"])
        let emailIndex = findColumnIndex(headers: headers, candidates: ["email", "e-mail", "email address"])

        // If we can't find a name column, try to parse the whole thing more loosely
        guard let nameIdx = nameIndex else {
            // Fallback: try to extract names from any column that looks like names
            return parseResidentsLoose(rows: rows)
        }

        // Parse data rows
        for row in rows.dropFirst() {
            let cols = parseCSVRow(row)
            guard cols.count > nameIdx else { continue }

            let nameCell = cols[nameIdx].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !nameCell.isEmpty else { continue }

            // Handle comma-separated names in the same cell
            let names = splitNames(nameCell)

            for name in names {
                let cleanName = name.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")

                // Skip empty or header-like values
                guard !cleanName.isEmpty,
                      !cleanName.lowercased().contains("name"),
                      cleanName.count > 2 else { continue }

                // Avoid duplicates
                let normalizedName = cleanName.lowercased()
                guard !seenNames.contains(normalizedName) else { continue }
                seenNames.insert(normalizedName)

                let room = roomIndex.flatMap { idx in
                    cols.count > idx ? cols[idx].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                }
                let building = buildingIndex.flatMap { idx in
                    cols.count > idx ? cols[idx].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                }
                let email = emailIndex.flatMap { idx in
                    cols.count > idx ? cols[idx].trimmingCharacters(in: .whitespacesAndNewlines) : nil
                }

                let resident = RoompactResident(
                    name: cleanName,
                    room: room?.isEmpty == true ? nil : room,
                    building: building?.isEmpty == true ? nil : building,
                    email: email?.isEmpty == true ? nil : email
                )
                results.append(resident)
            }
        }

        return results
    }

    /// Find column index from list of candidate header names
    private func findColumnIndex(headers: [String], candidates: [String]) -> Int? {
        for (index, header) in headers.enumerated() {
            for candidate in candidates {
                if header.contains(candidate) {
                    return index
                }
            }
        }
        return nil
    }

    /// Split comma-separated names, handling edge cases
    private func splitNames(_ cell: String) -> [String] {
        // Check if this looks like comma-separated names
        // (vs a single name with a comma like "Smith, John")

        let parts = cell.components(separatedBy: ",")

        // If we have "LastName, FirstName" format (2 parts, second is short)
        if parts.count == 2 {
            let first = parts[0].trimmingCharacters(in: .whitespaces)
            let second = parts[1].trimmingCharacters(in: .whitespaces)

            // Likely "Smith, John" format - single person
            if second.count < 20 && !second.contains(" ") {
                return ["\(second) \(first)"]  // Convert to "John Smith"
            }
        }

        // Multiple names comma-separated
        return parts.map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Fallback parser when we can't identify columns
    private func parseResidentsLoose(rows: [String]) -> [RoompactResident] {
        var results: [RoompactResident] = []
        var seenNames: Set<String> = []

        for row in rows.dropFirst() {
            let cols = parseCSVRow(row)

            for col in cols {
                let trimmed = col.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "\"", with: "")

                // Check if this looks like a name (has letters, reasonable length)
                guard trimmed.count >= 3,
                      trimmed.count <= 100,
                      trimmed.rangeOfCharacter(from: .letters) != nil,
                      !trimmed.contains("@"),  // Not an email
                      !trimmed.allSatisfy({ $0.isNumber || $0 == "-" || $0 == "/" })  // Not a date/number
                else { continue }

                // Try to split comma-separated names
                let names = splitNames(trimmed)

                for name in names {
                    let normalized = name.lowercased()

                    // Skip if looks like a header or already seen
                    guard !seenNames.contains(normalized),
                          !normalized.contains("name"),
                          !normalized.contains("resident"),
                          name.contains(" ") || name.count > 5  // Has space or is reasonably long
                    else { continue }

                    seenNames.insert(normalized)
                    results.append(RoompactResident(name: name))
                }
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

    // MARK: - Reset

    /// Clear all resident data
    func clearData() {
        residentStore.clearAll()
        state = .idle
    }
}
