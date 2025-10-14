import Foundation
import SwiftXDAVCore

/// WebDAV operations for resource management
///
/// `WebDAVOperations` provides methods for creating, updating, deleting,
/// copying, and moving resources on a WebDAV server.
///
/// ## Usage
///
/// ```swift
/// let operations = WebDAVOperations(client: httpClient)
///
/// // Create a collection
/// try await operations.mkcol(at: URL(string: "https://example.com/calendar/")!)
///
/// // Upload a resource
/// let data = "...".data(using: .utf8)!
/// let etag = try await operations.put(data, at: resourceURL, contentType: "text/calendar")
///
/// // Delete a resource
/// try await operations.delete(at: resourceURL)
/// ```
///
/// ## Topics
///
/// ### Creating Operations
/// - ``init(client:)``
///
/// ### Collection Operations
/// - ``mkcol(at:)``
///
/// ### Resource Operations
/// - ``put(_:at:contentType:ifMatch:ifNoneMatch:)``
/// - ``get(from:)``
/// - ``delete(at:ifMatch:)``
///
/// ### Moving and Copying
/// - ``copy(from:to:overwrite:)``
/// - ``move(from:to:overwrite:)``
public struct WebDAVOperations {
    private let client: HTTPClient

    /// Initialize with an HTTP client
    ///
    /// - Parameter client: The HTTP client to use for requests
    public init(client: HTTPClient) {
        self.client = client
    }

    // MARK: - Collection Operations

