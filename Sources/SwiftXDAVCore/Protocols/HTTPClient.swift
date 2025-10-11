import Foundation

/// HTTP request method
///
/// Includes standard HTTP methods and WebDAV/CalDAV/CardDAV extension methods.
///
/// ## Topics
///
/// ### Standard HTTP Methods
/// - ``get``
/// - ``post``
/// - ``put``
/// - ``delete``
/// - ``options``
///
/// ### WebDAV Methods
/// - ``propfind``
/// - ``proppatch``
/// - ``mkcol``
/// - ``copy``
/// - ``move``
/// - ``lock``
/// - ``unlock``
///
/// ### CalDAV/CardDAV Methods
/// - ``report``
public enum HTTPMethod: String, Sendable, Equatable {
    /// GET - Retrieve a resource
    case get = "GET"

    /// POST - Submit data to create or update a resource
    case post = "POST"

    /// PUT - Create or replace a resource
    case put = "PUT"

    /// DELETE - Remove a resource
    case delete = "DELETE"

    /// OPTIONS - Query server capabilities
    case options = "OPTIONS"

    /// PROPFIND - Retrieve properties of a resource (WebDAV)
    case propfind = "PROPFIND"

    /// PROPPATCH - Modify properties of a resource (WebDAV)
    case proppatch = "PROPPATCH"

    /// MKCOL - Create a collection (WebDAV)
    case mkcol = "MKCOL"

    /// COPY - Copy a resource (WebDAV)
    case copy = "COPY"

    /// MOVE - Move a resource (WebDAV)
    case move = "MOVE"

    /// LOCK - Lock a resource (WebDAV)
    case lock = "LOCK"

    /// UNLOCK - Unlock a resource (WebDAV)
    case unlock = "UNLOCK"

    /// REPORT - Query structured data (CalDAV/CardDAV)
    case report = "REPORT"
}

/// HTTP response
///
/// Represents the response from an HTTP request, including status code,
/// headers, and response body data.
public struct HTTPResponse: Sendable, Equatable {
    /// The HTTP status code
    public let statusCode: Int

    /// The HTTP response headers
    public let headers: [String: String]

    /// The response body data
    public let data: Data

    /// Creates a new HTTP response
    ///
    /// - Parameters:
    ///   - statusCode: The HTTP status code
    ///   - headers: The HTTP response headers
    ///   - data: The response body data
    public init(statusCode: Int, headers: [String: String], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }

    /// Returns the response body as a UTF-8 string
    ///
    /// - Returns: The response body as a string, or `nil` if it cannot be decoded as UTF-8
    public var bodyString: String? {
        String(data: data, encoding: .utf8)
    }

    /// Checks if the response indicates success
    ///
    /// A response is considered successful if the status code is in the 2xx range.
    public var isSuccess: Bool {
        (200..<300).contains(statusCode)
    }

    /// Checks if the response is a multi-status response
    ///
    /// WebDAV multi-status responses use status code 207.
    public var isMultiStatus: Bool {
        statusCode == 207
    }
}

/// Protocol for HTTP client implementations
///
/// Implementations of this protocol handle the actual HTTP communication
/// with servers, including authentication, header management, and error handling.
///
/// ## Topics
///
/// ### Making Requests
/// - ``request(_:url:headers:body:)``
///
/// ## Example
///
/// ```swift
/// let client = AlamofireHTTPClient()
/// let response = try await client.request(
///     .get,
///     url: URL(string: "https://example.com/calendar")!,
///     headers: ["Accept": "text/calendar"],
///     body: nil
/// )
/// print("Status: \(response.statusCode)")
/// ```
public protocol HTTPClient: Sendable {
    /// Execute an HTTP request
    ///
    /// - Parameters:
    ///   - method: The HTTP method to use
    ///   - url: The URL to request
    ///   - headers: Optional HTTP headers to include in the request
    ///   - body: Optional request body data
    /// - Returns: The HTTP response
    /// - Throws: ``SwiftXDAVError`` if the request fails
    func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse
}
