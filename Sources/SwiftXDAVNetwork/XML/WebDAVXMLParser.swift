import Foundation
import SwiftXDAVCore

/// Parser for WebDAV XML responses
///
/// `WebDAVXMLParser` handles parsing of WebDAV multi-status (207) responses,
/// including PROPFIND results, REPORT results, and other WebDAV operations.
///
/// ## Usage
///
/// ```swift
/// let parser = WebDAVXMLParser()
/// let responses = try await parser.parse(responseData)
///
/// for response in responses {
///     print("Resource: \(response.href)")
///     for property in response.properties {
///         print("  \(property.name): \(property.value ?? "")")
///     }
/// }
/// ```
///
/// ## WebDAV Multi-Status Format
///
/// WebDAV responses typically follow this structure:
/// ```xml
/// <?xml version="1.0" encoding="UTF-8"?>
/// <d:multistatus xmlns:d="DAV:">
///   <d:response>
///     <d:href>/path/to/resource</d:href>
///     <d:propstat>
///       <d:prop>
///         <d:displayname>Resource Name</d:displayname>
///         <d:resourcetype><d:collection/></d:resourcetype>
///       </d:prop>
///       <d:status>HTTP/1.1 200 OK</d:status>
///     </d:propstat>
///   </d:response>
/// </d:multistatus>
/// ```
///
/// ## Topics
///
/// ### Parsing
/// - ``parse(_:)``
public final class WebDAVXMLParser: NSObject, XMLParserDelegate {
    // Parser state
    private var currentElement: String = ""
    private var currentValue: String = ""
    private var currentNamespace: String = ""

    // Response building
    private var responses: [PropfindResponse] = []
    private var currentResponse: ResponseBuilder?
    private var currentPropstat: PropstatBuilder?
    private var currentProperty: PropertyBuilder?

    // Element stack for tracking hierarchy
    private var elementStack: [String] = []

    // MARK: - Helper Methods

    /// Strip namespace prefix from element name (e.g., "d:href" → "href")
    private func stripNamespace(_ elementName: String) -> String {
        if let colonIndex = elementName.firstIndex(of: ":") {
            return String(elementName[elementName.index(after: colonIndex)...])
        }
        return elementName
    }

    // MARK: - Parsing

    /// Parse WebDAV XML response data
    ///
    /// - Parameter data: The XML data from the HTTP response
    /// - Returns: An array of PROPFIND responses
    /// - Throws: `SwiftXDAVError.parsingError` if the XML is invalid
    public func parse(_ data: Data) throws -> [PropfindResponse] {
        // Reset state
        responses = []
        currentElement = ""
        currentValue = ""
        currentNamespace = ""
        currentResponse = nil
        currentPropstat = nil
        currentProperty = nil
        elementStack = []

        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            if let error = parser.parserError {
                throw SwiftXDAVError.parsingError("XML parsing failed: \(error.localizedDescription)")
            } else {
                throw SwiftXDAVError.parsingError("XML parsing failed with unknown error")
            }
        }

