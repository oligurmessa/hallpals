import Foundation
import WebKit

/// Shared WebKit context for maintaining authentication cookies across WKWebViews
/// All Roompact WKWebViews should use this shared context to preserve session
@MainActor
class WebContext {
    static let shared = WebContext()

    /// Shared data store (default, persistent)
    let dataStore: WKWebsiteDataStore

    /// Pre-configured WKWebViewConfiguration for Roompact
    var webViewConfiguration: WKWebViewConfiguration {
        let config = WKWebViewConfiguration()
        config.websiteDataStore = dataStore

        // Enable JavaScript
        let prefs = WKWebpagePreferences()
        prefs.allowsContentJavaScript = true
        config.defaultWebpagePreferences = prefs

        return config
    }

    private init() {
        dataStore = WKWebsiteDataStore.default()
    }

    /// Get all cookies from the cookie store
    func getAllCookies() async -> [HTTPCookie] {
        await withCheckedContinuation { continuation in
            dataStore.httpCookieStore.getAllCookies { cookies in
                continuation.resume(returning: cookies)
            }
        }
    }

    /// Check if we have Roompact authentication cookies
    func hasRoompactSession() async -> Bool {
        let cookies = await getAllCookies()
        return cookies.contains { cookie in
            cookie.domain.contains("roompact.com") &&
            (cookie.name.contains("session") || cookie.name.contains("auth"))
        }
    }

    /// Clear all Roompact cookies (for logout)
    func clearRoompactCookies() async {
        let cookies = await getAllCookies()
        let roompactCookies = cookies.filter { $0.domain.contains("roompact.com") }

        for cookie in roompactCookies {
            await dataStore.httpCookieStore.deleteCookie(cookie)
        }
    }

    /// Clear all website data (full reset)
    func clearAllData() async {
        let dataTypes = WKWebsiteDataStore.allWebsiteDataTypes()
        let date = Date(timeIntervalSince1970: 0)

        await dataStore.removeData(ofTypes: dataTypes, modifiedSince: date)
    }
}
