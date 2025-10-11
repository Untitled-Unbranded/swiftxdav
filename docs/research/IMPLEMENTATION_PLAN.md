# SwiftXDAV Implementation Plan

This document provides a comprehensive, step-by-step implementation plan for building the SwiftXDAV framework. This plan is designed for an LLM agent to execute autonomously.

## Table of Contents

1. [Project Overview](#project-overview)
2. [Prerequisites](#prerequisites)
3. [Phase 1: Project Setup](#phase-1-project-setup)
4. [Phase 2: Core Foundation](#phase-2-core-foundation)
5. [Phase 3: Network Layer](#phase-3-network-layer)
6. [Phase 4: WebDAV Implementation](#phase-4-webdav-implementation)
7. [Phase 5: iCalendar Parser](#phase-5-icalendar-parser)
8. [Phase 6: vCard Parser](#phase-6-vcard-parser)
9. [Phase 7: CalDAV Implementation](#phase-7-caldav-implementation)
10. [Phase 8: CardDAV Implementation](#phase-8-carddav-implementation)
11. [Phase 9: Server-Specific Implementations](#phase-9-server-specific-implementations)
12. [Phase 10: Synchronization](#phase-10-synchronization)
13. [Phase 11: Advanced Features](#phase-11-advanced-features)
14. [Phase 12: Testing and Documentation](#phase-12-testing-and-documentation)
15. [Success Criteria](#success-criteria)

---

## Project Overview

### Goals

Build a production-ready Swift framework that:
- Implements CalDAV (RFC 4791) and CardDAV (RFC 6352) protocols
- Supports WebDAV (RFC 4918) as foundation
- Parses and generates iCalendar (RFC 5545) and vCard (RFC 6350) data
- Works with iCloud, Google Calendar/Contacts, and self-hosted servers
- Uses Swift 6.0+ features (async/await, actors, Sendable)
- Provides a clean, type-safe, SwiftAPI

### Non-Goals

- UI components (framework only)
- Direct EventKit or Contacts framework integration (separate responsibility)
- Microsoft Graph API (different protocol, possible future extension)
- Calendar rendering or visualization

### Architecture Principles

1. **Modular**: Separate concerns into distinct modules
2. **Protocol-Oriented**: Use protocols for abstraction and testing
3. **Type-Safe**: Leverage Swift's type system
4. **Async**: Use async/await throughout
5. **Thread-Safe**: Use actors and Sendable types
6. **Testable**: Design for unit and integration testing
7. **Standards-Compliant**: Follow RFCs strictly

---

## Prerequisites

### Required Reading

Before starting implementation, read these documents:
- `docs/research/RFC_STANDARDS.md` - Complete RFC specifications
- `docs/research/SWIFT_6_BEST_PRACTICES.md` - Swift 6.0 guidance
- `docs/research/LIBRARY_ANALYSIS.md` - Existing library patterns
- `docs/research/SERVER_IMPLEMENTATIONS.md` - Server-specific details

### Development Environment

- macOS 13+ or Xcode 15+
- Swift 6.0 or later
- Xcode command line tools

### Dependencies

- **Alamofire** (>= 5.9.0): HTTP networking
- Consider native `XMLParser` for XML parsing (or XMLCoder if preferred)
- No other external dependencies initially

---

## Phase 1: Project Setup

### Step 1.1: Initialize Swift Package

Create the Swift Package structure:

```bash
swift package init --type library --name SwiftXDAV
```

### Step 1.2: Configure Package.swift

Edit `Package.swift` with the following structure:

```swift
// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "SwiftXDAV",
    platforms: [
        .macOS(.v13),
        .iOS(.v16),
        .tvOS(.v16),
        .watchOS(.v9),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "SwiftXDAV", targets: ["SwiftXDAV"]),
        .library(name: "SwiftXDAVCore", targets: ["SwiftXDAVCore"]),
        .library(name: "SwiftXDAVNetwork", targets: ["SwiftXDAVNetwork"]),
        .library(name: "SwiftXDAVCalendar", targets: ["SwiftXDAVCalendar"]),
        .library(name: "SwiftXDAVContacts", targets: ["SwiftXDAVContacts"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
    ],
    targets: [
        // Core module
        .target(
            name: "SwiftXDAVCore",
            dependencies: [],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Network module
        .target(
            name: "SwiftXDAVNetwork",
            dependencies: [
                "SwiftXDAVCore",
                "Alamofire"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Calendar module
        .target(
            name: "SwiftXDAVCalendar",
            dependencies: [
                "SwiftXDAVCore",
                "SwiftXDAVNetwork"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Contacts module
        .target(
            name: "SwiftXDAVContacts",
            dependencies: [
                "SwiftXDAVCore",
                "SwiftXDAVNetwork"
            ],
            swiftSettings: [
                .enableExperimentalFeature("StrictConcurrency")
            ]
        ),

        // Umbrella module
        .target(
            name: "SwiftXDAV",
            dependencies: [
                "SwiftXDAVCore",
                "SwiftXDAVNetwork",
                "SwiftXDAVCalendar",
                "SwiftXDAVContacts"
            ]
        ),

        // Tests
        .testTarget(name: "SwiftXDAVCoreTests", dependencies: ["SwiftXDAVCore"]),
        .testTarget(name: "SwiftXDAVNetworkTests", dependencies: ["SwiftXDAVNetwork"]),
        .testTarget(name: "SwiftXDAVCalendarTests", dependencies: ["SwiftXDAVCalendar"]),
        .testTarget(name: "SwiftXDAVContactsTests", dependencies: ["SwiftXDAVContacts"]),
    ],
    swiftLanguageVersions: [.v6]
)
```

### Step 1.3: Create Directory Structure

```bash
mkdir -p Sources/SwiftXDAVCore/{Models,Protocols,Utilities,Errors}
mkdir -p Sources/SwiftXDAVNetwork/{HTTP,WebDAV,Authentication,XML}
mkdir -p Sources/SwiftXDAVCalendar/{Models,Client,Parser,Recurrence}
mkdir -p Sources/SwiftXDAVContacts/{Models,Client,Parser}
mkdir -p Tests/SwiftXDAVCoreTests
mkdir -p Tests/SwiftXDAVNetworkTests
mkdir -p Tests/SwiftXDAVCalendarTests
mkdir -p Tests/SwiftXDAVContactsTests
mkdir -p Tests/Fixtures
```

### Step 1.4: Create Initial Files

Create placeholder files:

```bash
touch Sources/SwiftXDAV/SwiftXDAV.swift
touch Sources/SwiftXDAVCore/SwiftXDAVCore.swift
touch Sources/SwiftXDAVNetwork/SwiftXDAVNetwork.swift
touch Sources/SwiftXDAVCalendar/SwiftXDAVCalendar.swift
touch Sources/SwiftXDAVContacts/SwiftXDAVContacts.swift
```

### Step 1.5: Verify Build

```bash
swift build
```

Ensure the package builds successfully.

---

## Phase 2: Core Foundation

### Step 2.1: Define Error Types

**File:** `Sources/SwiftXDAVCore/Errors/SwiftXDAVError.swift`

```swift
import Foundation

/// Root error type for all SwiftXDAV errors
public enum SwiftXDAVError: Error, LocalizedError {
    case networkError(underlying: Error)
    case invalidResponse(statusCode: Int, body: String?)
    case parsingError(String)
    case authenticationRequired
    case unauthorized
    case forbidden
    case notFound
    case conflict(String)
    case preconditionFailed(etag: String?)
    case serverError(statusCode: Int, message: String?)
    case unsupportedOperation(String)
    case invalidData(String)

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
        }
    }
}
```

### Step 2.2: Define Core Protocols

**File:** `Sources/SwiftXDAVCore/Protocols/Resource.swift`

```swift
import Foundation

/// Represents a DAV resource (file or collection)
public protocol Resource: Sendable {
    /// The URL of this resource
    var url: URL { get }

    /// The ETag for cache validation
    var etag: String? { get }

    /// The resource type
    var resourceType: ResourceType { get }
}

public enum ResourceType: Sendable {
    case collection
    case resource
    case calendar
    case addressBook
}
```

**File:** `Sources/SwiftXDAVCore/Protocols/HTTPClient.swift`

```swift
import Foundation

/// HTTP request method
public enum HTTPMethod: String, Sendable {
    case get = "GET"
    case post = "POST"
    case put = "PUT"
    case delete = "DELETE"
    case options = "OPTIONS"
    case propfind = "PROPFIND"
    case proppatch = "PROPPATCH"
    case mkcol = "MKCOL"
    case copy = "COPY"
    case move = "MOVE"
    case lock = "LOCK"
    case unlock = "UNLOCK"
    case report = "REPORT"
}

/// HTTP response
public struct HTTPResponse: Sendable {
    public let statusCode: Int
    public let headers: [String: String]
    public let data: Data

    public init(statusCode: Int, headers: [String: String], data: Data) {
        self.statusCode = statusCode
        self.headers = headers
        self.data = data
    }
}

/// Protocol for HTTP client implementations
public protocol HTTPClient: Sendable {
    /// Execute an HTTP request
    func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse
}
```

### Step 2.3: Define Common Models

**File:** `Sources/SwiftXDAVCore/Models/DAVProperty.swift`

```swift
import Foundation

/// Represents a WebDAV property
public struct DAVProperty: Sendable, Equatable {
    public let namespace: String
    public let name: String
    public let value: String?

    public init(namespace: String, name: String, value: String? = nil) {
        self.namespace = namespace
        self.name = name
        self.value = value
    }
}

/// Common WebDAV property names
public enum DAVPropertyName {
    public static let resourceType = DAVProperty(namespace: "DAV:", name: "resourcetype")
    public static let displayName = DAVProperty(namespace: "DAV:", name: "displayname")
    public static let getETag = DAVProperty(namespace: "DAV:", name: "getetag")
    public static let getContentType = DAVProperty(namespace: "DAV:", name: "getcontenttype")
    public static let getLastModified = DAVProperty(namespace: "DAV:", name: "getlastmodified")
    public static let creationDate = DAVProperty(namespace: "DAV:", name: "creationdate")
    public static let getContentLength = DAVProperty(namespace: "DAV:", name: "getcontentlength")
    public static let currentUserPrincipal = DAVProperty(namespace: "DAV:", name: "current-user-principal")
    public static let supportedLock = DAVProperty(namespace: "DAV:", name: "supportedlock")
}
```

### Step 2.4: Create Utilities

**File:** `Sources/SwiftXDAVCore/Utilities/DateFormatter+ISO8601.swift`

```swift
import Foundation

extension DateFormatter {
    /// ISO 8601 date formatter for iCalendar dates
    public static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    /// ISO 8601 date-only formatter
    public static let iso8601DateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()
}

extension Date {
    /// Format as iCalendar date-time string (UTC)
    public func toICalendarFormat() -> String {
        DateFormatter.iso8601.string(from: self)
    }

    /// Format as iCalendar date-only string
    public func toICalendarDateFormat() -> String {
        DateFormatter.iso8601DateOnly.string(from: self)
    }
}

extension String {
    /// Parse iCalendar date-time string
    public func fromICalendarFormat() -> Date? {
        // Try with 'Z' suffix first
        if let date = DateFormatter.iso8601.date(from: self) {
            return date
        }

        // Try without 'Z' suffix (local time)
        let localFormatter = DateFormatter()
        localFormatter.calendar = Calendar(identifier: .iso8601)
        localFormatter.locale = Locale(identifier: "en_US_POSIX")
        localFormatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return localFormatter.date(from: self)
    }

    /// Parse iCalendar date-only string
    public func fromICalendarDateFormat() -> Date? {
        DateFormatter.iso8601DateOnly.date(from: self)
    }
}
```

### Step 2.5: Write Tests for Core

**File:** `Tests/SwiftXDAVCoreTests/DateFormatterTests.swift`

```swift
import XCTest
@testable import SwiftXDAVCore

final class DateFormatterTests: XCTestCase {
    func testICalendarDateFormat() {
        let date = Date(timeIntervalSince1970: 1623456789) // 2021-06-12T01:19:49Z
        let formatted = date.toICalendarFormat()
        XCTAssertEqual(formatted, "20210612T011949Z")

        let parsed = formatted.fromICalendarFormat()
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.timeIntervalSince1970, date.timeIntervalSince1970, accuracy: 1.0)
    }

    func testICalendarDateOnlyFormat() {
        let date = Date(timeIntervalSince1970: 1623456789)
        let formatted = date.toICalendarDateFormat()
        XCTAssertEqual(formatted, "20210612")

        let parsed = formatted.fromICalendarDateFormat()
        XCTAssertNotNil(parsed)
    }
}
```

Run tests:
```bash
swift test
```

---

## Phase 3: Network Layer

### Step 3.1: Implement Alamofire-Based HTTP Client

**File:** `Sources/SwiftXDAVNetwork/HTTP/AlamofireHTTPClient.swift`

```swift
import Foundation
import Alamofire
import SwiftXDAVCore

/// HTTP client implementation using Alamofire
public actor AlamofireHTTPClient: HTTPClient {
    private let session: Session

    public init(configuration: URLSessionConfiguration = .default) {
        self.session = Session(configuration: configuration)
    }

    public func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        let httpHeaders = HTTPHeaders(headers?.map { HTTPHeader(name: $0.key, value: $0.value) } ?? [])

        let dataRequest = session.request(
            url,
            method: Alamofire.HTTPMethod(rawValue: method.rawValue),
            parameters: nil,
            encoding: body.map { RawDataEncoding(data: $0) } ?? URLEncoding.default,
            headers: httpHeaders
        )

        let response = await dataRequest.serializingData().response

        guard let httpResponse = response.response else {
            throw SwiftXDAVError.networkError(underlying: response.error ?? URLError(.badServerResponse))
        }

        let responseHeaders = httpResponse.headers.dictionary
        let responseData = response.data ?? Data()

        if let error = response.error {
            throw SwiftXDAVError.networkError(underlying: error)
        }

        return HTTPResponse(
            statusCode: httpResponse.statusCode,
            headers: responseHeaders,
            data: responseData
        )
    }
}

// Helper for sending raw data in request body
private struct RawDataEncoding: ParameterEncoding {
    let data: Data

    func encode(_ urlRequest: URLRequestConvertible, with parameters: Parameters?) throws -> URLRequest {
        var request = try urlRequest.asURLRequest()
        request.httpBody = data
        return request
    }
}
```

### Step 3.2: Implement Authentication

**File:** `Sources/SwiftXDAVNetwork/Authentication/Authentication.swift`

```swift
import Foundation

/// Authentication methods
public enum Authentication: Sendable {
    case none
    case basic(username: String, password: String)
    case bearer(token: String)
    case oauth2(accessToken: String, refreshToken: String?, tokenURL: URL?)

    /// Apply authentication to request headers
    public func apply(to headers: inout [String: String]) {
        switch self {
        case .none:
            break

        case .basic(let username, let password):
            let credentials = "\(username):\(password)"
            if let data = credentials.data(using: .utf8) {
                let base64 = data.base64EncodedString()
                headers["Authorization"] = "Basic \(base64)"
            }

        case .bearer(let token):
            headers["Authorization"] = "Bearer \(token)"

        case .oauth2(let accessToken, _, _):
            headers["Authorization"] = "Bearer \(accessToken)"
        }
    }
}
```

### Step 3.3: Create Authenticated HTTP Client

**File:** `Sources/SwiftXDAVNetwork/HTTP/AuthenticatedHTTPClient.swift`

```swift
import Foundation
import SwiftXDAVCore

/// HTTP client that handles authentication
public actor AuthenticatedHTTPClient: HTTPClient {
    private let baseClient: HTTPClient
    private let authentication: Authentication

    public init(baseClient: HTTPClient, authentication: Authentication) {
        self.baseClient = baseClient
        self.authentication = authentication
    }

    public func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        var authHeaders = headers ?? [:]
        authentication.apply(to: &authHeaders)

        return try await baseClient.request(
            method,
            url: url,
            headers: authHeaders,
            body: body
        )
    }
}
```

### Step 3.4: Write Network Tests

**File:** `Tests/SwiftXDAVNetworkTests/HTTPClientTests.swift`

```swift
import XCTest
@testable import SwiftXDAVNetwork
@testable import SwiftXDAVCore

final class HTTPClientTests: XCTestCase {
    func testBasicAuthentication() async throws {
        let auth = Authentication.basic(username: "user", password: "pass")
        var headers: [String: String] = [:]
        auth.apply(to: &headers)

        XCTAssertNotNil(headers["Authorization"])
        XCTAssertTrue(headers["Authorization"]!.hasPrefix("Basic "))
    }

    func testBearerAuthentication() {
        let auth = Authentication.bearer(token: "abc123")
        var headers: [String: String] = [:]
        auth.apply(to: &headers)

        XCTAssertEqual(headers["Authorization"], "Bearer abc123")
    }
}
```

---

## Phase 4: WebDAV Implementation

### Step 4.1: XML Parser Utilities

**File:** `Sources/SwiftXDAVNetwork/XML/XMLBuilder.swift`

```swift
import Foundation

/// Helper for building XML documents
public struct XMLBuilder {
    private var elements: [String] = []

    public init() {}

    public mutating func startElement(_ name: String, attributes: [String: String] = [:]) {
        var element = "<\(name)"
        for (key, value) in attributes {
            element += " \(key)=\"\(value.xmlEscaped)\""
        }
        element += ">"
        elements.append(element)
    }

    public mutating func endElement(_ name: String) {
        elements.append("</\(name)>")
    }

    public mutating func element(_ name: String, value: String, attributes: [String: String] = [:]) {
        startElement(name, attributes: attributes)
        elements.append(value.xmlEscaped)
        endElement(name)
    }

    public func build() -> String {
        elements.joined()
    }
}

extension String {
    var xmlEscaped: String {
        self
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
```

**File:** `Sources/SwiftXDAVNetwork/XML/XMLParser.swift`

```swift
import Foundation
import SwiftXDAVCore

/// Parser for WebDAV XML responses
public actor WebDAVXMLParser: NSObject, XMLParserDelegate {
    private var currentElement: String = ""
    private var currentValue: String = ""
    private var responses: [PropfindResponse] = []
    private var currentResponse: PropfindResponse?
    private var currentProperties: [DAVProperty] = []

    public func parse(_ data: Data) async throws -> [PropfindResponse] {
        responses = []
        let parser = XMLParser(data: data)
        parser.delegate = self

        guard parser.parse() else {
            throw SwiftXDAVError.parsingError("Failed to parse XML")
        }

        return responses
    }

    // XMLParserDelegate methods
    public func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentElement = elementName
        currentValue = ""
    }

    public func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentValue += string
    }

    public func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        // Parse response elements and properties
        // This is simplified - full implementation would handle all WebDAV properties

        switch elementName {
        case "href":
            if currentResponse == nil {
                currentResponse = PropfindResponse(href: currentValue.trimmingCharacters(in: .whitespacesAndNewlines), properties: [])
            }
        case "displayname":
            let prop = DAVProperty(namespace: "DAV:", name: "displayname", value: currentValue.trimmingCharacters(in: .whitespacesAndNewlines))
            currentProperties.append(prop)
        case "response":
            if var response = currentResponse {
                response.properties = currentProperties
                responses.append(response)
                currentResponse = nil
                currentProperties = []
            }
        default:
            break
        }
    }
}

public struct PropfindResponse: Sendable {
    public var href: String
    public var properties: [DAVProperty]
}
```

### Step 4.2: Implement PROPFIND

**File:** `Sources/SwiftXDAVNetwork/WebDAV/PropfindRequest.swift`

```swift
import Foundation
import SwiftXDAVCore

/// PROPFIND request builder
public struct PropfindRequest {
    public let url: URL
    public let depth: Int
    public let properties: [DAVProperty]

    public init(url: URL, depth: Int, properties: [DAVProperty]) {
        self.url = url
        self.depth = depth
        self.properties = properties
    }

    /// Build the XML request body
    public func buildXML() -> Data {
        var xml = XMLBuilder()

        xml.startElement("d:propfind", attributes: ["xmlns:d": "DAV:"])
        xml.startElement("d:prop")

        for property in properties {
            xml.element("d:\(property.name)", value: "")
        }

        xml.endElement("d:prop")
        xml.endElement("d:propfind")

        let xmlString = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n" + xml.build()
        return xmlString.data(using: .utf8) ?? Data()
    }

    /// Execute the PROPFIND request
    public func execute(using client: HTTPClient) async throws -> [PropfindResponse] {
        let body = buildXML()
        let headers = [
            "Depth": "\(depth)",
            "Content-Type": "application/xml; charset=utf-8"
        ]

        let response = try await client.request(
            .propfind,
            url: url,
            headers: headers,
            body: body
        )

        guard response.statusCode == 207 else {
            throw SwiftXDAVError.invalidResponse(statusCode: response.statusCode, body: String(data: response.data, encoding: .utf8))
        }

        let parser = WebDAVXMLParser()
        return try await parser.parse(response.data)
    }
}
```

### Step 4.3: Implement Other WebDAV Methods

Create similar implementations for:
- MKCOL (create collection)
- PUT (create/update resource)
- DELETE (delete resource)
- COPY, MOVE (resource management)

**File:** `Sources/SwiftXDAVNetwork/WebDAV/WebDAVOperations.swift`

```swift
import Foundation
import SwiftXDAVCore

/// WebDAV operations
public struct WebDAVOperations {
    private let client: HTTPClient

    public init(client: HTTPClient) {
        self.client = client
    }

    /// Create a collection
    public func mkcol(at url: URL) async throws {
        let response = try await client.request(
            .mkcol,
            url: url,
            headers: nil,
            body: nil
        )

        guard response.statusCode == 201 else {
            throw SwiftXDAVError.invalidResponse(statusCode: response.statusCode, body: nil)
        }
    }

    /// Put a resource
    public func put(_ data: Data, at url: URL, contentType: String, ifMatch etag: String? = nil) async throws -> String? {
        var headers = ["Content-Type": contentType]
        if let etag = etag {
            headers["If-Match"] = etag
        }

        let response = try await client.request(
            .put,
            url: url,
            headers: headers,
            body: data
        )

        guard [200, 201, 204].contains(response.statusCode) else {
            throw SwiftXDAVError.invalidResponse(statusCode: response.statusCode, body: String(data: response.data, encoding: .utf8))
        }

        return response.headers["ETag"]
    }

    /// Delete a resource
    public func delete(at url: URL) async throws {
        let response = try await client.request(
            .delete,
            url: url,
            headers: nil,
            body: nil
        )

        guard [200, 204].contains(response.statusCode) else {
            throw SwiftXDAVError.invalidResponse(statusCode: response.statusCode, body: nil)
        }
    }
}
```

---

## Phase 5: iCalendar Parser

### Step 5.1: Define iCalendar Models

**File:** `Sources/SwiftXDAVCalendar/Models/ICalendar.swift`

```swift
import Foundation

/// Root iCalendar container
public struct ICalendar: Sendable, Equatable {
    public var version: String
    public var prodid: String
    public var calscale: String
    public var method: String?
    public var events: [VEvent]
    public var todos: [VTodo]
    public var timezones: [VTimeZone]

    public init(
        version: String = "2.0",
        prodid: String = "-//SwiftXDAV//SwiftXDAV 1.0//EN",
        calscale: String = "GREGORIAN",
        method: String? = nil,
        events: [VEvent] = [],
        todos: [VTodo] = [],
        timezones: [VTimeZone] = []
    ) {
        self.version = version
        self.prodid = prodid
        self.calscale = calscale
        self.method = method
        self.events = events
        self.todos = todos
        self.timezones = timezones
    }
}
```

**File:** `Sources/SwiftXDAVCalendar/Models/VEvent.swift`

```swift
import Foundation

/// iCalendar VEVENT component
public struct VEvent: Sendable, Equatable {
    public var uid: String
    public var dtstamp: Date
    public var dtstart: Date?
    public var dtend: Date?
    public var duration: TimeInterval?
    public var summary: String?
    public var description: String?
    public var location: String?
    public var status: EventStatus?
    public var transparency: Transparency?
    public var organizer: Organizer?
    public var attendees: [Attendee]
    public var rrule: RecurrenceRule?
    public var exdates: [Date]
    public var rdates: [Date]
    public var alarms: [VAlarm]
    public var categories: [String]
    public var sequence: Int
    public var created: Date?
    public var lastModified: Date?
    public var url: URL?

    public init(
        uid: String = UUID().uuidString,
        dtstamp: Date = Date(),
        dtstart: Date? = nil,
        dtend: Date? = nil,
        duration: TimeInterval? = nil,
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        status: EventStatus? = nil,
        transparency: Transparency? = nil,
        organizer: Organizer? = nil,
        attendees: [Attendee] = [],
        rrule: RecurrenceRule? = nil,
        exdates: [Date] = [],
        rdates: [Date] = [],
        alarms: [VAlarm] = [],
        categories: [String] = [],
        sequence: Int = 0,
        created: Date? = nil,
        lastModified: Date? = nil,
        url: URL? = nil
    ) {
        self.uid = uid
        self.dtstamp = dtstamp
        self.dtstart = dtstart
        self.dtend = dtend
        self.duration = duration
        self.summary = summary
        self.description = description
        self.location = location
        self.status = status
        self.transparency = transparency
        self.organizer = organizer
        self.attendees = attendees
        self.rrule = rrule
        self.exdates = exdates
        self.rdates = rdates
        self.alarms = alarms
        self.categories = categories
        self.sequence = sequence
        self.created = created
        self.lastModified = lastModified
        self.url = url
    }
}

public enum EventStatus: String, Sendable {
    case tentative = "TENTATIVE"
    case confirmed = "CONFIRMED"
    case cancelled = "CANCELLED"
}

public enum Transparency: String, Sendable {
    case opaque = "OPAQUE"
    case transparent = "TRANSPARENT"
}

public struct Organizer: Sendable, Equatable {
    public var email: String
    public var commonName: String?

    public init(email: String, commonName: String? = nil) {
        self.email = email
        self.commonName = commonName
    }
}

public struct Attendee: Sendable, Equatable {
    public var email: String
    public var commonName: String?
    public var role: AttendeeRole
    public var status: ParticipationStatus
    public var rsvp: Bool

    public init(
        email: String,
        commonName: String? = nil,
        role: AttendeeRole = .reqParticipant,
        status: ParticipationStatus = .needsAction,
        rsvp: Bool = false
    ) {
        self.email = email
        self.commonName = commonName
        self.role = role
        self.status = status
        self.rsvp = rsvp
    }
}

public enum AttendeeRole: String, Sendable {
    case chair = "CHAIR"
    case reqParticipant = "REQ-PARTICIPANT"
    case optParticipant = "OPT-PARTICIPANT"
    case nonParticipant = "NON-PARTICIPANT"
}

public enum ParticipationStatus: String, Sendable {
    case needsAction = "NEEDS-ACTION"
    case accepted = "ACCEPTED"
    case declined = "DECLINED"
    case tentative = "TENTATIVE"
    case delegated = "DELEGATED"
}
```

Create similar models for:
- VTodo
- VTimeZone
- VAlarm
- RecurrenceRule

### Step 5.2: Implement iCalendar Parser

**File:** `Sources/SwiftXDAVCalendar/Parser/ICalendarParser.swift`

```swift
import Foundation
import SwiftXDAVCore

/// Parser for iCalendar data
public actor ICalendarParser {
    public init() {}

    /// Parse iCalendar data
    public func parse(_ data: Data) async throws -> ICalendar {
        guard let text = String(data: data, encoding: .utf8) else {
            throw SwiftXDAVError.parsingError("Invalid UTF-8 encoding")
        }

        return try parse(text)
    }

    /// Parse iCalendar text
    public func parse(_ text: String) throws -> ICalendar {
        var lines = unfoldLines(text)
        var calendar = ICalendar()
        var currentComponent: Component?

        for line in lines {
            let (name, parameters, value) = try parseLine(line)

            switch name {
            case "BEGIN":
                currentComponent = Component(type: value)

            case "END":
                if let component = currentComponent {
                    try addComponent(component, to: &calendar)
                    currentComponent = nil
                }

            case "VERSION":
                calendar.version = value

            case "PRODID":
                calendar.prodid = value

            case "CALSCALE":
                calendar.calscale = value

            case "METHOD":
                calendar.method = value

            default:
                if var component = currentComponent {
                    component.properties.append(Property(name: name, parameters: parameters, value: value))
                    currentComponent = component
                }
            }
        }

        return calendar
    }

    /// Unfold lines (handle line wrapping)
    private func unfoldLines(_ text: String) -> [String] {
        var result: [String] = []
        var currentLine = ""

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                // Continuation of previous line
                currentLine += line.dropFirst()
            } else {
                if !currentLine.isEmpty {
                    result.append(currentLine)
                }
                currentLine = line
            }
        }

        if !currentLine.isEmpty {
            result.append(currentLine)
        }

        return result
    }

    /// Parse a single line
    private func parseLine(_ line: String) throws -> (name: String, parameters: [String: String], value: String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            throw SwiftXDAVError.parsingError("Invalid line format: \(line)")
        }

        let nameAndParams = line[..<colonIndex]
        let value = String(line[line.index(after: colonIndex)...])

        let parts = nameAndParams.components(separatedBy: ";")
        let name = parts[0]
        var parameters: [String: String] = [:]

        for param in parts.dropFirst() {
            let paramParts = param.components(separatedBy: "=")
            if paramParts.count == 2 {
                parameters[paramParts[0]] = paramParts[1]
            }
        }

        return (name, parameters, value)
    }

    /// Add parsed component to calendar
    private func addComponent(_ component: Component, to calendar: inout ICalendar) throws {
        switch component.type {
        case "VEVENT":
            let event = try parseVEvent(component)
            calendar.events.append(event)

        case "VTODO":
            let todo = try parseVTodo(component)
            calendar.todos.append(todo)

        case "VTIMEZONE":
            let tz = try parseVTimeZone(component)
            calendar.timezones.append(tz)

        default:
            // Ignore unknown components
            break
        }
    }

    private func parseVEvent(_ component: Component) throws -> VEvent {
        var event = VEvent()

        for prop in component.properties {
            switch prop.name {
            case "UID":
                event.uid = prop.value
            case "DTSTART":
                event.dtstart = try parseDate(prop.value, parameters: prop.parameters)
            case "DTEND":
                event.dtend = try parseDate(prop.value, parameters: prop.parameters)
            case "SUMMARY":
                event.summary = prop.value
            case "DESCRIPTION":
                event.description = unescapeText(prop.value)
            case "LOCATION":
                event.location = prop.value
            case "STATUS":
                event.status = EventStatus(rawValue: prop.value)
            // ... parse other properties
            default:
                break
            }
        }

        return event
    }

    private func parseVTodo(_ component: Component) throws -> VTodo {
        // Similar to parseVEvent
        fatalError("Not implemented")
    }

    private func parseVTimeZone(_ component: Component) throws -> VTimeZone {
        // Parse timezone
        fatalError("Not implemented")
    }

    private func parseDate(_ value: String, parameters: [String: String]) throws -> Date {
        // Parse date based on VALUE parameter
        if let date = value.fromICalendarFormat() {
            return date
        } else if let date = value.fromICalendarDateFormat() {
            return date
        } else {
            throw SwiftXDAVError.parsingError("Invalid date format: \(value)")
        }
    }

    private func unescapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\,", with: ",")
    }
}

// Helper types
private struct Component {
    let type: String
    var properties: [Property] = []
}

private struct Property {
    let name: String
    let parameters: [String: String]
    let value: String
}

// Placeholder for incomplete models
public struct VTodo: Sendable, Equatable {}
public struct VTimeZone: Sendable, Equatable {}
public struct VAlarm: Sendable, Equatable {}
public struct RecurrenceRule: Sendable, Equatable {}
```

### Step 5.3: Implement iCalendar Serializer

**File:** `Sources/SwiftXDAVCalendar/Parser/ICalendarSerializer.swift`

```swift
import Foundation

/// Serializer for iCalendar data
public actor ICalendarSerializer {
    public init() {}

    /// Serialize iCalendar to data
    public func serialize(_ calendar: ICalendar) async throws -> Data {
        let text = try serializeToString(calendar)
        guard let data = text.data(using: .utf8) else {
            throw SwiftXDAVError.invalidData("Failed to encode as UTF-8")
        }
        return data
    }

    /// Serialize to string
    public func serializeToString(_ calendar: ICalendar) throws -> String {
        var lines: [String] = []

        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:\(calendar.version)")
        lines.append("PRODID:\(calendar.prodid)")
        lines.append("CALSCALE:\(calendar.calscale)")

        if let method = calendar.method {
            lines.append("METHOD:\(method)")
        }

        for event in calendar.events {
            lines.append(contentsOf: serializeVEvent(event))
        }

        for todo in calendar.todos {
            lines.append(contentsOf: serializeVTodo(todo))
        }

        for tz in calendar.timezones {
            lines.append(contentsOf: serializeVTimeZone(tz))
        }

        lines.append("END:VCALENDAR")

        return foldLines(lines).joined(separator: "\r\n") + "\r\n"
    }

    private func serializeVEvent(_ event: VEvent) -> [String] {
        var lines: [String] = []

        lines.append("BEGIN:VEVENT")
        lines.append("UID:\(event.uid)")
        lines.append("DTSTAMP:\(event.dtstamp.toICalendarFormat())")

        if let dtstart = event.dtstart {
            lines.append("DTSTART:\(dtstart.toICalendarFormat())")
        }

        if let dtend = event.dtend {
            lines.append("DTEND:\(dtend.toICalendarFormat())")
        }

        if let summary = event.summary {
            lines.append("SUMMARY:\(escapeText(summary))")
        }

        if let description = event.description {
            lines.append("DESCRIPTION:\(escapeText(description))")
        }

        if let location = event.location {
            lines.append("LOCATION:\(escapeText(location))")
        }

        if let status = event.status {
            lines.append("STATUS:\(status.rawValue)")
        }

        // ... serialize other properties

        lines.append("END:VEVENT")

        return lines
    }

    private func serializeVTodo(_ todo: VTodo) -> [String] {
        // Similar to serializeVEvent
        return []
    }

    private func serializeVTimeZone(_ tz: VTimeZone) -> [String] {
        // Serialize timezone
        return []
    }

    private func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    /// Fold long lines to max 75 characters
    private func foldLines(_ lines: [String]) -> [String] {
        lines.flatMap { line in
            if line.count <= 75 {
                return [line]
            }

            var result: [String] = []
            var remaining = line

            while !remaining.isEmpty {
                if remaining.count <= 75 {
                    result.append(remaining)
                    break
                }

                let index = remaining.index(remaining.startIndex, offsetBy: 75)
                result.append(String(remaining[..<index]))
                remaining = " " + String(remaining[index...])
            }

            return result
        }
    }
}
```

---

## Phase 6: vCard Parser

Due to length constraints, I'll provide a high-level outline:

### Step 6.1: Define vCard Models
- Create VCard struct with all properties from RFC 6350
- Support both vCard 3.0 and 4.0

### Step 6.2: Implement vCard Parser
- Similar pattern to iCalendar parser
- Handle line unfolding, parameter parsing
- Support version detection

### Step 6.3: Implement vCard Serializer
- Generate vCard 3.0 or 4.0 text
- Handle line folding
- Escape special characters

---

## Phase 7: CalDAV Implementation

### Step 7.1: CalDAV Client

**File:** `Sources/SwiftXDAVCalendar/Client/CalDAVClient.swift`

```swift
import Foundation
import SwiftXDAVCore
import SwiftXDAVNetwork

/// CalDAV client
public actor CalDAVClient {
    private let httpClient: HTTPClient
    private let baseURL: URL

    public init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    /// Discover calendar home
    public func discoverCalendarHome() async throws -> URL {
        // 1. Discover principal
        let principalURL = try await discoverPrincipal()

        // 2. Get calendar-home-set from principal
        let request = PropfindRequest(
            url: principalURL,
            depth: 0,
            properties: [DAVProperty(namespace: "urn:ietf:params:xml:ns:caldav", name: "calendar-home-set")]
        )

        let responses = try await request.execute(using: httpClient)

        // Parse calendar-home-set URL from response
        // This is simplified - full implementation would parse XML properly
        guard let calendarHome = responses.first?.properties.first(where: { $0.name == "calendar-home-set" })?.value else {
            throw SwiftXDAVError.notFound
        }

        return URL(string: calendarHome, relativeTo: baseURL)!
    }

    /// Discover principal URL
    private func discoverPrincipal() async throws -> URL {
        let request = PropfindRequest(
            url: baseURL,
            depth: 0,
            properties: [DAVPropertyName.currentUserPrincipal]
        )

        let responses = try await request.execute(using: httpClient)

        guard let principal = responses.first?.properties.first(where: { $0.name == "current-user-principal" })?.value else {
            throw SwiftXDAVError.notFound
        }

        return URL(string: principal, relativeTo: baseURL)!
    }

    /// List calendars
    public func listCalendars() async throws -> [Calendar] {
        let calendarHome = try await discoverCalendarHome()

        let request = PropfindRequest(
            url: calendarHome,
            depth: 1,
            properties: [
                DAVPropertyName.resourceType,
                DAVPropertyName.displayName,
                DAVProperty(namespace: "urn:ietf:params:xml:ns:caldav", name: "supported-calendar-component-set"),
                DAVProperty(namespace: "http://calendarserver.org/ns/", name: "getctag")
            ]
        )

        let responses = try await request.execute(using: httpClient)

        // Parse responses into Calendar objects
        // This is simplified
        return responses.compactMap { response in
            guard let displayName = response.properties.first(where: { $0.name == "displayname" })?.value else {
                return nil
            }

            return Calendar(
                url: URL(string: response.href, relativeTo: calendarHome)!,
                displayName: displayName,
                ctag: response.properties.first(where: { $0.name == "getctag" })?.value
            )
        }
    }

    /// Fetch events from calendar
    public func fetchEvents(from calendar: Calendar, start: Date, end: Date) async throws -> [VEvent] {
        // Build calendar-query REPORT
        let queryXML = buildCalendarQuery(start: start, end: end)

        let response = try await httpClient.request(
            .report,
            url: calendar.url,
            headers: ["Content-Type": "application/xml; charset=utf-8"],
            body: queryXML
        )

        guard response.statusCode == 207 else {
            throw SwiftXDAVError.invalidResponse(statusCode: response.statusCode, body: nil)
        }

        // Parse multi-status response and extract calendar data
        let parser = WebDAVXMLParser()
        let responses = try await parser.parse(response.data)

        var events: [VEvent] = []
        let icalParser = ICalendarParser()

        for resp in responses {
            if let calendarData = resp.properties.first(where: { $0.name == "calendar-data" })?.value,
               let data = calendarData.data(using: .utf8) {
                let ical = try await icalParser.parse(data)
                events.append(contentsOf: ical.events)
            }
        }

        return events
    }

    /// Create event in calendar
    public func createEvent(_ event: VEvent, in calendar: Calendar) async throws -> VEvent {
        let ical = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let data = try await serializer.serialize(ical)

        let eventURL = calendar.url.appendingPathComponent("\(event.uid).ics")

        let webdav = WebDAVOperations(client: httpClient)
        let etag = try await webdav.put(data, at: eventURL, contentType: "text/calendar; charset=utf-8")

        var createdEvent = event
        // Store etag somewhere if needed
        return createdEvent
    }

    /// Update event
    public func updateEvent(_ event: VEvent, in calendar: Calendar, etag: String) async throws {
        let ical = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let data = try await serializer.serialize(ical)

        let eventURL = calendar.url.appendingPathComponent("\(event.uid).ics")

        let webdav = WebDAVOperations(client: httpClient)
        _ = try await webdav.put(data, at: eventURL, contentType: "text/calendar; charset=utf-8", ifMatch: etag)
    }

    /// Delete event
    public func deleteEvent(uid: String, from calendar: Calendar) async throws {
        let eventURL = calendar.url.appendingPathComponent("\(uid).ics")

        let webdav = WebDAVOperations(client: httpClient)
        try await webdav.delete(at: eventURL)
    }

    private func buildCalendarQuery(start: Date, end: Date) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
          <D:prop>
            <D:getetag/>
            <C:calendar-data/>
          </D:prop>
          <C:filter>
            <C:comp-filter name="VCALENDAR">
              <C:comp-filter name="VEVENT">
                <C:time-range start="\(start.toICalendarFormat())" end="\(end.toICalendarFormat())"/>
              </C:comp-filter>
            </C:comp-filter>
          </C:filter>
        </C:calendar-query>
        """

        return xml.data(using: .utf8)!
    }
}

public struct Calendar: Sendable {
    public let url: URL
    public let displayName: String
    public let ctag: String?

    public init(url: URL, displayName: String, ctag: String?) {
        self.url = url
        self.displayName = displayName
        self.ctag = ctag
    }
}
```

---

## Phase 8: CardDAV Implementation

Create similar implementation for CardDAV following the CalDAV pattern.

---

## Phase 9: Server-Specific Implementations

### Step 9.1: iCloud Configuration

Create helper for iCloud setup:

```swift
public extension CalDAVClient {
    static func iCloud(username: String, appSpecificPassword: String) -> CalDAVClient {
        let baseClient = AlamofireHTTPClient()
        let auth = Authentication.basic(username: username, password: appSpecificPassword)
        let authedClient = AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)

        return CalDAVClient(
            httpClient: authedClient,
            baseURL: URL(string: "https://caldav.icloud.com")!
        )
    }
}
```

### Step 9.2: Google Configuration

Implement OAuth 2.0 flow for Google.

### Step 9.3: Server Detection

Implement server capability detection to adjust behavior.

---

## Phase 10: Synchronization

### Step 10.1: Sync Token Support

Implement efficient sync using sync-tokens (RFC 6578).

### Step 10.2: ETag-Based Sync

Fallback to ETag comparison when sync-tokens aren't available.

### Step 10.3: Conflict Resolution

Implement conflict detection and resolution strategies.

---

## Phase 11: Advanced Features

### Step 11.1: Recurrence Engine

Implement recurrence rule calculation (RRULE expansion).

### Step 11.2: Timezone Support

Comprehensive timezone handling.

### Step 11.3: Scheduling (RFC 6638)

Implement scheduling extensions for invitations and responses.

---

## Phase 12: Testing and Documentation

### Step 12.1: Unit Tests

Write comprehensive unit tests for all components.

### Step 12.2: Integration Tests

Test against real servers (iCloud, Google, self-hosted).

### Step 12.3: DocC Documentation

Add comprehensive documentation comments.

### Step 12.4: Example App

Create sample iOS/macOS app demonstrating usage.

---

## Success Criteria

The implementation is complete when:

- [ ] All WebDAV methods implemented (PROPFIND, PUT, DELETE, etc.)
- [ ] iCalendar parser handles all components (VEVENT, VTODO, VTIMEZONE)
- [ ] vCard parser handles vCard 3.0 and 4.0
- [ ] CalDAV client can list calendars and CRUD events
- [ ] CardDAV client can list address books and CRUD contacts
- [ ] Works with iCloud (with app-specific passwords)
- [ ] Works with Google Calendar (with OAuth 2.0)
- [ ] Works with self-hosted servers (Nextcloud, Radicale)
- [ ] Efficient sync with sync-tokens
- [ ] Comprehensive unit test coverage (>80%)
- [ ] Integration tests pass against real servers
- [ ] Full DocC documentation
- [ ] Example app demonstrates key features
- [ ] Swift 6.0 strict concurrency compliance
- [ ] No force unwraps or force casts
- [ ] All public APIs are documented
- [ ] README with quick start guide

---

## Execution Notes for LLM Agent

1. **Work systematically through phases** - complete each phase before moving to next
2. **Test continuously** - run `swift test` after each significant change
3. **Follow Swift 6.0 best practices** - use async/await, actors, Sendable
4. **Handle errors properly** - use typed errors, provide context
5. **Document as you go** - add DocC comments to all public APIs
6. **Use existing patterns** - reference LIBRARY_ANALYSIS.md for proven approaches
7. **Verify against RFCs** - consult RFC_STANDARDS.md when implementing protocols
8. **Test with real servers** - use SERVER_IMPLEMENTATIONS.md for server-specific testing
9. **No shortcuts** - implement features completely and correctly
10. **Ask for clarification** if requirements are unclear

Remember: This is a production framework that developers will rely on. Quality and correctness are paramount.