        return responses
    }

    // MARK: - XMLParserDelegate

    public func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        let localName = stripNamespace(elementName)

        currentElement = localName
        currentNamespace = namespaceURI ?? ""
        currentValue = ""
        elementStack.append(localName)

        // Start building structures based on element
        switch localName {
        case "response":
            currentResponse = ResponseBuilder()

        case "propstat":
            currentPropstat = PropstatBuilder()

        case "prop":
            // Inside prop element, don't create a property for it
            break

        case "href":
            // Don't create a property for href
            break

        default:
            // Check if we're inside a prop element but not in resourcetype sub-elements
            // Only create property if parent is "prop" (not nested in another property)
            let parentElement = elementStack.count >= 2 ? elementStack[elementStack.count - 2] : ""
            if parentElement == "prop" &&
               !["prop", "propstat", "response", "multistatus", "collection", "calendar"].contains(localName) {
                // This is a property element
                currentProperty = PropertyBuilder(
                    namespace: currentNamespace,
                    name: localName
                )
            }
        }
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    public func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        let localName = stripNamespace(elementName)
        let trimmedValue = currentValue.trimmingCharacters(in: .whitespacesAndNewlines)

        switch localName {
        case "href":
            // Check if this href is directly under response (not under prop)
            if elementStack.count >= 2 && elementStack[elementStack.count - 2] == "response" {
                currentResponse?.href = trimmedValue.xmlUnescaped
            } else if currentProperty != nil {
                // This is a nested href within a property value (e.g., current-user-principal)
                currentProperty?.nestedHref = trimmedValue.xmlUnescaped
            }

        case "status":
            // Status in propstat
            currentPropstat?.status = trimmedValue

        case "propstat":
            // Finished building propstat
            if let propstat = currentPropstat {
                currentResponse?.propstats.append(propstat)
            }
            currentPropstat = nil

        case "response":
            // Finished building response
            if let response = currentResponse?.build() {
                responses.append(response)
            }
            currentResponse = nil

        case "prop":
            // Finished with prop element
            break

        case "resourcetype":
            // Finished with resourcetype - save it if we have one
            if let property = currentProperty, property.name == "resourcetype" {
                currentPropstat?.properties.append(property.build())
                currentProperty = nil
            }

        case "collection":
            // Mark that this is a collection
            currentProperty?.isCollection = true

        case "calendar":
            // Mark that this is a calendar
            currentProperty?.isCalendar = true

        default:
            // Check if this is a property element
            if let property = currentProperty, property.name == localName {
                // Set the property value
                property.value = trimmedValue.isEmpty ? nil : trimmedValue.xmlUnescaped
                currentPropstat?.properties.append(property.build())
                currentProperty = nil
            }
        }

        // Pop from element stack
        if !elementStack.isEmpty {
            elementStack.removeLast()
        }

        currentValue = ""
    }

    public func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        // Error will be handled in parse() method
    }
}

// MARK: - Response Types

/// A PROPFIND response representing a single resource
///
/// Contains the resource URL (href) and all discovered properties.
public struct PropfindResponse: Sendable, Equatable {
    /// The URL of the resource
    public let href: String

    /// The properties found for this resource
    public let properties: [DAVProperty]

    /// The HTTP status code for this response (usually 200)
    public let status: String?

    /// Initialize a PROPFIND response
    public init(href: String, properties: [DAVProperty], status: String? = nil) {
        self.href = href
        self.properties = properties
        self.status = status
    }

    /// Get a specific property by name
    ///
    /// - Parameter name: The property name (without namespace)
    /// - Returns: The property value, or nil if not found
    public func property(named name: String) -> String? {
        properties.first { $0.name == name }?.value
    }

    /// Check if this resource is a collection
    public var isCollection: Bool {
        properties.contains { property in
            property.name == "resourcetype" && (property.value?.contains("collection") ?? false)
        }
    }
}

// MARK: - Builder Types

private class ResponseBuilder {
    var href: String = ""
    var propstats: [PropstatBuilder] = []

    func build() -> PropfindResponse? {
        guard !href.isEmpty else { return nil }

        // Merge properties from all propstats with 200-level status
        var allProperties: [DAVProperty] = []
        var status: String?

        for propstat in propstats {
            // Only include properties with successful status (2xx)
            if let propstatStatus = propstat.status, propstatStatus.contains("200") {
                allProperties.append(contentsOf: propstat.properties)
                if status == nil {
                    status = propstatStatus
                }
            }
        }

        return PropfindResponse(
            href: href,
            properties: allProperties,
            status: status
        )
    }
}

private class PropstatBuilder {
    var properties: [DAVProperty] = []
    var status: String?
}

private class PropertyBuilder {
    let namespace: String
    let name: String
    var value: String?
    var nestedHref: String?
    var isCollection = false
    var isCalendar = false

    init(namespace: String, name: String) {
        self.namespace = namespace
        self.name = name
    }

    func build() -> DAVProperty {
        var finalValue = value

        // If there's a nested href, use it as the value (properties like current-user-principal)
        if let href = nestedHref {
            finalValue = href
        }

        // Special handling for resourcetype
        if name == "resourcetype" {
            if isCollection && isCalendar {
                finalValue = "collection,calendar"
            } else if isCollection {
                finalValue = "collection"
            } else if isCalendar {
                finalValue = "calendar"
            }
        }

        return DAVProperty(
            namespace: namespace.isEmpty ? "DAV:" : namespace,
            name: name,
            value: finalValue
        )
    }
}
