import Foundation

/// Root error type for all SwiftXDAV errors
///
/// This error type provides comprehensive error handling for all operations
/// in the SwiftXDAV framework, including network errors, parsing errors,
/// HTTP status code errors, and protocol-specific errors.
///
/// ## Topics
///
/// ### Network Errors
/// - ``networkError(underlying:)``
/// - ``invalidResponse(statusCode:body:)``
///
/// ### Authentication Errors
/// - ``authenticationRequired``
/// - ``unauthorized``
/// - ``forbidden``
///
/// ### Resource Errors
/// - ``notFound``
/// - ``conflict(_:)``
/// - ``preconditionFailed(etag:)``
///
/// ### Data Errors
/// - ``parsingError(_:)``
/// - ``invalidData(_:)``
///
/// ### Server Errors
/// - ``serverError(statusCode:message:)``
/// - ``unsupportedOperation(_:)``
public enum SwiftXDAVError: Error, LocalizedError, Sendable {
    /// A network error occurred
    ///
    /// - Parameter underlying: The underlying error that caused the network failure
    case networkError(underlying: Error)

    /// The server returned an invalid or unexpected response
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code received
    ///   - body: The response body, if available
    case invalidResponse(statusCode: Int, body: String?)

    /// Failed to parse data
    ///
    /// - Parameter message: A description of what failed to parse
    case parsingError(String)

    /// Authentication is required to access this resource
    case authenticationRequired

    /// The provided credentials are invalid or expired
    case unauthorized

    /// Access to the resource is forbidden
    case forbidden

    /// The requested resource was not found
    case notFound

    /// A conflict occurred (e.g., resource already exists)
    ///
    /// - Parameter message: Details about the conflict
    case conflict(String)

    /// A precondition failed (e.g., ETag mismatch)
    ///
    /// - Parameter etag: The ETag that failed to match, if available
    case preconditionFailed(etag: String?)

    /// A server error occurred
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code (5xx)
    ///   - message: Error message from the server, if available
    case serverError(statusCode: Int, message: String?)

    /// The requested operation is not supported
    ///
    /// - Parameter message: Details about what operation is unsupported
    case unsupportedOperation(String)

    /// The provided data is invalid
    ///
    /// - Parameter message: Details about what data is invalid
    case invalidData(String)

    /// The sync token has expired or is invalid
    ///
    /// This error is returned when the server no longer recognizes a sync token.
    /// The client must perform a full sync (initial sync with no token) to recover.
    case syncTokenExpired

    /// A human-readable description of the error
    public var errorDescription: String? {
        switch self {
        case .networkError(let underlying):
            return "Network error: \(underlying.localizedDescription)"
        case .invalidResponse(let statusCode, _):
            return "Invalid response with status code: \(statusCode)"
        case .parsingError(let message):
            return "Parsing error: \(message)"
        case .authenticationRequired:
            return "Authentication is required"
        case .unauthorized:
            return "Unauthorized access"
        case .forbidden:
            return "Access forbidden"
        case .notFound:
            return "Resource not found"
        case .conflict(let message):
            return "Conflict: \(message)"
        case .preconditionFailed(let etag):
            return "Precondition failed" + (etag.map { " (etag: \($0))" } ?? "")
        case .serverError(let statusCode, let message):
            return "Server error (\(statusCode))" + (message.map { ": \($0)" } ?? "")
        case .unsupportedOperation(let message):
            return "Unsupported operation: \(message)"
        case .invalidData(let message):
            return "Invalid data: \(message)"
        case .syncTokenExpired:
            return "Sync token has expired"
        }
    }

    /// Additional information about the error for debugging
    public var failureReason: String? {
        switch self {
        case .networkError:
            return "The network request failed to complete"
        case .invalidResponse(_, let body):
            return body
        case .parsingError:
            return "The data could not be parsed into the expected format"
        case .authenticationRequired:
            return "This resource requires authentication"
        case .unauthorized:
            return "The credentials provided are invalid or expired"
        case .forbidden:
            return "You do not have permission to access this resource"
        case .notFound:
            return "The requested resource does not exist on the server"
        case .conflict:
            return "The operation conflicts with the current state of the resource"
        case .preconditionFailed:
            return "The resource has been modified since it was last retrieved"
        case .serverError:
            return "The server encountered an error processing the request"
        case .unsupportedOperation:
            return "This operation is not supported by the server"
        case .invalidData:
            return "The data provided does not meet the required format"
        case .syncTokenExpired:
            return "The sync token is no longer valid. A full sync is required."
        }
    }
}

// MARK: - Equatable Conformance

extension SwiftXDAVError: Equatable {
    public static func == (lhs: SwiftXDAVError, rhs: SwiftXDAVError) -> Bool {
        switch (lhs, rhs) {
        case (.networkError, .networkError):
            // Cannot compare underlying errors, so treat all network errors as equal
            return true
        case (.invalidResponse(let lhsCode, let lhsBody), .invalidResponse(let rhsCode, let rhsBody)):
            return lhsCode == rhsCode && lhsBody == rhsBody
        case (.parsingError(let lhsMsg), .parsingError(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.authenticationRequired, .authenticationRequired):
            return true
        case (.unauthorized, .unauthorized):
            return true
        case (.forbidden, .forbidden):
            return true
        case (.notFound, .notFound):
            return true
        case (.conflict(let lhsMsg), .conflict(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.preconditionFailed(let lhsEtag), .preconditionFailed(let rhsEtag)):
            return lhsEtag == rhsEtag
        case (.serverError(let lhsCode, let lhsMsg), .serverError(let rhsCode, let rhsMsg)):
            return lhsCode == rhsCode && lhsMsg == rhsMsg
        case (.unsupportedOperation(let lhsMsg), .unsupportedOperation(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.invalidData(let lhsMsg), .invalidData(let rhsMsg)):
            return lhsMsg == rhsMsg
        case (.syncTokenExpired, .syncTokenExpired):
            return true
        default:
            return false
        }
    }
}
