import Foundation
import SwiftXDAVCore

/// HTTP client that handles OAuth 2.0 authentication with automatic token refresh
///
/// This client automatically manages OAuth 2.0 tokens, refreshing them when necessary
/// before making requests. It wraps a base HTTP client and adds OAuth 2.0 authentication.
///
/// ## Usage
///
/// ```swift
/// let tokenManager = OAuth2TokenManager.google(
///     accessToken: "ya29.a0...",
///     refreshToken: "1//0g...",
///     clientID: "your-client-id",
///     clientSecret: "your-client-secret"
/// )
///
/// let client = OAuth2HTTPClient(
///     baseClient: AlamofireHTTPClient(),
///     tokenManager: tokenManager
/// )
///
/// // Tokens are automatically refreshed if needed
/// let response = try await client.request(.get, url: url, headers: nil, body: nil)
/// ```
///
/// ## Topics
///
/// ### Initialization
/// - ``init(baseClient:tokenManager:)``
///
/// ### Making Requests
/// - ``request(_:url:headers:body:)``
public actor OAuth2HTTPClient: HTTPClient {
    // MARK: - Properties

    /// The underlying HTTP client
    private let baseClient: HTTPClient

    /// The OAuth 2.0 token manager
    private let tokenManager: OAuth2TokenManager

    // MARK: - Initialization

    /// Create an OAuth 2.0 HTTP client
    ///
    /// - Parameters:
    ///   - baseClient: The underlying HTTP client to use for requests
    ///   - tokenManager: The OAuth 2.0 token manager
    public init(baseClient: HTTPClient, tokenManager: OAuth2TokenManager) {
        self.baseClient = baseClient
        self.tokenManager = tokenManager
    }

    // MARK: - HTTPClient

    /// Execute an HTTP request with OAuth 2.0 authentication
    ///
    /// This method automatically:
    /// 1. Gets a valid access token (refreshing if needed)
    /// 2. Adds the Authorization header
    /// 3. Executes the request
    /// 4. Retries once with a fresh token if we get a 401 (Unauthorized)
    ///
    /// - Parameters:
    ///   - method: The HTTP method
    ///   - url: The request URL
    ///   - headers: Additional headers (Authorization will be added)
    ///   - body: The request body
    /// - Returns: The HTTP response
    /// - Throws: ``SwiftXDAVError`` if the request fails
    public func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        // Get a valid access token (refreshes if needed)
        let accessToken = try await tokenManager.getAccessToken()

        // Add OAuth 2.0 authorization header
        var authHeaders = headers ?? [:]
        authHeaders["Authorization"] = "Bearer \(accessToken)"

        // Execute request
        var response = try await baseClient.request(method, url: url, headers: authHeaders, body: body)

        // If we get 401, the token might have been revoked or expired
        // Try refreshing and retrying once
        if response.statusCode == 401 {
            // Force refresh the token
            try await tokenManager.forceRefresh()
            let newAccessToken = try await tokenManager.getAccessToken()

            // Update headers with new token
            authHeaders["Authorization"] = "Bearer \(newAccessToken)"

            // Retry the request
            response = try await baseClient.request(method, url: url, headers: authHeaders, body: body)
        }

        return response
    }
}

// MARK: - Convenience Constructors

extension OAuth2HTTPClient {
    /// Create an OAuth 2.0 HTTP client for Google services
    ///
    /// - Parameters:
    ///   - accessToken: The Google OAuth 2.0 access token
    ///   - refreshToken: The Google OAuth 2.0 refresh token
    ///   - clientID: Your Google OAuth 2.0 client ID
    ///   - clientSecret: Your Google OAuth 2.0 client secret
    ///   - expiresAt: When the access token expires
    ///   - onTokenRefresh: Callback when tokens are refreshed
    /// - Returns: A configured OAuth2HTTPClient for Google
    public static func google(
        accessToken: String,
        refreshToken: String,
        clientID: String,
        clientSecret: String,
        expiresAt: Date? = nil,
        onTokenRefresh: ((String, Date?) -> Void)? = nil
    ) -> OAuth2HTTPClient {
        let tokenManager = OAuth2TokenManager.google(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientID: clientID,
            clientSecret: clientSecret,
            expiresAt: expiresAt,
            onTokenRefresh: onTokenRefresh
        )

        return OAuth2HTTPClient(
            baseClient: AlamofireHTTPClient(),
            tokenManager: tokenManager
        )
    }
}
