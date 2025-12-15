import Foundation
import SwiftUI

#if canImport(MSAL)
import MSAL
#endif

/// Manages MSAL authentication for Microsoft Graph API
/// Handles token acquisition, caching, and refresh
@MainActor
class MSALAuthManager: ObservableObject {

    static let shared = MSALAuthManager()

    @Published var isAuthenticated = false
    @Published var userDisplayName: String?
    @Published var errorMessage: String?

    #if canImport(MSAL)
    private var msalApplication: MSALPublicClientApplication?
    private var currentAccount: MSALAccount?
    #endif

    private var accessToken: String?

    private init() {
        #if canImport(MSAL)
        setupMSAL()
        #endif
    }

    // MARK: - MSAL Setup

    #if canImport(MSAL)
    private func setupMSAL() {
        guard MSGraphConfig.isConfigured else {
            errorMessage = "MSGraph not configured. Update MSGraphConfig.swift"
            return
        }

        do {
            let authority = try MSALAADAuthority(url: URL(string: MSGraphConfig.authorityURL)!)

            let config = MSALPublicClientApplicationConfig(
                clientId: MSGraphConfig.clientId,
                redirectUri: MSGraphConfig.redirectUri,
                authority: authority
            )

            msalApplication = try MSALPublicClientApplication(configuration: config)

            // Try to get cached account
            loadCachedAccount()
        } catch {
            errorMessage = "Failed to initialize MSAL: \(error.localizedDescription)"
        }
    }

    private func loadCachedAccount() {
        guard let application = msalApplication else { return }

        do {
            let accounts = try application.allAccounts()
            if let account = accounts.first {
                currentAccount = account
                userDisplayName = account.username
                // Try silent token acquisition
                Task {
                    _ = try? await acquireTokenSilently()
                }
            }
        } catch {
            print("Failed to load cached accounts: \(error)")
        }
    }
    #endif

    // MARK: - Token Acquisition

    /// Acquires an access token, using silent acquisition if possible
    /// Falls back to interactive login if needed
    func getAccessToken() async throws -> String {
        // Return cached token if still valid
        if let token = accessToken {
            return token
        }

        #if canImport(MSAL)
        // Try silent first
        if let token = try? await acquireTokenSilently() {
            return token
        }

        // Fall back to interactive
        return try await acquireTokenInteractively()
        #else
        throw MSALError.msalNotAvailable
        #endif
    }

    #if canImport(MSAL)
    /// Attempts to acquire token silently using cached credentials
    private func acquireTokenSilently() async throws -> String {
        guard let application = msalApplication,
              let account = currentAccount else {
            throw MSALError.noAccount
        }

        let parameters = MSALSilentTokenParameters(
            scopes: MSGraphConfig.scopes,
            account: account
        )

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireTokenSilent(with: parameters) { [weak self] result, error in
                if let error = error as NSError? {
                    // Check if we need interactive login
                    if error.domain == MSALErrorDomain,
                       error.code == MSALError.interactionRequired.rawValue {
                        continuation.resume(throwing: MSALError.interactionRequired)
                    } else {
                        continuation.resume(throwing: MSALError.silentAcquisitionFailed(error.localizedDescription))
                    }
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: MSALError.noResult)
                    return
                }

                Task { @MainActor in
                    self?.accessToken = result.accessToken
                    self?.isAuthenticated = true
                }

                continuation.resume(returning: result.accessToken)
            }
        }
    }

    /// Acquires token interactively, showing login UI
    private func acquireTokenInteractively() async throws -> String {
        guard let application = msalApplication else {
            throw MSALError.notInitialized
        }

        // Get the presenting view controller
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first,
              let viewController = window.rootViewController else {
            throw MSALError.noViewController
        }

        let webviewParameters = MSALWebviewParameters(authPresentationViewController: viewController)
        let parameters = MSALInteractiveTokenParameters(
            scopes: MSGraphConfig.scopes,
            webviewParameters: webviewParameters
        )

        return try await withCheckedThrowingContinuation { continuation in
            application.acquireToken(with: parameters) { [weak self] result, error in
                if let error = error {
                    continuation.resume(throwing: MSALError.interactiveFailed(error.localizedDescription))
                    return
                }

                guard let result = result else {
                    continuation.resume(throwing: MSALError.noResult)
                    return
                }

                Task { @MainActor in
                    self?.currentAccount = result.account
                    self?.userDisplayName = result.account.username
                    self?.accessToken = result.accessToken
                    self?.isAuthenticated = true
                }

                continuation.resume(returning: result.accessToken)
            }
        }
    }
    #endif

    // MARK: - Sign Out

    func signOut() {
        #if canImport(MSAL)
        guard let application = msalApplication,
              let account = currentAccount else { return }

        do {
            try application.remove(account)
        } catch {
            print("Failed to remove account: \(error)")
        }

        currentAccount = nil
        #endif

        accessToken = nil
        isAuthenticated = false
        userDisplayName = nil
    }

    // MARK: - Interactive Sign In

    func signIn() async throws {
        #if canImport(MSAL)
        _ = try await acquireTokenInteractively()
        #else
        throw MSALError.msalNotAvailable
        #endif
    }
}

// MARK: - Error Types

enum MSALError: LocalizedError {
    case msalNotAvailable
    case notInitialized
    case noAccount
    case noResult
    case noViewController
    case interactionRequired
    case silentAcquisitionFailed(String)
    case interactiveFailed(String)

    var errorDescription: String? {
        switch self {
        case .msalNotAvailable:
            return "MSAL framework not available. Add MSAL package to your project."
        case .notInitialized:
            return "MSAL not initialized. Check your configuration."
        case .noAccount:
            return "No account found. Please sign in."
        case .noResult:
            return "No result returned from authentication."
        case .noViewController:
            return "Could not find view controller to present login."
        case .interactionRequired:
            return "User interaction required. Please sign in again."
        case .silentAcquisitionFailed(let message):
            return "Silent token acquisition failed: \(message)"
        case .interactiveFailed(let message):
            return "Interactive login failed: \(message)"
        }
    }
}
