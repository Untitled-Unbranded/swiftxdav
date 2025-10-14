import Foundation
import SwiftXDAVCore

/// PROPFIND request builder and executor
///
/// `PropfindRequest` creates and executes WebDAV PROPFIND requests to discover
/// properties of resources on a WebDAV server.
///
/// ## Usage
///
/// ### Request All Properties
///
/// ```swift
/// let request = PropfindRequest(
///     url: serverURL,
///     depth: 1,
///     properties: [
///         DAVPropertyName.displayName,
///         DAVPropertyName.resourceType,
///         DAVPropertyName.getETag
///     ]
/// )
///
/// let responses = try await request.execute(using: httpClient)
/// ```
///
/// ### Depth Levels
///
/// - **0**: Properties of the resource itself only
/// - **1**: Properties of the resource and its immediate children
/// - **infinity**: Properties of the resource and all descendants (often disabled by servers)
///
/// ## Topics
///
/// ### Creating Requests
/// - ``init(url:depth:properties:)``
///
/// ### Executing Requests
/// - ``execute(using:)``
/// - ``buildXML()``
public struct PropfindRequest {
    /// The URL to query
    public let url: URL

    /// The depth of the request (0, 1, or infinity)
    public let depth: Int

    /// The properties to request
    public let properties: [DAVProperty]

    /// Initialize a PROPFIND request
    ///
    /// - Parameters:
    ///   - url: The URL of the resource to query
    ///   - depth: The depth level (0 = resource only, 1 = resource + children)
    ///   - properties: The properties to request
    public init(url: URL, depth: Int = 0, properties: [DAVProperty]) {
        self.url = url
        self.depth = depth
        self.properties = properties
    }

    /// Build the XML request body
    ///
    /// Creates a WebDAV PROPFIND XML document requesting the specified properties.
    ///
    /// - Returns: The XML data for the request body
    ///
    /// ## Example Output
    ///
    /// ```xml
    /// <?xml version="1.0" encoding="UTF-8"?>
    /// <d:propfind xmlns:d="DAV:">
    ///   <d:prop>
    ///     <d:displayname/>
    ///     <d:resourcetype/>
    ///     <d:getetag/>
    ///   </d:prop>
    /// </d:propfind>
    /// ```
    public func buildXML() -> Data {
        var xml = XMLBuilder()

        xml.startElement("d:propfind", attributes: ["xmlns:d": "DAV:"])
        xml.startElement("d:prop")

        for property in properties {
            // Handle namespace prefixes
            let prefix: String
            if property.namespace == "DAV:" {
                prefix = "d"
            } else if property.namespace.contains("caldav") {
                prefix = "c"
            } else if property.namespace.contains("carddav") {
                prefix = "card"
            } else if property.namespace.contains("calendarserver") || property.namespace.contains("apple") {
                prefix = "cs"
            } else {
                prefix = "d"
            }

            // Add the property element (empty/self-closing)
            xml.element("\(prefix):\(property.name)")
        }

        xml.endElement("d:prop")
        xml.endElement("d:propfind")

        return xml.buildData()
    }

    /// Execute the PROPFIND request
    ///
    /// Sends the PROPFIND request to the server and parses the multi-status response.
    ///
    /// - Parameter client: The HTTP client to use for the request
    /// - Returns: An array of PROPFIND responses, one for each resource found
    /// - Throws: `SwiftXDAVError` if the request fails or parsing fails
    ///
    /// ## Error Handling
    ///
    /// - Throws `.invalidResponse` if the status code is not 207 (Multi-Status)
    /// - Throws `.parsingError` if the XML response is malformed
    /// - Throws `.networkError` if the HTTP request fails
    public func execute(using client: HTTPClient) async throws -> [PropfindResponse] {
        let body = buildXML()

        // Build headers with proper depth
        let depthString = depth == Int.max ? "infinity" : "\(depth)"
        let headers = [
            "Depth": depthString,
            "Content-Type": "application/xml; charset=utf-8"
        ]

        // Execute the PROPFIND request
        let response = try await client.request(
            .propfind,
            url: url,
            headers: headers,
            body: body
        )

        // WebDAV PROPFIND must return 207 Multi-Status
        guard response.statusCode == 207 else {
            let bodyString = String(data: response.data, encoding: .utf8)
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: bodyString
            )
        }

        // Parse the multi-status XML response
        let parser = WebDAVXMLParser()
        return try parser.parse(response.data)
    }
}

// MARK: - Convenience Constructors

extension PropfindRequest {
    /// Create a PROPFIND request for all properties
    ///
    /// Requests all standard WebDAV properties.
    ///
    /// - Parameters:
    ///   - url: The URL to query
    ///   - depth: The depth level
    /// - Returns: A PROPFIND request
    public static func allProperties(url: URL, depth: Int = 0) -> PropfindRequest {
        PropfindRequest(
            url: url,
            depth: depth,
            properties: [
                DAVPropertyName.displayName,
                DAVPropertyName.resourceType,
                DAVPropertyName.getETag,
                DAVPropertyName.getContentType,
                DAVPropertyName.getLastModified,
                DAVPropertyName.creationDate,
                DAVPropertyName.getContentLength
            ]
        )
    }

    /// Create a PROPFIND request for calendar properties
    ///
    /// Requests properties relevant to CalDAV calendars.
    ///
    /// - Parameters:
    ///   - url: The URL to query
    ///   - depth: The depth level
    /// - Returns: A PROPFIND request
    public static func calendarProperties(url: URL, depth: Int = 1) -> PropfindRequest {
        PropfindRequest(
            url: url,
            depth: depth,
            properties: [
                DAVPropertyName.displayName,
                DAVPropertyName.resourceType,
                DAVPropertyName.getETag,
                CalDAVPropertyName.calendarDescription,
                CalDAVPropertyName.calendarTimezone,
                CalDAVPropertyName.supportedCalendarComponentSet,
                ApplePropertyName.getctag
            ]
        )
    }

    /// Create a PROPFIND request for address book properties
    ///
    /// Requests properties relevant to CardDAV address books.
    ///
    /// - Parameters:
    ///   - url: The URL to query
    ///   - depth: The depth level
    /// - Returns: A PROPFIND request
    public static func addressBookProperties(url: URL, depth: Int = 1) -> PropfindRequest {
        PropfindRequest(
            url: url,
            depth: depth,
            properties: [
                DAVPropertyName.displayName,
                DAVPropertyName.resourceType,
                DAVPropertyName.getETag,
                CardDAVPropertyName.addressbookDescription,
                ApplePropertyName.getctag
            ]
        )
    }
}
