import Foundation

/// Authentication methods for HTTP requests
///
/// SwiftXDAV supports multiple authentication mechanisms for interacting with
/// CalDAV/CardDAV servers.
///
/// ## Supported Methods
///
/// - **None**: No authentication
/// - **Basic**: HTTP Basic Authentication (RFC 7617)
/// - **Bearer**: Bearer token authentication
/// - **OAuth 2.0**: OAuth 2.0 access token authentication
///
/// ## Usage
///
/// ### Basic Authentication (iCloud, self-hosted servers)
///
/// ```swift
/// let auth = Authentication.basic(
///     username: "user@icloud.com",
///     password: "abcd-efgh-ijkl-mnop"
/// )
/// ```
///
/// ### Bearer Token
///
/// ```swift
/// let auth = Authentication.bearer(token: "your-access-token")
/// ```
///
/// ### OAuth 2.0 (Google Calendar/Contacts)
///
/// ```swift
/// let auth = Authentication.oauth2(
///     accessToken: "ya29.a0...",
///     refreshToken: "1//0g...",
///     tokenURL: URL(string: "https://oauth2.googleapis.com/token")!
/// )
/// ```
///
/// ## Topics
///
/// ### Authentication Cases
/// - ``none``
/// - ``basic(username:password:)``
/// - ``bearer(token:)``
/// - ``oauth2(accessToken:refreshToken:tokenURL:)``
///
/// ### Applying Authentication
/// - ``apply(to:)``
public enum Authentication: Sendable, Equatable {
    /// No authentication
    case none

    /// HTTP Basic Authentication
    ///
    /// Uses Base64 encoding of "username:password" with "Basic" scheme.
    ///
    /// - Parameters:
    ///   - username: The username
    ///   - password: The password (for iCloud, use app-specific password)
    case basic(username: String, password: String)

    /// Bearer token authentication
    ///
    /// Typically used for API tokens or OAuth 2.0 access tokens.
    ///
    /// - Parameter token: The bearer token
    case bearer(token: String)

    /// OAuth 2.0 authentication
    ///
    /// Provides access token with optional refresh capability.
    ///
    /// - Parameters:
    ///   - accessToken: The OAuth 2.0 access token
    ///   - refreshToken: Optional refresh token for obtaining new access tokens
    ///   - tokenURL: Optional URL for token refresh endpoint
    case oauth2(accessToken: String, refreshToken: String?, tokenURL: URL?)

    /// Apply authentication to request headers
    ///
    /// Modifies the provided headers dictionary to include the appropriate
    /// authentication header.
    ///
    /// - Parameter headers: The headers dictionary to modify
    ///
    /// ## Implementation Notes
    ///
    /// - Basic: Adds `Authorization: Basic <base64>` header
    /// - Bearer: Adds `Authorization: Bearer <token>` header
    /// - OAuth 2.0: Adds `Authorization: Bearer <accessToken>` header
    /// - None: No modifications
    public func apply(to headers: inout [String: String]) {
        switch self {
        case .none:
            // No authentication headers to add
            break

        case .basic(let username, let password):
            // Create Basic authentication header
            // Format: "Basic <base64(username:password)>"
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                headers["Authorization"] = "Basic \(base64)"
            }

        case .bearer(let token):
            // Create Bearer token header
            // Format: "Bearer <token>"
            headers["Authorization"] = "Bearer \(token)"

        case .oauth2(let accessToken, _, _):
            // OAuth 2.0 uses Bearer token format with access token
            // Format: "Bearer <accessToken>"
            // Note: Refresh logic should be handled at a higher level
            headers["Authorization"] = "Bearer \(accessToken)"
        }
    }
}

// MARK: - CustomStringConvertible

extension Authentication: CustomStringConvertible {
    /// A textual representation of the authentication method
    ///
    /// This representation is safe for logging and doesn't expose credentials.
    public var description: String {
        switch self {
        case .none:
            return "Authentication.none"
        case .basic(let username, _):
            return "Authentication.basic(username: \(username), password: ***)"
        case .bearer:
            return "Authentication.bearer(token: ***)"
        case .oauth2:
            return "Authentication.oauth2(accessToken: ***, refreshToken: ***, tokenURL: ***)"
        }
    }
}

// MARK: - Convenience Constructors

extension Authentication {
    /// Create Basic authentication for iCloud
    ///
    /// iCloud requires an app-specific password, not your regular Apple ID password.
    /// Generate one at appleid.apple.com.
    ///
    /// - Parameters:
    ///   - username: Your iCloud email (e.g., "user@icloud.com")
    ///   - appSpecificPassword: The app-specific password (format: "abcd-efgh-ijkl-mnop")
    /// - Returns: A Basic authentication instance
    public static func iCloud(username: String, appSpecificPassword: String) -> Authentication {
        .basic(username: username, password: appSpecificPassword)
    }

    /// Create OAuth 2.0 authentication for Google
    ///
    /// - Parameters:
    ///   - accessToken: The OAuth 2.0 access token
    ///   - refreshToken: Optional refresh token
    /// - Returns: An OAuth 2.0 authentication instance configured for Google
    public static func google(accessToken: String, refreshToken: String? = nil) -> Authentication {
        .oauth2(
            accessToken: accessToken,
            refreshToken: refreshToken,
            tokenURL: URL(string: "https://oauth2.googleapis.com/token")
        )
    }
}
