import Foundation

/// Service for interacting with Excel workbooks via Microsoft Graph API
/// Handles reading and writing to Excel tables in SharePoint/OneDrive
@MainActor
class GraphWorkbookService: ObservableObject {

    static let shared = GraphWorkbookService()

    @Published var isLoading = false
    @Published var errorMessage: String?

    private var driveId: String?
    private var itemId: String?
    private var sessionId: String?

    private let authManager = MSALAuthManager.shared

    private init() {}

    // MARK: - Share ID Generation

    /// Converts a SharePoint URL to a Graph shareId
    /// Algorithm: base64 encode URL, convert to unpadded base64url, prefix with "u!"
    private func graphShareId(from urlString: String) -> String {
        let data = Data(urlString.utf8)
        var b64 = data.base64EncodedString()
        b64 = b64.replacingOccurrences(of: "=", with: "")
                 .replacingOccurrences(of: "/", with: "_")
                 .replacingOccurrences(of: "+", with: "-")
        return "u!\(b64)"
    }

    // MARK: - Initialize Workbook Access

    /// Resolves the SharePoint share URL to driveId and itemId
    /// Must be called before any workbook operations
    func initializeWorkbookAccess() async throws {
        guard MSGraphConfig.isConfigured else {
            throw GraphError.notConfigured
        }

        isLoading = true
        defer { isLoading = false }

        let token = try await authManager.getAccessToken()

        // Convert SharePoint URL to share token
        let shareId = graphShareId(from: MSGraphConfig.residentsExcelShareURL)

        // Resolve driveItem from share
        let url = URL(string: "\(MSGraphConfig.graphBaseURL)/shares/\(shareId)/driveItem")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GraphError.failedToResolveDriveItem
        }

        let driveItem = try JSONDecoder().decode(DriveItemResponse.self, from: data)

        self.driveId = driveItem.parentReference.driveId
        self.itemId = driveItem.id

        // Create workbook session for better performance
        try await createWorkbookSession()
    }

    // MARK: - Workbook Session

    /// Creates a workbook session for more efficient multi-call operations
    private func createWorkbookSession() async throws {
        guard let driveId = driveId, let itemId = itemId else {
            throw GraphError.notInitialized
        }

        let token = try await authManager.getAccessToken()

        let url = URL(string: "\(MSGraphConfig.graphBaseURL)/drives/\(driveId)/items/\(itemId)/workbook/createSession")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONEncoder().encode(["persistChanges": true])

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 else {
            // Session creation failed, but we can continue without it
            print("Warning: Could not create workbook session")
            return
        }

        let sessionResponse = try JSONDecoder().decode(WorkbookSessionResponse.self, from: data)
        self.sessionId = sessionResponse.id
    }

    // MARK: - Read Residents Table

    /// Fetches all rows from the Residents table
    func fetchResidents() async throws -> [Resident] {
        guard let driveId = driveId, let itemId = itemId else {
            throw GraphError.notInitialized
        }

        isLoading = true
        defer { isLoading = false }

        let token = try await authManager.getAccessToken()
        let tableName = MSGraphConfig.residentsTableName

        let url = URL(string: "\(MSGraphConfig.graphBaseURL)/drives/\(driveId)/items/\(itemId)/workbook/tables/\(tableName)/rows")!

        var request = URLRequest(url: url)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        if let sessionId = sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "workbook-session-id")
        }

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GraphError.failedToFetchRows
        }

        let rowsResponse = try JSONDecoder().decode(TableRowsResponse.self, from: data)

        // Parse rows into Resident structs
        // Assuming columns: Name, Room, Email, Phone, MoveOutStatus, MoveOutDate
        return rowsResponse.value.compactMap { row -> Resident? in
            guard row.values.count >= 4 else { return nil }

            let values = row.values[0] // First (and only) row array

            return Resident(
                id: UUID().uuidString,
                name: values[safe: 0] as? String ?? "",
                room: values[safe: 1] as? String ?? "",
                email: values[safe: 2] as? String ?? "",
                phone: values[safe: 3] as? String ?? "",
                moveOutStatus: MoveOutStatus(rawValue: values[safe: 4] as? String ?? "") ?? .none,
                moveOutDate: values[safe: 5] as? String,
                rowIndex: row.index
            )
        }
    }

    // MARK: - Add Move Out Request

    /// Adds a new move out request row to the MoveOutRequests table
    func addMoveOutRequest(_ request: MoveOutRequest) async throws {
        guard let driveId = driveId, let itemId = itemId else {
            throw GraphError.notInitialized
        }

        isLoading = true
        defer { isLoading = false }

        let token = try await authManager.getAccessToken()
        let tableName = MSGraphConfig.moveOutRequestsTableName

        let url = URL(string: "\(MSGraphConfig.graphBaseURL)/drives/\(driveId)/items/\(itemId)/workbook/tables/\(tableName)/rows/add")!

        var urlRequest = URLRequest(url: url)
        urlRequest.httpMethod = "POST"
        urlRequest.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        urlRequest.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionId = sessionId {
            urlRequest.setValue(sessionId, forHTTPHeaderField: "workbook-session-id")
        }

        // Format row values matching your Excel table columns
        let rowValues: [[Any]] = [[
            request.residentName,
            request.room,
            request.requestedDate,
            request.reason,
            request.status.rawValue,
            ISO8601DateFormatter().string(from: Date()),
            request.notes ?? ""
        ]]

        let body: [String: Any] = ["values": rowValues]
        urlRequest.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: urlRequest)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 201 || httpResponse.statusCode == 200 else {
            throw GraphError.failedToAddRow
        }
    }

    // MARK: - Update Resident Status

    /// Updates a resident's move out status in the Residents table
    func updateResidentStatus(rowIndex: Int, status: MoveOutStatus, date: String?) async throws {
        guard let driveId = driveId, let itemId = itemId else {
            throw GraphError.notInitialized
        }

        isLoading = true
        defer { isLoading = false }

        let token = try await authManager.getAccessToken()

        // Calculate the range address (assuming MoveOutStatus is column E, MoveOutDate is column F)
        // Row index from Graph is 0-based, Excel rows are 1-based, plus header row
        let excelRow = rowIndex + 2
        let rangeAddress = "E\(excelRow):F\(excelRow)"

        let url = URL(string: "\(MSGraphConfig.graphBaseURL)/drives/\(driveId)/items/\(itemId)/workbook/worksheets/Sheet1/range(address='\(rangeAddress)')")!

        var request = URLRequest(url: url)
        request.httpMethod = "PATCH"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let sessionId = sessionId {
            request.setValue(sessionId, forHTTPHeaderField: "workbook-session-id")
        }

        let values: [[Any]] = [[status.rawValue, date ?? ""]]
        let body: [String: Any] = ["values": values]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (_, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GraphError.failedToUpdateRow
        }
    }

    // MARK: - Close Session

    /// Closes the workbook session when done
    func closeSession() async {
        guard let driveId = driveId,
              let itemId = itemId,
              let sessionId = sessionId else { return }

        guard let token = try? await authManager.getAccessToken() else { return }

        let url = URL(string: "\(MSGraphConfig.graphBaseURL)/drives/\(driveId)/items/\(itemId)/workbook/closeSession")!

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue(sessionId, forHTTPHeaderField: "workbook-session-id")

        _ = try? await URLSession.shared.data(for: request)
        self.sessionId = nil
    }
}

