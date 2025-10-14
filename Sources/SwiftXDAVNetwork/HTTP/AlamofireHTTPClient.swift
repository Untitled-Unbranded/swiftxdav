import Foundation
import Alamofire
import SwiftXDAVCore

/// HTTP client implementation using Alamofire
///
/// `AlamofireHTTPClient` wraps Alamofire's networking capabilities in an actor-based
/// implementation that provides async/await support and thread-safe access.
///
/// ## Usage
///
/// ```swift
/// let client = AlamofireHTTPClient()
/// let response = try await client.request(
///     .get,
///     url: URL(string: "https://example.com")!,
///     headers: nil,
///     body: nil
/// )
/// ```
///
/// ## Thread Safety
///
/// This actor ensures thread-safe access to the underlying Alamofire session.
public actor AlamofireHTTPClient: HTTPClient {
    private let session: Session

    /// Initialize with a custom URLSessionConfiguration
    ///
    /// - Parameter configuration: The URLSession configuration to use. Defaults to `.default`
    public init(configuration: URLSessionConfiguration = .default) {
        self.session = Session(configuration: configuration)
    }

    /// Execute an HTTP request
    ///
    /// - Parameters:
    ///   - method: The HTTP method to use
    ///   - url: The URL to request
    ///   - headers: Optional HTTP headers
    ///   - body: Optional request body data
    /// - Returns: The HTTP response
    /// - Throws: `SwiftXDAVError.networkError` if the request fails
    public func request(
        _ method: SwiftXDAVCore.HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        // Convert headers to Alamofire format
        let httpHeaders: HTTPHeaders
        if let headers = headers {
            httpHeaders = HTTPHeaders(headers.map { HTTPHeader(name: $0.key, value: $0.value) })
        } else {
            httpHeaders = HTTPHeaders()
        }

        // Create the request
        let dataRequest: DataRequest
        if let body = body {
            // For requests with body, use custom encoding
            dataRequest = session.request(
                url,
                method: Alamofire.HTTPMethod(rawValue: method.rawValue),
                encoding: RawDataEncoding(data: body),
                headers: httpHeaders
            )
        } else {
            // For requests without body
            dataRequest = session.request(
                url,
                method: Alamofire.HTTPMethod(rawValue: method.rawValue),
                headers: httpHeaders
            )
        }

        // Execute request and await response
        let response = await dataRequest.serializingData().response

        // Check for HTTP response
        guard let httpResponse = response.response else {
            if let error = response.error {
                throw SwiftXDAVError.networkError(underlying: error)
            } else {
                throw SwiftXDAVError.networkError(underlying: URLError(.badServerResponse))
            }
        }

        // Extract response headers
        let responseHeaders = Dictionary(
            uniqueKeysWithValues: httpResponse.headers.map { ($0.name, $0.value) }
        )

        // Get response data (empty if none)
        let responseData = response.data ?? Data()

        // Check for Alamofire errors (network issues, etc.)
        if let error = response.error {
            // Only throw if it's not a successful HTTP status code error
            // (we want to return responses even for 4xx/5xx status codes)
            if httpResponse.statusCode >= 600 {
                throw SwiftXDAVError.networkError(underlying: error)
            }
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            data: responseData
        )
    }
}

// MARK: - Helper Types

/// Custom parameter encoding for raw data
///
/// This encoding simply sets the request body to the provided data without any transformation.
private struct RawDataEncoding: ParameterEncoding {
    let data: Data

    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = data
        return request
    }
}
