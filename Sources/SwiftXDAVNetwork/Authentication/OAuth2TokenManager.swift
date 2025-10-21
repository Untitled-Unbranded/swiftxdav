import Foundation
import SwiftXDAVCore

/// OAuth 2.0 token manager with automatic refresh capabilities
///
/// This actor manages OAuth 2.0 tokens and handles automatic refresh when tokens expire.
/// It's thread-safe and can be shared across multiple HTTP clients.
///
/// ## Usage
///
/// ### Create with initial tokens
///
/// ```swift
/// let tokenManager = OAuth2TokenManager(
///     accessToken: "ya29.a0...",
///     refreshToken: "1//0g...",
///     tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
///     clientID: "your-client-id",
///     clientSecret: "your-client-secret"
/// )
/// ```
///
/// ### Get current access token (auto-refreshes if needed)
///
/// ```swift
/// let token = try await tokenManager.getAccessToken()
/// ```
///
/// ## Topics
///
/// ### Initialization
/// - ``init(accessToken:refreshToken:tokenURL:clientID:clientSecret:expiresAt:)``
///
/// ### Token Management
/// - ``getAccessToken()``
/// - ``refreshTokenIfNeeded()``
/// - ``forceRefresh()``
///
/// ### Token Information
/// - ``isExpired``
/// - ``expiresAt``
public actor OAuth2TokenManager {
    // MARK: - Properties

    /// The current access token
    private var accessToken: String

    /// The refresh token used to obtain new access tokens
    private let refreshToken: String

    /// The URL for the token refresh endpoint
    private let tokenURL: URL

    /// OAuth 2.0 client ID
    private let clientID: String

    /// OAuth 2.0 client secret
    private let clientSecret: String?

    /// When the current access token expires
    private var expiresAt: Date?

    /// Buffer time before expiration to trigger refresh (default: 5 minutes)
    private let expirationBuffer: TimeInterval = 300

    /// Callback for when tokens are refreshed (useful for persistence)
    private var onTokenRefresh: ((String, Date?) -> Void)?

    // MARK: - Initialization

    /// Create an OAuth 2.0 token manager
    ///
    /// - Parameters:
    ///   - accessToken: The initial access token
    ///   - refreshToken: The refresh token for obtaining new access tokens
    ///   - tokenURL: The token refresh endpoint URL
    ///   - clientID: OAuth 2.0 client ID
    ///   - clientSecret: OAuth 2.0 client secret (optional for some flows)
    ///   - expiresAt: When the access token expires (optional)
    ///   - onTokenRefresh: Callback when tokens are refreshed (optional)
    public init(
        accessToken: String,
        refreshToken: String,
        tokenURL: URL,
        clientID: String,
        clientSecret: String? = nil,
        expiresAt: Date? = nil,
        onTokenRefresh: ((String, Date?) -> Void)? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenURL = tokenURL
        self.clientID = clientID
        self.clientSecret = clientSecret
        self.expiresAt = expiresAt
        self.onTokenRefresh = onTokenRefresh
    }

    // MARK: - Public Methods

    /// Get the current access token, refreshing if necessary
    ///
    /// This method automatically refreshes the token if it's expired or about to expire.
    ///
    /// - Returns: A valid access token
    /// - Throws: ``SwiftXDAVError`` if token refresh fails
    public func getAccessToken() async throws -> String {
        try await refreshTokenIfNeeded()
        return accessToken
    }

    /// Check if the current token is expired or about to expire
    public var isExpired: Bool {
        guard let expiresAt = expiresAt else {
            // If we don't know when it expires, assume it might be expired
            return true
        }

        // Consider expired if within buffer time of actual expiration
        return Date().addingTimeInterval(expirationBuffer) >= expiresAt
    }

    /// Refresh the token if it's expired or about to expire
    ///
    /// - Throws: ``SwiftXDAVError`` if refresh fails
    public func refreshTokenIfNeeded() async throws {
        guard isExpired else {
            return
        }

        try await forceRefresh()
    }

    /// Force a token refresh regardless of expiration status
    ///
    /// - Throws: ``SwiftXDAVError`` if refresh fails
    public func forceRefresh() async throws {
        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")

        // Build request body
        var bodyComponents = URLComponents()
        bodyComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientID)
        ]

        if let clientSecret = clientSecret {
            bodyComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }

        request.httpBody = bodyComponents.query?.data(using: .utf8)

        // Execute request
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SwiftXDAVError.networkError(underlying: URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            let errorMessage = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw SwiftXDAVError.invalidResponse(
                statusCode: httpResponse.statusCode,
                body: errorMessage
            )
        }

        // Parse response
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let newAccessToken = json["access_token"] as? String else {
            throw SwiftXDAVError.parsingError("Failed to parse token response")
        }

        // Update token
        self.accessToken = newAccessToken

        // Update expiration if provided
        if let expiresIn = json["expires_in"] as? TimeInterval {
            self.expiresAt = Date().addingTimeInterval(expiresIn)
        }

        // Notify callback
        onTokenRefresh?(newAccessToken, expiresAt)
    }

    /// Update the token refresh callback
    ///
    /// - Parameter callback: Callback to invoke when tokens are refreshed
    public func setTokenRefreshCallback(_ callback: @escaping (String, Date?) -> Void) {
        self.onTokenRefresh = callback
    }
}

// MARK: - Google-Specific Helper

extension OAuth2TokenManager {
    /// Create a token manager for Google services
    ///
    /// - Parameters:
    ///   - accessToken: The Google OAuth 2.0 access token
    ///   - refreshToken: The Google OAuth 2.0 refresh token
    ///   - clientID: Your Google OAuth 2.0 client ID
    ///   - clientSecret: Your Google OAuth 2.0 client secret
    ///   - expiresAt: When the access token expires
    ///   - onTokenRefresh: Callback when tokens are refreshed
    /// - Returns: A configured OAuth2TokenManager for Google
    public static func google(
        accessToken: String,
        refreshToken: String,
        clientID: String,
        clientSecret: String,
        expiresAt: Date? = nil,
        onTokenRefresh: ((String, Date?) -> Void)? = nil
    ) -> OAuth2TokenManager {
        OAuth2TokenManager(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
            clientID: clientID,
            clientSecret: clientSecret,
            expiresAt: expiresAt,
            onTokenRefresh: onTokenRefresh
        )
    }
}