// MARK: - Response Models

struct DriveItemResponse: Codable {
    let id: String
    let name: String
    let parentReference: ParentReference

    struct ParentReference: Codable {
        let driveId: String
    }
}

struct WorkbookSessionResponse: Codable {
    let id: String
    let persistChanges: Bool
}

struct TableRowsResponse: Codable {
    let value: [TableRow]

    struct TableRow: Codable {
        let index: Int
        let values: [[Any]]

        enum CodingKeys: String, CodingKey {
            case index
            case values
        }

        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            index = try container.decode(Int.self, forKey: .index)

            // Values come as array of arrays with mixed types
            let rawValues = try container.decode([[AnyCodable]].self, forKey: .values)
            values = rawValues.map { $0.map { $0.value } }
        }

        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(index, forKey: .index)
            try container.encode(values.map { $0.map { AnyCodable($0) } }, forKey: .values)
        }
    }
}

// MARK: - AnyCodable Helper

struct AnyCodable: Codable {
    let value: Any

    init(_ value: Any) {
        self.value = value
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()

        if let string = try? container.decode(String.self) {
            value = string
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if container.decodeNil() {
            value = ""
        } else {
            value = ""
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()

        if let string = value as? String {
            try container.encode(string)
        } else if let int = value as? Int {
            try container.encode(int)
        } else if let double = value as? Double {
            try container.encode(double)
        } else if let bool = value as? Bool {
            try container.encode(bool)
        } else {
            try container.encodeNil()
        }
    }
}

// MARK: - Error Types

enum GraphError: LocalizedError {
    case notConfigured
    case notInitialized
    case failedToResolveDriveItem
    case failedToFetchRows
    case failedToAddRow
    case failedToUpdateRow

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Microsoft Graph not configured. Update MSGraphConfig.swift with your app registration details."
        case .notInitialized:
            return "Workbook access not initialized. Call initializeWorkbookAccess() first."
        case .failedToResolveDriveItem:
            return "Could not access the Excel file. Check your SharePoint URL."
        case .failedToFetchRows:
            return "Failed to fetch data from Excel table."
        case .failedToAddRow:
            return "Failed to add row to Excel table."
        case .failedToUpdateRow:
            return "Failed to update row in Excel table."
        }
    }
}

// MARK: - Array Safe Subscript

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
