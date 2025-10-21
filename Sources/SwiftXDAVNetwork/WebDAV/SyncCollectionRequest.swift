import Foundation
import SwiftXDAVCore

/// Represents a WebDAV sync-collection REPORT request (RFC 6578)
///
/// The sync-collection REPORT enables efficient synchronization by requesting
/// only changes since a previous sync token. This is much more efficient than
/// re-downloading all resources for large collections.
///
/// ## Usage
///
/// ```swift
/// // Initial sync (no token)
/// let request = SyncCollectionRequest(
///     url: calendarURL,
///     syncToken: nil,
///     properties: [.getETag]
/// )
/// let result = try await request.execute(using: httpClient)
///
/// // Subsequent sync (with token)
/// let deltaRequest = SyncCollectionRequest(
///     url: calendarURL,
///     syncToken: result.newSyncToken,
///     properties: [.getETag]
/// )
/// let deltaResult = try await deltaRequest.execute(using: httpClient)
/// ```
///
/// ## Topics
///
/// ### Creating a Request
/// - ``init(url:syncToken:properties:fetchResourceData:)``
///
/// ### Executing the Request
/// - ``execute(using:)``
/// - ``buildXML()``
public struct SyncCollectionRequest {
    /// The URL of the collection to sync
    public let url: URL

    /// The sync token from the previous sync (nil for initial sync)
    public let syncToken: SyncToken?

    /// Properties to fetch for each resource
    public let properties: [DAVProperty]

    /// Whether to fetch full resource data (calendar-data/address-data)
    public let fetchResourceData: Bool

    /// Initialize a sync-collection request
    ///
    /// - Parameters:
    ///   - url: The URL of the collection to sync
    ///   - syncToken: The sync token from the previous sync (nil for initial sync)
    ///   - properties: Properties to fetch (defaults to getetag)
    ///   - fetchResourceData: Whether to fetch full resource data (default: false)
    public init(
        url: URL,
        syncToken: SyncToken?,
        properties: [DAVProperty] = [DAVPropertyName.getETag],
        fetchResourceData: Bool = false
    ) {
        self.url = url
        self.syncToken = syncToken
        self.properties = properties
        self.fetchResourceData = fetchResourceData
    }

    /// Build the XML request body
    ///
    /// Generates the `<sync-collection>` XML according to RFC 6578.
    ///
    /// - Returns: XML data for the request body
    public func buildXML() -> Data {
        var xml = XMLBuilder()

        xml.startElement("d:sync-collection", attributes: ["xmlns:d": "DAV:"])

        // Sync token element
        // RFC 6578 requires explicit opening/closing tags, not self-closing
        xml.startElement("d:sync-token")
        if let token = syncToken {
            xml.raw(token.value)
        }
        xml.endElement("d:sync-token")

        // Sync level (1 = immediate children only)
        xml.element("d:sync-level", value: "1")

        // Properties to fetch
        xml.startElement("d:prop")
        for property in properties {
            let prefix = property.namespace == "DAV:" ? "d" : "cs"
            xml.element("\(prefix):\(property.name)", value: "")
        }
        xml.endElement("d:prop")

        xml.endElement("d:sync-collection")

        let xmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + xml.build()
        return xmlString.data(using: .utf8) ?? Data()
    }

    /// Execute the sync-collection request
    ///
    /// Sends the REPORT request to the server and parses the response.
    ///
    /// - Parameter client: The HTTP client to use
    /// - Returns: The sync result with changes and new token
    /// - Throws: `SwiftXDAVError` if the request fails
    public func execute(using client: HTTPClient) async throws -> SyncCollectionResponse {
        let body = buildXML()
        let headers = [
            "Content-Type": "application/xml; charset=utf-8",
            "Depth": "0"
        ]

        let response = try await client.request(
            .report,
            url: url,
            headers: headers,
            body: body
        )

        // 207 Multi-Status is the expected response
        guard response.statusCode == 207 else {
            // Handle sync token expiration (410 Gone or 403 Forbidden)
            if response.statusCode == 410 || response.statusCode == 403 {
                throw SwiftXDAVError.syncTokenExpired
            }

            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }

        // Parse the multi-status response
        let parser = SyncCollectionParser()
        return try await parser.parse(response.data)
    }
}

