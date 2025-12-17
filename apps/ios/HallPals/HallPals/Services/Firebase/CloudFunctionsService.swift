import Foundation

#if canImport(FirebaseFunctions)
import FirebaseFunctions
#endif

/// Service for calling Cloud Functions
/// Phase C2.1: Server-controlled role assignment
@MainActor
final class CloudFunctionsService: ObservableObject {

    // MARK: - Singleton

    static let shared = CloudFunctionsService()

    // MARK: - State

    @Published private(set) var isLoading = false
    @Published private(set) var error: String?

    #if canImport(FirebaseFunctions)
    private lazy var functions = Functions.functions()
    #endif

    // MARK: - Init

    private init() {}

    // MARK: - Response Types

    struct JoinHallResponse {
        let success: Bool
        let role: String
        let hallId: String
        let message: String
    }

    struct EnsureUserDocResponse {
        let success: Bool
        let action: String // "created", "updated", or "none"
        let uid: String
    }

    struct AIResponse {
        let response: String
        let model: String
    }

    // MARK: - Join Hall

    /// Calls the joinHallWithCode Cloud Function
    /// V2: Role is now determined by roster lookup on the server
    /// hallId is optional - if not provided, server discovers from roster or admin assigns later
    func joinHall(hallId: String? = nil) async throws -> JoinHallResponse {
        #if canImport(FirebaseFunctions)
        isLoading = true
        error = nil

        defer { isLoading = false }

        #if DEBUG
        print("☁️ FUNCTIONS: Calling joinHallWithCode with hallId: \(hallId ?? "none")")
        #endif

        do {
            // Build request data - only include hallId if provided
            var requestData: [String: Any] = [:]
            if let hallId = hallId {
                requestData["hallId"] = hallId
            }

            let result = try await functions.httpsCallable("joinHallWithCode").call(requestData)

            guard let data = result.data as? [String: Any] else {
                throw CloudFunctionsError.invalidResponse
            }

            let success = data["success"] as? Bool ?? false
            let role = data["role"] as? String ?? ""
            let returnedHallId = data["hallId"] as? String ?? ""  // Empty string if no hall assigned
            let message = data["message"] as? String ?? ""

            #if DEBUG
            print("☁️ FUNCTIONS: joinHallWithCode response - success: \(success), role: \(role), hallId: \(returnedHallId.isEmpty ? "none" : returnedHallId)")
            #endif

            if !success {
                throw CloudFunctionsError.functionFailed(message)
            }

            return JoinHallResponse(
                success: success,
                role: role,
                hallId: returnedHallId,
                message: message
            )

        } catch let error as NSError {
            #if DEBUG
            print("☁️ FUNCTIONS: joinHallWithCode error - \(error.localizedDescription)")
            #endif

            // Parse Firebase Functions error
            let message = parseFunctionsError(error)
            self.error = message
            throw CloudFunctionsError.functionFailed(message)
        }
        #else
        throw CloudFunctionsError.notConfigured
        #endif
    }

    // MARK: - Ensure User Doc (Self-heal)

    /// Ensures /users/{uid} exists with tenantId
    /// Call this after login and on app launch when already logged in
    /// This is a safety net for users created before the auth trigger was deployed
    func ensureUserDoc() async throws -> EnsureUserDocResponse {
        #if canImport(FirebaseFunctions)
        isLoading = true
        error = nil

        defer { isLoading = false }

        #if DEBUG
        print("☁️ FUNCTIONS: Calling ensureUserDoc")
        #endif

        do {
            let result = try await functions.httpsCallable("ensureUserDoc").call([:])

            guard let data = result.data as? [String: Any] else {
                throw CloudFunctionsError.invalidResponse
            }

            let success = data["success"] as? Bool ?? false
            let action = data["action"] as? String ?? "none"
            let uid = data["uid"] as? String ?? ""

            #if DEBUG
            print("☁️ FUNCTIONS: ensureUserDoc response - success: \(success), action: \(action), uid: \(uid)")
            #endif

            return EnsureUserDocResponse(
                success: success,
                action: action,
                uid: uid
            )

        } catch let error as NSError {
            #if DEBUG
            print("☁️ FUNCTIONS: ensureUserDoc error - \(error.localizedDescription)")
            #endif

            let message = parseFunctionsError(error)
            self.error = message
            throw CloudFunctionsError.functionFailed(message)
        }
        #else
        throw CloudFunctionsError.notConfigured
        #endif
    }

    // MARK: - Ask AI

    /// Calls the askAI Cloud Function with Vertex AI (Gemini)
    /// - Parameters:
    ///   - prompt: The user's question or prompt
    ///   - systemPrompt: Optional system context for the AI
    ///   - model: Optional model override (default: gemini-2.0-flash)
    /// - Returns: The AI's response text
    func askAI(prompt: String, systemPrompt: String? = nil, model: String? = nil) async throws -> AIResponse {
        #if canImport(FirebaseFunctions)
        isLoading = true
        error = nil

        defer { isLoading = false }

        #if DEBUG
        print("🤖 AI: Calling askAI with prompt: \(prompt.prefix(50))...")
        #endif

        var data: [String: Any] = ["prompt": prompt]
        if let system = systemPrompt {
            data["systemPrompt"] = system
        }
        if let model = model {
            data["model"] = model
        }

        do {
            let result = try await functions.httpsCallable("askAI").call(data)

            guard let responseData = result.data as? [String: Any],
                  let responseText = responseData["response"] as? String else {
                throw CloudFunctionsError.invalidResponse
            }

            let responseModel = responseData["model"] as? String ?? "unknown"

            #if DEBUG
            print("🤖 AI: Response received from model: \(responseModel)")
            #endif

            return AIResponse(response: responseText, model: responseModel)

        } catch let error as NSError {
            #if DEBUG
            print("🤖 AI: Error - \(error.localizedDescription)")
            #endif

            let message = parseFunctionsError(error)
            self.error = message
            throw CloudFunctionsError.functionFailed(message)
        }
        #else
        throw CloudFunctionsError.notConfigured
        #endif
    }

    // MARK: - Error Parsing

    private func parseFunctionsError(_ error: NSError) -> String {
        // Firebase Functions errors have a specific domain
        if error.domain == "com.firebase.functions" {
            // Check for specific error codes
            switch error.code {
            case 3: // INVALID_ARGUMENT
                return error.localizedDescription
            case 5: // NOT_FOUND
                return "Hall not found"
            case 7: // PERMISSION_DENIED
                return "Permission denied"
            case 16: // UNAUTHENTICATED
                return "Please sign in first"
            default:
                return error.localizedDescription
            }
        }

        return error.localizedDescription
    }
}

// MARK: - Errors

enum CloudFunctionsError: LocalizedError {
    case notConfigured
    case invalidResponse
    case functionFailed(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured:
            return "Cloud Functions is not configured"
        case .invalidResponse:
            return "Invalid response from server"
        case .functionFailed(let message):
            return message
        }
    }
}
