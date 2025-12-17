import Foundation

/// Configuration for Microsoft Graph API and MSAL authentication
/// IMPORTANT: Update these values with your Entra ID app registration details
struct MSGraphConfig {

    // MARK: - App Registration (Update these values!)

    /// Your Entra ID (Azure AD) Application (client) ID
    /// Get this from: Azure Portal → App registrations → Your app → Overview
    static let clientId = "YOUR_CLIENT_ID_HERE"

    /// Your Entra ID tenant ID (or "common" for multi-tenant)
    /// Get this from: Azure Portal → App registrations → Your app → Overview
    static let tenantId = "YOUR_TENANT_ID_HERE"

    /// The redirect URI configured in your app registration
    /// Format: msauth.<bundle-id>://auth
    /// Get bundle ID from: Xcode → Target → General → Bundle Identifier
    static var redirectUri: String {
        let bundleId = Bundle.main.bundleIdentifier ?? "com.hallpals.app"
        return "msauth.\(bundleId)://auth"
    }

    // MARK: - Graph API Endpoints

    static let graphBaseURL = "https://graph.microsoft.com/v1.0"

    // MARK: - Scopes

    /// Delegated permissions required for Excel workbook access
    static let scopes = [
        "User.Read",
        "Files.ReadWrite.All",
        "Sites.ReadWrite.All"
    ]

    // MARK: - SharePoint Excel File

    /// The SharePoint URL to your Residents.xlsx file
    /// This should be the share link from SharePoint
    /// Example: "https://yourtenant.sharepoint.com/:x:/s/sitename/ENCODED_FILE_ID"
    static let residentsExcelShareURL = "YOUR_SHAREPOINT_SHARE_URL_HERE"

    /// Excel table name for residents data
    /// Make sure you've converted your data to an Excel Table with this name
    static let residentsTableName = "Residents"

    /// Excel table name for move out requests
    static let moveOutRequestsTableName = "MoveOutRequests"

    // MARK: - Authority URL

    static var authorityURL: String {
        "https://login.microsoftonline.com/\(tenantId)"
    }

    // MARK: - Validation

    static var isConfigured: Bool {
        clientId != "YOUR_CLIENT_ID_HERE" &&
        tenantId != "YOUR_TENANT_ID_HERE" &&
        residentsExcelShareURL != "YOUR_SHAREPOINT_SHARE_URL_HERE"
    }
}
