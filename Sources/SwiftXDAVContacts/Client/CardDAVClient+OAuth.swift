import Foundation
import SwiftXDAVCore
import SwiftXDAVNetwork

// MARK: - OAuth 2.0 Convenience Initializers

extension CardDAVClient {
    /// Create a CardDAV client for Google Contacts with OAuth 2.0 token refresh
    ///
    /// Google Contacts requires OAuth 2.0 authentication with automatic token refresh.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let client = CardDAVClient.googleWithRefresh(
    ///     accessToken: "current-access-token",
    ///     refreshToken: "refresh-token",
    ///     clientID: "your-client-id",
    ///     clientSecret: "your-client-secret"
    /// )
    /// ```
    ///
    /// - Parameters:
    ///   - accessToken: Current OAuth 2.0 access token
    ///   - refreshToken: OAuth 2.0 refresh token
    ///   - expiresIn: Number of seconds until access token expires
    ///   - clientID: Google OAuth 2.0 client ID
    ///   - clientSecret: Google OAuth 2.0 client secret
    /// - Returns: A configured CardDAV client for Google Contacts
    public static func googleWithRefresh(
        accessToken: String,
        refreshToken: String,
        expiresIn: Int? = nil,
        clientID: String,
        clientSecret: String
    ) -> CardDAVClient {
        let baseClient = AlamofireHTTPClient()
        let tokenManager = OAuth2TokenManager(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
            clientID: clientID,
            clientSecret: clientSecret
        )
        let oauthClient = OAuth2HTTPClient(baseClient: baseClient, tokenManager: tokenManager)

        return CardDAVClient(
            httpClient: oauthClient,
            baseURL: URL(string: "https://www.googleapis.com/.well-known/carddav")!
        )
    }

    /// Create a CardDAV client with custom OAuth 2.0 token refresh
    ///
    /// Use this for servers that support OAuth 2.0 authentication.
    ///
    /// - Parameters:
    ///   - baseURL: Base URL of the CardDAV server
    ///   - accessToken: Current OAuth 2.0 access token
    ///   - refreshToken: OAuth 2.0 refresh token
    ///   - tokenURL: URL for token refresh requests
    ///   - clientID: OAuth 2.0 client ID
    ///   - clientSecret: OAuth 2.0 client secret (optional)
    ///   - expiresIn: Number of seconds until access token expires
    /// - Returns: A configured CardDAV client
    public static func customWithOAuth(
        baseURL: URL,
        accessToken: String,
        refreshToken: String?,
        tokenURL: URL,
        clientID: String,
        clientSecret: String? = nil,
        expiresIn: Int? = nil
    ) -> CardDAVClient {
        let baseClient = AlamofireHTTPClient()
        let tokenManager = OAuth2TokenManager(
            accessToken: accessToken,
            refreshToken: refreshToken,
            expiresIn: expiresIn,
            tokenURL: tokenURL,
            clientID: clientID,
            clientSecret: clientSecret
        )
        let oauthClient = OAuth2HTTPClient(baseClient: baseClient, tokenManager: tokenManager)

        return CardDAVClient(
            httpClient: oauthClient,
            baseURL: baseURL
        )
    }

    /// Detect server capabilities
    ///
    /// This performs server capability detection to determine which features
    /// are supported.
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let client = CardDAVClient.iCloud(username: "user@icloud.com", appSpecificPassword: "xxxx-xxxx-xxxx-xxxx")
    /// let capabilities = try await client.detectServerCapabilities()
    /// print("Server: \(capabilities.serverType)")
    /// print("Supports sync tokens: \(capabilities.supportsSyncToken)")
    /// ```
    ///
    /// - Returns: Detected server capabilities
    /// - Throws: `SwiftXDAVError` if detection fails
    public func detectServerCapabilities() async throws -> ServerCapabilities {
        let detector = ServerDetector(httpClient: httpClient)
        return try await detector.detect(baseURL: baseURL)
    }
}
