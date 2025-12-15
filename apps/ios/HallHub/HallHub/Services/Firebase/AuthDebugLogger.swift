import Foundation

#if canImport(FirebaseCore)
import FirebaseCore
#endif

#if canImport(FirebaseAuth)
import FirebaseAuth
#endif

/// Centralized logging utility for Firebase Auth diagnostics
/// - Verbose logs are gated behind DEBUG flag
/// - Config validation always runs (returns errors for fatalError)
/// - NEVER logs passwords or tokens
enum AuthDebugLogger {

    // MARK: - Configuration Validation

    /// Validates Firebase configuration at startup
    /// Returns (isValid, errorMessage)
    /// NOTE: This runs in all builds - errors are used for fatalError messaging
    static func validateFirebaseConfig() -> (isValid: Bool, error: String?) {
        #if canImport(FirebaseCore)
        guard let app = FirebaseApp.app() else {
            return (false, "Firebase not configured. Ensure GoogleService-Info.plist is in the target and FirebaseApp.configure() is called in HallPalsApp.init().")
        }

        let options = app.options
        let projectID = options.projectID ?? ""
        let apiKey = options.apiKey ?? ""
        let bundleID = options.bundleID ?? ""
        let googleAppID = options.googleAppID ?? ""

        if projectID.isEmpty {
            return (false, "GoogleService-Info.plist missing PROJECT_ID. Re-download from Firebase Console.")
        }

        if apiKey.isEmpty {
            return (false, "GoogleService-Info.plist missing API_KEY. Re-download from Firebase Console.")
        }

        if bundleID.isEmpty {
            return (false, "GoogleService-Info.plist missing BUNDLE_ID. Re-download from Firebase Console.")
        }

        if googleAppID.isEmpty {
            return (false, "GoogleService-Info.plist missing GOOGLE_APP_ID. Re-download from Firebase Console.")
        }

        // Validate bundle ID matches the running app
        let appBundleID = Bundle.main.bundleIdentifier ?? "unknown"
        if bundleID != appBundleID {
            return (false, "Bundle ID mismatch. GoogleService-Info.plist expects '\(bundleID)' but app is '\(appBundleID)'. Download correct plist from Firebase Console.")
        }

        #if DEBUG
        logConfig(projectID: projectID, bundleID: bundleID, apiKey: apiKey, googleAppID: googleAppID)
        #endif

        return (true, nil)
        #else
        return (false, "FirebaseCore framework not linked. Add Firebase SPM package to the target.")
        #endif
    }

    // MARK: - Logging Methods (DEBUG only)

    static func logConfig(projectID: String, bundleID: String, apiKey: String, googleAppID: String) {
        #if DEBUG
        print("""

        ╔══════════════════════════════════════════════════════════════╗
        ║                 FIREBASE AUTH CONFIGURATION                   ║
        ╠══════════════════════════════════════════════════════════════╣
        ║ Project ID:   \(projectID.padding(toLength: 45, withPad: " ", startingAt: 0))║
        ║ Bundle ID:    \(bundleID.padding(toLength: 45, withPad: " ", startingAt: 0))║
        ║ API Key:      \(maskApiKey(apiKey).padding(toLength: 45, withPad: " ", startingAt: 0))║
        ║ Google App ID:\(googleAppID.padding(toLength: 45, withPad: " ", startingAt: 0))║
        ╚══════════════════════════════════════════════════════════════╝

        """)
        #endif
    }

    static func logAuthAction(_ action: String, email: String) {
        #if DEBUG
        let normalized = normalizeEmail(email)
        // Mask email for privacy in logs
        let maskedEmail = maskEmail(normalized)
        print("🔐 AUTH: \(action) | email: \(maskedEmail)")
        #endif
    }

    static func logProviderDiscovery(email: String, methods: [String]) {
        #if DEBUG
        let maskedEmail = maskEmail(email)
        let methodsStr = methods.isEmpty ? "[empty - Email Enumeration Protection may be on]" : methods.joined(separator: ", ")
        print("🔍 PROVIDERS for \(maskedEmail): \(methodsStr)")
        #endif
    }

    static func logAuthSuccess(action: String, uid: String, email: String?, isVerified: Bool) {
        #if DEBUG
        let maskedEmail = email.map { maskEmail($0) } ?? "nil"
        let verifiedStr = isVerified ? "✓" : "✗"
        print("✅ AUTH SUCCESS: \(action) | uid: \(uid.prefix(8))... | email: \(maskedEmail) | verified: \(verifiedStr)")
        #endif
    }

    static func logAuthError(action: String, error: Error) {
        #if DEBUG
        var msg = "❌ AUTH ERROR: \(action) | \(error.localizedDescription)"
        if let nsError = error as NSError? {
            msg += " | code: \(nsError.code) | \(diagnoseError(code: nsError.code))"
        }
        print(msg)
        #endif
    }

    static func logStateTransition(from: String, to: String, reason: String) {
        #if DEBUG
        print("🔄 STATE: \(from) → \(to) | \(reason)")
        #endif
    }

    static func logVerificationCheck(isVerified: Bool, userEmail: String?) {
        #if DEBUG
        let maskedEmail = userEmail.map { maskEmail($0) } ?? "nil"
        let verifiedStr = isVerified ? "✓ VERIFIED" : "✗ NOT VERIFIED"
        print("📧 VERIFICATION CHECK: \(maskedEmail) | \(verifiedStr)")
        #endif
    }

    // MARK: - Helpers

    /// Normalizes email for consistent handling (trim + lowercase)
    static func normalizeEmail(_ email: String) -> String {
        return email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    /// Masks email for privacy in logs (shows first 2 chars + domain)
    private static func maskEmail(_ email: String) -> String {
        guard let atIndex = email.firstIndex(of: "@") else { return "***" }
        let localPart = email[..<atIndex]
        let domain = email[atIndex...]
        if localPart.count <= 2 {
            return "**\(domain)"
        }
        return "\(localPart.prefix(2))***\(domain)"
    }

    /// Masks API key for logs (shows first 8 + last 4 chars)
    private static func maskApiKey(_ key: String) -> String {
        guard key.count > 12 else { return "***" }
        return "\(key.prefix(8))...\(key.suffix(4))"
    }

    private static func diagnoseError(code: Int) -> String {
        switch code {
        case 17004: return "INVALID_CREDENTIAL"
        case 17007: return "EMAIL_ALREADY_IN_USE"
        case 17008: return "INVALID_EMAIL"
        case 17009: return "WRONG_PASSWORD"
        case 17010: return "USER_DISABLED"
        case 17011: return "USER_NOT_FOUND"
        case 17020: return "NETWORK_ERROR"
        case 17026: return "WEAK_PASSWORD"
        case 17995: return "KEYCHAIN_ERROR"
        default: return "CODE_\(code)"
        }
    }
}