    /// Create a collection (directory)
    ///
    /// Creates a new collection resource at the specified URL.
    ///
    /// - Parameter url: The URL of the collection to create
    /// - Throws: `SwiftXDAVError.invalidResponse` if the status is not 201
    ///
    /// ## HTTP Status Codes
    ///
    /// - **201 Created**: Collection created successfully
    /// - **405 Method Not Allowed**: Collection already exists
    /// - **409 Conflict**: Parent collection doesn't exist
    /// - **507 Insufficient Storage**: Quota exceeded
    public func mkcol(at url: URL) async throws {
        let response = try await client.request(
            .mkcol,
            url: url,
            headers: nil,
            body: nil
        )

        guard response.statusCode == 201 else {
            let bodyString = String(data: response.data, encoding: .utf8)
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: bodyString
            )
        }
    }

    // MARK: - Resource Operations

    /// Upload or update a resource
    ///
    /// Creates a new resource or updates an existing one.
    ///
    /// - Parameters:
    ///   - data: The resource data to upload
    ///   - url: The URL where the resource should be stored
    ///   - contentType: The MIME type of the resource
    ///   - ifMatch: Optional ETag for conditional updates (prevents lost updates)
    ///   - ifNoneMatch: Set to "*" to prevent overwriting an existing resource
    /// - Returns: The ETag of the created/updated resource, if provided by the server
    /// - Throws: `SwiftXDAVError.invalidResponse` if the operation fails
    ///
    /// ## HTTP Status Codes
    ///
    /// - **200 OK**: Resource updated successfully
    /// - **201 Created**: Resource created successfully
    /// - **204 No Content**: Resource updated successfully (no response body)
    /// - **412 Precondition Failed**: If-Match ETag doesn't match current resource
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Create new resource
    /// let etag = try await operations.put(
    ///     calendarData,
    ///     at: eventURL,
    ///     contentType: "text/calendar; charset=utf-8"
    /// )
    ///
    /// // Update with optimistic locking
    /// try await operations.put(
    ///     updatedData,
    ///     at: eventURL,
    ///     contentType: "text/calendar; charset=utf-8",
    ///     ifMatch: etag
    /// )
    /// ```
    public func put(
        _ data: Data,
        at url: URL,
        contentType: String,
        ifMatch etag: String? = nil,
        ifNoneMatch: String? = nil
    ) async throws -> String? {
        var headers = ["Content-Type": contentType]

        if let etag = etag {
            headers["If-Match"] = etag
        }

        if let ifNoneMatch = ifNoneMatch {
            headers["If-None-Match"] = ifNoneMatch
        }

        let response = try await client.request(
            .put,
            url: url,
            headers: headers,
            body: data
        )

        // Accept 200, 201, or 204 as success
        guard [200, 201, 204].contains(response.statusCode) else {
            let bodyString = String(data: response.data, encoding: .utf8)

            // Special handling for precondition failures
            if response.statusCode == 412 {
                throw SwiftXDAVError.preconditionFailed(etag: etag)
            }

            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: bodyString
            )
        }

        // Return the ETag if provided
        return response.headers["ETag"] ?? response.headers["etag"]
    }

    /// Download a resource
    ///
    /// Retrieves the content of a resource.
    ///
    /// - Parameter url: The URL of the resource to download
    /// - Returns: The resource data and optional ETag
    /// - Throws: `SwiftXDAVError.invalidResponse` if the resource doesn't exist
    ///
    /// ## Example
    ///
    /// ```swift
    /// let (data, etag) = try await operations.get(from: eventURL)
    /// let calendar = try parseICalendar(data)
    /// ```
    public func get(from url: URL) async throws -> (data: Data, etag: String?) {
        let response = try await client.request(
            .get,
            url: url,
            headers: nil,
            body: nil
        )

        guard response.statusCode == 200 else {
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }

        let etag = response.headers["ETag"] ?? response.headers["etag"]
        return (response.data, etag)
    }

    /// Delete a resource
    ///
    /// Removes a resource or collection from the server.
    ///
    /// - Parameters:
    ///   - url: The URL of the resource to delete
    ///   - ifMatch: Optional ETag for conditional deletion
    /// - Throws: `SwiftXDAVError.invalidResponse` if the operation fails
    ///
    /// ## HTTP Status Codes
    ///
    /// - **200 OK**: Resource deleted (with response body)
    /// - **204 No Content**: Resource deleted (no response body)
    /// - **404 Not Found**: Resource doesn't exist
    /// - **412 Precondition Failed**: If-Match ETag doesn't match
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Simple deletion
    /// try await operations.delete(at: eventURL)
    ///
    /// // Conditional deletion (prevents race conditions)
    /// try await operations.delete(at: eventURL, ifMatch: currentETag)
    /// ```
    public func delete(at url: URL, ifMatch etag: String? = nil) async throws {
        var headers: [String: String]? = nil

        if let etag = etag {
            headers = ["If-Match": etag]
        }

        let response = try await client.request(
            .delete,
            url: url,
            headers: headers,
            body: nil
        )

        guard [200, 204, 404].contains(response.statusCode) else {
            // Special handling for precondition failures
            if response.statusCode == 412 {
                throw SwiftXDAVError.preconditionFailed(etag: etag)
            }

            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }
    }

    // MARK: - Copy and Move Operations

    /// Copy a resource or collection
    ///
    /// Creates a duplicate of a resource at a new location.
    ///
    /// - Parameters:
    ///   - source: The URL of the resource to copy
    ///   - destination: The URL where the copy should be created
    ///   - overwrite: Whether to overwrite an existing resource at the destination
    /// - Throws: `SwiftXDAVError.invalidResponse` if the operation fails
    ///
    /// ## HTTP Status Codes
    ///
    /// - **201 Created**: Resource copied successfully
    /// - **204 No Content**: Resource copied, overwriting existing resource
    /// - **412 Precondition Failed**: Destination exists and overwrite is false
    public func copy(from source: URL, to destination: URL, overwrite: Bool = false) async throws {
        let headers = [
            "Destination": destination.absoluteString,
            "Overwrite": overwrite ? "T" : "F"
        ]

        let response = try await client.request(
            .copy,
            url: source,
            headers: headers,
            body: nil
        )

        guard [201, 204].contains(response.statusCode) else {
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }
    }

    /// Move a resource or collection
    ///
    /// Moves a resource to a new location (rename or relocate).
    ///
    /// - Parameters:
    ///   - source: The URL of the resource to move
    ///   - destination: The new URL for the resource
    ///   - overwrite: Whether to overwrite an existing resource at the destination
    /// - Throws: `SwiftXDAVError.invalidResponse` if the operation fails
    ///
    /// ## HTTP Status Codes
    ///
    /// - **201 Created**: Resource moved successfully
    /// - **204 No Content**: Resource moved, overwriting existing resource
    /// - **412 Precondition Failed**: Destination exists and overwrite is false
    ///
    /// ## Example
    ///
    /// ```swift
    /// // Rename a calendar
    /// try await operations.move(
    ///     from: URL(string: "https://example.com/old-calendar/")!,
    ///     to: URL(string: "https://example.com/new-calendar/")!
    /// )
    /// ```
    public func move(from source: URL, to destination: URL, overwrite: Bool = false) async throws {
        let headers = [
            "Destination": destination.absoluteString,
            "Overwrite": overwrite ? "T" : "F"
        ]

        let response = try await client.request(
            .move,
            url: source,
            headers: headers,
            body: nil
        )

        guard [201, 204].contains(response.statusCode) else {
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }
    }
}
