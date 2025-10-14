import Foundation
import SwiftXDAVCore

/// HTTP client that automatically applies authentication to all requests
///
/// `AuthenticatedHTTPClient` is a decorator that wraps another `HTTPClient`
/// and automatically applies the specified authentication to each request.
///
/// ## Usage
///
/// ```swift
/// let baseClient = AlamofireHTTPClient()
/// let auth = Authentication.basic(username: "user", password: "pass")
/// let authenticatedClient = AuthenticatedHTTPClient(
///     baseClient: baseClient,
///     authentication: auth
/// )
///
/// // All requests will automatically include authentication headers
/// let response = try await authenticatedClient.request(
///     .get,
///     url: URL(string: "https://example.com")!,
///     headers: nil,
///     body: nil
/// )
/// ```
///
/// ## Design Pattern
///
/// This implements the Decorator pattern, allowing authentication to be
/// layered onto any `HTTPClient` implementation.
///
/// ## Topics
///
/// ### Creating a Client
/// - ``init(baseClient:authentication:)``
///
/// ### Making Requests
/// - ``request(_:url:headers:body:)``
public actor AuthenticatedHTTPClient: HTTPClient {
    private let baseClient: HTTPClient
    private let authentication: Authentication

    /// Initialize with a base client and authentication
    ///
    /// - Parameters:
    ///   - baseClient: The underlying HTTP client to use
    ///   - authentication: The authentication method to apply
    public init(baseClient: HTTPClient, authentication: Authentication) {
        self.baseClient = baseClient
        self.authentication = authentication
    }

    /// Execute an HTTP request with authentication
    ///
    /// This method merges the provided headers with authentication headers
    /// and forwards the request to the base client.
    ///
    /// - Parameters:
    ///   - method: The HTTP method to use
    ///   - url: The URL to request
    ///   - headers: Optional HTTP headers (will be merged with auth headers)
    ///   - body: Optional request body data
    /// - Returns: The HTTP response
    /// - Throws: `SwiftXDAVError` if the request fails
    ///
    /// ## Note
    ///
    /// If the provided headers already contain an "Authorization" header,
    /// it will be overwritten by the authentication credentials.
    public func request(
        _ method: SwiftXDAVCore.HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        // Start with provided headers or empty dictionary
        var authHeaders = headers ?? [:]

        // Apply authentication (this will add/overwrite Authorization header)
        authentication.apply(to: &authHeaders)

        // Forward to base client with authenticated headers
        return try await baseClient.request(
            method,
            url: url,
            headers: authHeaders,
            body: body
        )
    }
}

// MARK: - Convenience Constructors

extension AuthenticatedHTTPClient {
    /// Create an authenticated client for iCloud
    ///
    /// - Parameters:
    ///   - username: iCloud email address
    ///   - appSpecificPassword: iCloud app-specific password
    ///   - configuration: Optional URLSession configuration
    /// - Returns: An authenticated HTTP client configured for iCloud
    public static func iCloud(
        username: String,
        appSpecificPassword: String,
        configuration: URLSessionConfiguration = .default
    ) -> AuthenticatedHTTPClient {
        let baseClient = AlamofireHTTPClient(configuration: configuration)
        let auth = Authentication.iCloud(username: username, appSpecificPassword: appSpecificPassword)
        return AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)
    }

    /// Create an authenticated client for Google
    ///
    /// - Parameters:
    ///   - accessToken: Google OAuth 2.0 access token
    ///   - refreshToken: Optional refresh token
    ///   - configuration: Optional URLSession configuration
    /// - Returns: An authenticated HTTP client configured for Google
    public static func google(
        accessToken: String,
        refreshToken: String? = nil,
        configuration: URLSessionConfiguration = .default
    ) -> AuthenticatedHTTPClient {
        let baseClient = AlamofireHTTPClient(configuration: configuration)
        let auth = Authentication.google(accessToken: accessToken, refreshToken: refreshToken)
        return AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)
    }

    /// Create an authenticated client with basic authentication
    ///
    /// - Parameters:
    ///   - username: The username
    ///   - password: The password
    ///   - configuration: Optional URLSession configuration
    /// - Returns: An authenticated HTTP client with basic auth
    public static func basicAuth(
        username: String,
        password: String,
        configuration: URLSessionConfiguration = .default
    ) -> AuthenticatedHTTPClient {
        let baseClient = AlamofireHTTPClient(configuration: configuration)
        let auth = Authentication.basic(username: username, password: password)
        return AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)
    }

    /// Create an authenticated client with bearer token
    ///
    /// - Parameters:
    ///   - token: The bearer token
    ///   - configuration: Optional URLSession configuration
    /// - Returns: An authenticated HTTP client with bearer token auth
    public static func bearerToken(
        _ token: String,
        configuration: URLSessionConfiguration = .default
    ) -> AuthenticatedHTTPClient {
        let baseClient = AlamofireHTTPClient(configuration: configuration)
        let auth = Authentication.bearer(token: token)
        return AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)
    }
}