/// Response from a sync-collection REPORT
public struct SyncCollectionResponse: Sendable, Equatable {
    /// The new sync token to use for the next sync
    public let newSyncToken: SyncToken

    /// Resources that were added or modified
    public let changedResources: [SyncResourceInfo]

    /// Resources that were deleted
    public let deletedResources: [URL]

    /// Initialize a sync-collection response
    ///
    /// - Parameters:
    ///   - newSyncToken: The new sync token
    ///   - changedResources: Changed resources
    ///   - deletedResources: Deleted resources
    public init(
        newSyncToken: SyncToken,
        changedResources: [SyncResourceInfo],
        deletedResources: [URL]
    ) {
        self.newSyncToken = newSyncToken
        self.changedResources = changedResources
        self.deletedResources = deletedResources
    }
}

/// Information about a resource in a sync response
public struct SyncResourceInfo: Sendable, Equatable {
    /// The URL of the resource
    public let url: URL

    /// The current ETag of the resource
    public let etag: String?

    /// Properties of the resource
    public let properties: [String: String]

    /// Initialize resource info
    ///
    /// - Parameters:
    ///   - url: The resource URL
    ///   - etag: The resource ETag
    ///   - properties: Additional properties
    public init(url: URL, etag: String?, properties: [String: String] = [:]) {
        self.url = url
        self.etag = etag
        self.properties = properties
    }
}

/// Parser for sync-collection REPORT responses
actor SyncCollectionParser {
    func parse(_ data: Data) throws -> SyncCollectionResponse {
        guard let xmlString = String(data: data, encoding: .utf8) else {
            throw SwiftXDAVError.parsingError("Invalid UTF-8 encoding")
        }

        // Parse sync-token
        guard let syncToken = extractSyncToken(from: xmlString) else {
            throw SwiftXDAVError.parsingError("No sync-token found in response")
        }

        // Parse WebDAV multi-status responses
        let webdavParser = WebDAVXMLParser()
        let responses = try webdavParser.parse(data)

        var changedResources: [SyncResourceInfo] = []
        var deletedResources: [URL] = []

        for response in responses {
            guard let url = URL(string: response.href) else {
                continue
            }

            // Check if this is a deletion
            let isDeletion = response.status?.contains("404") ?? false

            if isDeletion {
                deletedResources.append(url)
            } else {
                let etag = response.property(named: "getetag")
                let properties = response.properties.reduce(into: [String: String]()) { result, prop in
                    if let value = prop.value {
                        result[prop.name] = value
                    }
                }

                let resourceInfo = SyncResourceInfo(
                    url: url,
                    etag: etag,
                    properties: properties
                )
                changedResources.append(resourceInfo)
            }
        }

        return SyncCollectionResponse(
            newSyncToken: SyncToken(syncToken),
            changedResources: changedResources,
            deletedResources: deletedResources
        )
    }

    private func extractSyncToken(from xml: String) -> String? {
        // Simple regex to extract sync-token value
        // Format: <d:sync-token>VALUE</d:sync-token> or <sync-token>VALUE</sync-token>
        let patterns = [
            "<d:sync-token>(.+?)</d:sync-token>",
            "<sync-token>(.+?)</sync-token>",
            "<D:sync-token>(.+?)</D:sync-token>"
        ]

        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []),
               let match = regex.firstMatch(in: xml, options: [], range: NSRange(xml.startIndex..., in: xml)),
               let range = Range(match.range(at: 1), in: xml) {
                return String(xml[range])
            }
        }

        return nil
    }
}
