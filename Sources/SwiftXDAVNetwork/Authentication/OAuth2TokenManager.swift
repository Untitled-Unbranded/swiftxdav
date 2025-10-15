import Foundation
import SwiftXDAVCore

/// Manages OAuth 2.0 access and refresh tokens with automatic refresh
///
/// This actor handles OAuth 2.0 token lifecycle, automatically refreshing
/// expired access tokens using refresh tokens.
///
/// ## Usage
///
/// ```swift
/// let tokenManager = OAuth2TokenManager(
///     accessToken: "current-access-token",
///     refreshToken: "refresh-token",
///     tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
///     clientID: "your-client-id",
///     clientSecret: "your-client-secret"
/// )
///
/// // Get current valid token (automatically refreshes if expired)
/// let token = try await tokenManager.getValidAccessToken()
/// ```
public actor OAuth2TokenManager {
    /// OAuth 2.0 token response
    public struct TokenResponse: Sendable, Codable {
        public let accessToken: String
        public let refreshToken: String?
        public let expiresIn: Int?
        public let tokenType: String?

        enum CodingKeys: String, CodingKey {
            case accessToken = "access_token"
            case refreshToken = "refresh_token"
            case expiresIn = "expires_in"
            case tokenType = "token_type"
        }

        public init(accessToken: String, refreshToken: String? = nil, expiresIn: Int? = nil, tokenType: String? = nil) {
            self.accessToken = accessToken
            self.refreshToken = refreshToken
            self.expiresIn = expiresIn
            self.tokenType = tokenType
        }
    }

    private var accessToken: String
    private var refreshToken: String?
    private var expiresAt: Date?

    private let tokenURL: URL
    private let clientID: String
    private let clientSecret: String?

    /// Initialize OAuth 2.0 token manager
    ///
    /// - Parameters:
    ///   - accessToken: Current access token
    ///   - refreshToken: Refresh token for obtaining new access tokens
    ///   - expiresIn: Number of seconds until access token expires
    ///   - tokenURL: URL for token refresh requests
    ///   - clientID: OAuth 2.0 client ID
    ///   - clientSecret: OAuth 2.0 client secret (optional for some flows)
    public init(
        accessToken: String,
        refreshToken: String? = nil,
        expiresIn: Int? = nil,
        tokenURL: URL,
        clientID: String,
        clientSecret: String? = nil
    ) {
        self.accessToken = accessToken
        self.refreshToken = refreshToken
        self.tokenURL = tokenURL
        self.clientID = clientID
        self.clientSecret = clientSecret

        if let expiresIn = expiresIn {
            // Set expiry with 5 minute buffer to avoid edge cases
            self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 300))
        }
    }

    /// Get a valid access token, refreshing if necessary
    ///
    /// - Returns: A valid access token
    /// - Throws: `SwiftXDAVError` if token refresh fails
    public func getValidAccessToken() async throws -> String {
        // Check if current token is still valid
        if let expiresAt = expiresAt, Date() < expiresAt {
            return accessToken
        }

        // Token expired or no expiry info, try to refresh
        guard let refreshToken = refreshToken else {
            throw SwiftXDAVError.authenticationRequired
        }

        try await refreshAccessToken(refreshToken: refreshToken)
        return accessToken
    }

    /// Refresh the access token using the refresh token
    ///
    /// - Parameter refreshToken: The refresh token to use
    /// - Throws: `SwiftXDAVError` if refresh fails
    private func refreshAccessToken(refreshToken: String) async throws {
        var urlComponents = URLComponents(url: tokenURL, resolvingAgainstBaseURL: false)!
        urlComponents.queryItems = [
            URLQueryItem(name: "grant_type", value: "refresh_token"),
            URLQueryItem(name: "refresh_token", value: refreshToken),
            URLQueryItem(name: "client_id", value: clientID)
        ]

        if let clientSecret = clientSecret {
            urlComponents.queryItems?.append(URLQueryItem(name: "client_secret", value: clientSecret))
        }

        var request = URLRequest(url: tokenURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        request.httpBody = urlComponents.query?.data(using: .utf8)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw SwiftXDAVError.networkError(underlying: URLError(.badServerResponse))
        }

        guard httpResponse.statusCode == 200 else {
            let body = String(data: data, encoding: .utf8)
            throw SwiftXDAVError.invalidResponse(statusCode: httpResponse.statusCode, body: body)
        }

        let tokenResponse = try JSONDecoder().decode(TokenResponse.self, from: data)

        // Update stored tokens
        self.accessToken = tokenResponse.accessToken
        if let newRefreshToken = tokenResponse.refreshToken {
            self.refreshToken = newRefreshToken
        }

        // Update expiry time
        if let expiresIn = tokenResponse.expiresIn {
            self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 300))
        }
    }

    /// Manually update the access token
    ///
    /// Useful when obtaining a new token from an external source
    ///
    /// - Parameters:
    ///   - accessToken: New access token
    ///   - refreshToken: New refresh token (optional)
    ///   - expiresIn: Number of seconds until expiry
    public func updateToken(accessToken: String, refreshToken: String? = nil, expiresIn: Int? = nil) {
        self.accessToken = accessToken
        if let refreshToken = refreshToken {
            self.refreshToken = refreshToken
        }
        if let expiresIn = expiresIn {
            self.expiresAt = Date().addingTimeInterval(TimeInterval(expiresIn - 300))
        }
    }
}

/// HTTP client that automatically refreshes OAuth 2.0 tokens
public actor OAuth2HTTPClient: HTTPClient {
    private let baseClient: HTTPClient
    private let tokenManager: OAuth2TokenManager

    /// Initialize OAuth 2.0 authenticated HTTP client
    ///
    /// - Parameters:
    ///   - baseClient: Underlying HTTP client for requests
    ///   - tokenManager: OAuth 2.0 token manager
    public init(baseClient: HTTPClient, tokenManager: OAuth2TokenManager) {
        self.baseClient = baseClient
        self.tokenManager = tokenManager
    }

    public func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        // Get valid access token (refreshes if needed)
        let accessToken = try await tokenManager.getValidAccessToken()

        // Add OAuth bearer token to headers
        var authHeaders = headers ?? [:]
        authHeaders["Authorization"] = "Bearer \(accessToken)"

        return try await baseClient.request(
            method,
            url: url,
            headers: authHeaders,
            body: body
        )
    }
}
