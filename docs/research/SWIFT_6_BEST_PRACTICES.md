# Swift 6.0+ Best Practices for SwiftXDAV

This document outlines Swift 6.0+ best practices and modern patterns that should be applied throughout the SwiftXDAV framework implementation.

## Table of Contents

1. [Swift 6.0 Overview](#swift-60-overview)
2. [Concurrency and Threading](#concurrency-and-threading)
3. [Type Safety and Sendable](#type-safety-and-sendable)
4. [Memory Management](#memory-management)
5. [Error Handling](#error-handling)
6. [API Design](#api-design)
7. [Protocol-Oriented Programming](#protocol-oriented-programming)
8. [Package Structure](#package-structure)
9. [Testing](#testing)
10. [Documentation](#documentation)

---

## Swift 6.0 Overview

### Major Changes in Swift 6.0/6.2

**Swift 6.0** (Released 2024):
- Complete concurrency checking enabled by default
- Data race safety enforced at compile time
- Isolation regions for concurrent code verification
- Enhanced actor isolation

**Swift 6.2** (Released September 2025):
- Approachable Concurrency for progressive disclosure
- `@concurrent` attribute for explicit concurrent execution
- Default main actor isolation option
- Improved async stepping in debugger
- Enhanced Sendable checking

### Key Philosophy

Swift 6 follows a **progressive disclosure model** for concurrency:

1. **Phase 1**: Write simple, single-threaded code where everything runs sequentially by default
2. **Phase 2**: Write async code without data-race safety errors using async/await
3. **Phase 3**: Boost performance with parallelism by offloading work from the main actor

---

## Concurrency and Threading

### Approachable Concurrency (Swift 6.2)

For frameworks like SwiftXDAV that don't require UI work, start simple and add concurrency where needed.

#### Default Behavior

Programs adopting approachable concurrency are **single-threaded by default**:

```swift
// This runs on the caller's thread by default
func fetchCalendarEvents() async throws -> [CalendarEvent] {
    // Network call happens on caller's context
    let data = try await networkClient.get(url)
    return try parseEvents(data)
}
```

#### Explicit Concurrent Execution

Use `@concurrent` when you want to ensure execution on the concurrent thread pool:

```swift
// This ALWAYS runs on concurrent thread pool
@concurrent
func parseICalendarData(_ data: Data) async throws -> ICalendar {
    // Heavy parsing work offloaded from main thread
    return try ICalendarParser.parse(data)
}
```

### Async/Await Pattern

Use async/await for all asynchronous operations:

```swift
// Good - async/await
func syncCalendar() async throws {
    let events = try await fetchRemoteEvents()
    try await saveToLocalStore(events)
}

// Bad - completion handlers
func syncCalendar(completion: @escaping (Result<Void, Error>) -> Void) {
    // Avoid this pattern in new code
}
```

### Structured Concurrency

Use task groups for parallel operations:

```swift
func fetchMultipleCalendars(_ calendarURLs: [URL]) async throws -> [Calendar] {
    try await withThrowingTaskGroup(of: Calendar.self) { group in
        for url in calendarURLs {
            group.addTask {
                try await self.fetchCalendar(from: url)
            }
        }

        var calendars: [Calendar] = []
        for try await calendar in group {
            calendars.append(calendar)
        }
        return calendars
    }
}
```

### Actor Isolation

Use actors to protect mutable state:

```swift
actor CalendarCache {
    private var cache: [String: Calendar] = [:]

    func get(_ key: String) -> Calendar? {
        cache[key]
    }

    func set(_ key: String, calendar: Calendar) {
        cache[key] = calendar
    }

    func clear() {
        cache.removeAll()
    }
}

// Usage
let cache = CalendarCache()
await cache.set("work", calendar: workCalendar)
let cached = await cache.get("work")
```

### Main Actor Isolation

For code that must run on the main thread (typically UI-related):

```swift
@MainActor
class CalendarViewController {
    func updateUI(with events: [CalendarEvent]) {
        // Guaranteed to run on main thread
        self.tableView.reloadData()
    }
}

// Or per-method
class SyncManager {
    @MainActor
    func notifyUserOfSync() {
        // Show UI notification
    }

    func performSync() async {
        // Background work
        await notifyUserOfSync() // Switches to main actor
    }
}
```

---

## Type Safety and Sendable

### Sendable Types

Types that can be safely passed across concurrency boundaries must conform to `Sendable`:

```swift
// Value types are implicitly Sendable if all properties are Sendable
struct CalendarEvent: Sendable {
    let id: UUID
    let title: String
    let startDate: Date
    let endDate: Date
}

// Reference types need explicit conformance
final class ICalendarParser: @unchecked Sendable {
    // Must ensure internal synchronization
    private let lock = NSLock()
    private var state: ParserState

    // ... implementation with proper locking
}

// Actors are always Sendable
actor EventStore: Sendable {
    private var events: [CalendarEvent] = []
    // No explicit synchronization needed
}
```

### Non-Sendable Types

When working with non-Sendable types across concurrency boundaries, use isolation:

```swift
// Legacy type that can't be made Sendable
class LegacyParser {
    var state: Int = 0

    func parse(_ data: Data) -> Result {
        // mutable state, not thread-safe
    }
}

// Wrap in actor for safe concurrent access
actor ParserWrapper {
    private let parser = LegacyParser()

    func parse(_ data: Data) -> Result {
        parser.parse(data)
    }
}
```

---

## Memory Management

### Ownership and References

Use appropriate reference types:

```swift
// Strong references by default
class CalendarManager {
    let networkClient: NetworkClient // Strong reference
    let parser: ICalendarParser // Strong reference
}

// Weak references to avoid cycles
class EventObserver {
    weak var delegate: EventDelegate? // Weak reference

    func notifyUpdate() {
        delegate?.eventsDidUpdate()
    }
}

// Unowned for guaranteed non-nil references
class CalendarEvent {
    unowned let calendar: Calendar // Won't outlive calendar
}
```

### Capture Lists

Always use capture lists in closures:

```swift
// Good
class SyncManager {
    func scheduleSync() {
        Timer.scheduledTimer(withTimeInterval: 60) { [weak self] _ in
            guard let self else { return }
            self.performSync()
        }
    }
}

// Good - with async
func fetchAndProcess() async {
    await withCheckedContinuation { [weak self] continuation in
        guard let self else {
            continuation.resume(returning: nil)
            return
        }
        self.networkCall { result in
            continuation.resume(returning: result)
        }
    }
}
```

### Value Semantics

Prefer value types (structs) over reference types (classes) when possible:

```swift
// Good - value type for data model
struct CalendarEvent: Codable, Equatable {
    let id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
}

// Good - reference type for service
final class CalendarService {
    func fetchEvents() async throws -> [CalendarEvent] {
        // Returns value types
    }
}
```

---

## Error Handling

### Typed Errors (Swift 6.0+)

Use typed throws for better type safety:

```swift
enum CalDAVError: Error {
    case networkError(underlying: Error)
    case invalidResponse(statusCode: Int)
    case parsingError(String)
    case authenticationRequired
    case notFound
}

// Typed throws - caller knows exact error type
func fetchCalendar(at url: URL) async throws(CalDAVError) -> Calendar {
    guard let response = try await networkClient.get(url) else {
        throw .notFound
    }

    guard response.statusCode == 200 else {
        throw .invalidResponse(statusCode: response.statusCode)
    }

    do {
        return try parseCalendar(response.data)
    } catch {
        throw .parsingError(error.localizedDescription)
    }
}

// Caller gets precise error type
do {
    let calendar = try await fetchCalendar(at: url)
} catch let error as CalDAVError {
    switch error {
    case .authenticationRequired:
        // Handle auth
    case .notFound:
        // Handle not found
    default:
        // Handle other cases
    }
}
```

### Result Type

For non-throwing APIs, use Result:

```swift
func parseVCard(_ data: Data) -> Result<VCard, VCardError> {
    guard !data.isEmpty else {
        return .failure(.emptyData)
    }

    // Parse...
    return .success(vcard)
}

// Usage
switch parseVCard(data) {
case .success(let vcard):
    print("Parsed: \(vcard)")
case .failure(let error):
    print("Error: \(error)")
}
```

### Error Context

Provide rich error context:

```swift
struct CalDAVError: Error, LocalizedError {
    let kind: Kind
    let url: URL?
    let underlyingError: Error?

    enum Kind {
        case networkFailure
        case invalidResponse
        case parsingError
        case unauthorized
    }

    var errorDescription: String? {
        switch kind {
        case .networkFailure:
            return "Network request failed\(url.map { " for \($0)" } ?? "")"
        case .invalidResponse:
            return "Invalid response from server"
        case .parsingError:
            return "Failed to parse calendar data"
        case .unauthorized:
            return "Authentication required"
        }
    }

    var recoverySuggestion: String? {
        switch kind {
        case .networkFailure:
            return "Check your internet connection and try again"
        case .unauthorized:
            return "Please log in again"
        default:
            return nil
        }
    }
}
```

---

## API Design

### Naming Conventions

Follow Swift API Design Guidelines:

```swift
// Good - clear, concise naming
func fetchEvents(from calendar: Calendar, in dateRange: DateInterval) async throws -> [Event]
func createEvent(_ event: Event, in calendar: Calendar) async throws
func deleteEvent(withID id: UUID) async throws

// Bad - unclear or verbose
func getEventsFromCalendarInDateRange(cal: Calendar, range: DateInterval) async throws -> [Event]
func addNewEventToCalendar(event: Event, calendar: Calendar) async throws
```

### Method Arguments

Use argument labels for clarity:

```swift
// Good - clear roles
func search(for text: String, in calendar: Calendar, options: SearchOptions) async throws -> [Event]

// Good - boolean parameters
func sync(calendar: Calendar, deleteRemoved: Bool, createMissing: Bool) async throws

// Bad - unclear parameters
func sync(_ calendar: Calendar, _ delete: Bool, _ create: Bool) async throws
```

### Default Arguments

Use default arguments for optional behavior:

```swift
func fetchEvents(
    from calendar: Calendar,
    in dateRange: DateInterval? = nil,
    includeRecurring: Bool = true,
    limit: Int? = nil
) async throws -> [Event] {
    // Implementation
}

// Usage
let allEvents = try await fetchEvents(from: calendar)
let limitedEvents = try await fetchEvents(from: calendar, limit: 100)
```

### Builder Pattern

For complex configuration, use builder pattern:

```swift
struct CalDAVClientConfiguration {
    var baseURL: URL
    var timeout: TimeInterval = 30
    var authentication: Authentication?
    var cachePolicy: CachePolicy = .default
    var retryPolicy: RetryPolicy = .default

    static func make(_ configure: (inout Self) -> Void) -> Self {
        var config = Self(baseURL: URL(string: "https://")!)
        configure(&config)
        return config
    }
}

// Usage
let config = CalDAVClientConfiguration.make { config in
    config.baseURL = URL(string: "https://caldav.icloud.com")!
    config.timeout = 60
    config.authentication = .basic(username: "user", password: "pass")
}
```

---

## Protocol-Oriented Programming

### Protocol Design

Design protocols for flexibility and testability:

```swift
// Protocol for network layer
protocol NetworkClient: Sendable {
    func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse
}

// Protocol for parser
protocol ICalendarParser: Sendable {
    func parse(_ data: Data) async throws -> ICalendar
    func serialize(_ calendar: ICalendar) async throws -> Data
}

// Protocol for storage
protocol EventStore: Sendable {
    func save(_ event: Event) async throws
    func fetch(id: UUID) async throws -> Event?
    func fetchAll(in calendar: Calendar) async throws -> [Event]
    func delete(id: UUID) async throws
}
```

### Protocol Composition

Combine protocols for rich capabilities:

```swift
protocol Identifiable {
    var id: UUID { get }
}

protocol Timestamped {
    var createdAt: Date { get }
    var updatedAt: Date { get }
}

protocol Syncable: Identifiable, Timestamped {
    var etag: String? { get }
    var syncStatus: SyncStatus { get }
}

struct CalendarEvent: Syncable {
    let id: UUID
    let createdAt: Date
    var updatedAt: Date
    var etag: String?
    var syncStatus: SyncStatus

    // Event-specific properties
    var title: String
    var startDate: Date
    var endDate: Date
}
```

### Protocol Extensions

Provide default implementations:

```swift
protocol CalDAVResource {
    var url: URL { get }
    var etag: String? { get }
}

extension CalDAVResource {
    func needsSync(comparedTo remote: Self) -> Bool {
        guard let localETag = self.etag,
              let remoteETag = remote.etag else {
            return true
        }
        return localETag != remoteETag
    }
}

// All conforming types get this for free
```

---

## Package Structure

### Swift Package Manager

Organize as a Swift Package with clear module boundaries:

```
SwiftXDAV/
├── Package.swift
├── README.md
├── Sources/
│   ├── SwiftXDAV/              # Main module (umbrella)
│   │   └── SwiftXDAV.swift
│   ├── SwiftXDAVCore/          # Core types and protocols
│   │   ├── Models/
│   │   ├── Protocols/
│   │   └── Utilities/
│   ├── SwiftXDAVNetwork/       # Networking layer
│   │   ├── HTTPClient/
│   │   ├── WebDAV/
│   │   └── Authentication/
│   ├── SwiftXDAVCalendar/      # CalDAV implementation
│   │   ├── Models/
│   │   ├── Client/
│   │   └── Parser/
│   ├── SwiftXDAVContacts/      # CardDAV implementation
│   │   ├── Models/
│   │   ├── Client/
│   │   └── Parser/
│   └── SwiftXDAVStorage/       # Local storage (optional)
│       ├── Cache/
│       └── Database/
├── Tests/
│   ├── SwiftXDAVCoreTests/
│   ├── SwiftXDAVNetworkTests/
│   ├── SwiftXDAVCalendarTests/
│   └── SwiftXDAVContactsTests/
└── docs/
```

### Package.swift Example

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
        .library(
            name: "SwiftXDAV",
            targets: ["SwiftXDAV"]),
        .library(
            name: "SwiftXDAVCalendar",
            targets: ["SwiftXDAVCalendar"]),
        .library(
            name: "SwiftXDAVContacts",
            targets: ["SwiftXDAVContacts"]),
    ],
    dependencies: [
        .package(url: "https://github.com/Alamofire/Alamofire.git", from: "5.9.0"),
        .package(url: "https://github.com/Flight-School/AnyCodable.git", from: "0.6.0"),
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
        .testTarget(
            name: "SwiftXDAVCoreTests",
            dependencies: ["SwiftXDAVCore"]
        ),
        .testTarget(
            name: "SwiftXDAVNetworkTests",
            dependencies: ["SwiftXDAVNetwork"]
        ),
        .testTarget(
            name: "SwiftXDAVCalendarTests",
            dependencies: ["SwiftXDAVCalendar"]
        ),
        .testTarget(
            name: "SwiftXDAVContactsTests",
            dependencies: ["SwiftXDAVContacts"]
        ),
    ],
    swiftLanguageVersions: [.v6]
)
```

### Module Organization

**SwiftXDAVCore**: Foundation types, protocols, utilities
- `Models/`: Shared data models
- `Protocols/`: Core protocols
- `Utilities/`: Helper types and extensions

**SwiftXDAVNetwork**: HTTP and WebDAV networking
- `HTTPClient/`: HTTP client implementation
- `WebDAV/`: WebDAV protocol implementation
- `Authentication/`: Auth mechanisms (Basic, OAuth, etc.)

**SwiftXDAVCalendar**: CalDAV and iCalendar
- `Models/`: Event, Calendar, Todo, etc.
- `Client/`: CalDAV client
- `Parser/`: iCalendar parser/serializer

**SwiftXDAVContacts**: CardDAV and vCard
- `Models/`: Contact, VCard, etc.
- `Client/`: CardDAV client
- `Parser/`: vCard parser/serializer

---

## Testing

### Unit Testing

Write comprehensive unit tests:

```swift
import XCTest
@testable import SwiftXDAVCalendar

final class ICalendarParserTests: XCTestCase {
    var parser: ICalendarParser!

    override func setUp() async throws {
        parser = ICalendarParser()
    }

    func testParseBasicEvent() async throws {
        let icalData = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test//EN
        BEGIN:VEVENT
        UID:test-event-123
        DTSTART:20250611T090000Z
        DTEND:20250611T100000Z
        SUMMARY:Test Event
        END:VEVENT
        END:VCALENDAR
        """.data(using: .utf8)!

        let calendar = try await parser.parse(icalData)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].summary, "Test Event")
    }

    func testParseRecurringEvent() async throws {
        // Test recurrence
    }

    func testParseInvalidData() async {
        let invalidData = "INVALID DATA".data(using: .utf8)!

        await assertThrowsError(
            try await parser.parse(invalidData)
        ) { error in
            XCTAssertTrue(error is ICalendarParserError)
        }
    }
}

// Helper for async throwing tests
func assertThrowsError<T>(
    _ expression: @autoclosure () async throws -> T,
    _ errorHandler: (Error) -> Void = { _ in }
) async {
    do {
        _ = try await expression()
        XCTFail("Expected error to be thrown")
    } catch {
        errorHandler(error)
    }
}
```

### Mock Objects

Create protocol-based mocks:

```swift
actor MockNetworkClient: NetworkClient {
    var responses: [URL: HTTPResponse] = [:]
    var requestHistory: [HTTPRequest] = []

    func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        let request = HTTPRequest(method: method, url: url, headers: headers, body: body)
        requestHistory.append(request)

        guard let response = responses[url] else {
            throw NetworkError.notFound
        }

        return response
    }

    func setResponse(_ response: HTTPResponse, for url: URL) {
        responses[url] = response
    }
}

// Usage in tests
func testFetchCalendar() async throws {
    let mockClient = MockNetworkClient()
    await mockClient.setResponse(
        HTTPResponse(statusCode: 200, data: sampleCalendarData),
        for: calendarURL
    )

    let client = CalDAVClient(networkClient: mockClient)
    let calendar = try await client.fetchCalendar(at: calendarURL)

    XCTAssertNotNil(calendar)
}
```

### Integration Testing

Test real network interactions (marked as integration tests):

```swift
final class CalDAVIntegrationTests: XCTestCase {
    func testRealServerConnection() async throws {
        // Skip if no credentials
        try XCTSkipUnless(
            ProcessInfo.processInfo.environment["CALDAV_TEST_URL"] != nil,
            "Set CALDAV_TEST_URL to run integration tests"
        )

        let url = URL(string: ProcessInfo.processInfo.environment["CALDAV_TEST_URL"]!)!
        let client = CalDAVClient(baseURL: url)

        let calendars = try await client.listCalendars()
        XCTAssertFalse(calendars.isEmpty)
    }
}
```

---

## Documentation

### DocC Documentation

Use DocC for comprehensive documentation:

```swift
/// A client for interacting with CalDAV servers.
///
/// `CalDAVClient` provides a high-level interface for:
/// - Discovering calendars
/// - Fetching and creating events
/// - Syncing calendar data
/// - Managing calendar properties
///
/// ## Usage
///
/// Create a client with your server URL and credentials:
///
/// ```swift
/// let config = CalDAVClientConfiguration.make { config in
///     config.baseURL = URL(string: "https://caldav.example.com")!
///     config.authentication = .basic(username: "user", password: "pass")
/// }
///
/// let client = CalDAVClient(configuration: config)
/// ```
///
/// Fetch calendars:
///
/// ```swift
/// let calendars = try await client.listCalendars()
/// for calendar in calendars {
///     print("Calendar: \(calendar.displayName)")
/// }
/// ```
///
/// ## Topics
///
/// ### Creating a Client
/// - ``init(configuration:)``
/// - ``CalDAVClientConfiguration``
///
/// ### Discovering Calendars
/// - ``listCalendars()``
/// - ``findCalendar(withID:)``
///
/// ### Working with Events
/// - ``fetchEvents(from:in:)``
/// - ``createEvent(_:in:)``
/// - ``updateEvent(_:)``
/// - ``deleteEvent(withID:in:)``
///
/// ### Synchronization
/// - ``syncCalendar(_:)``
/// - ``SyncResult``
///
public final class CalDAVClient: Sendable {
    /// The configuration for this client.
    public let configuration: CalDAVClientConfiguration

    /// Creates a new CalDAV client with the specified configuration.
    ///
    /// - Parameter configuration: The configuration to use for this client.
    public init(configuration: CalDAVClientConfiguration) {
        self.configuration = configuration
    }

    /// Lists all calendars available to the authenticated user.
    ///
    /// - Returns: An array of ``Calendar`` objects.
    /// - Throws: ``CalDAVError`` if the request fails.
    ///
    /// ## Example
    ///
    /// ```swift
    /// let calendars = try await client.listCalendars()
    /// for calendar in calendars {
    ///     print("Found calendar: \(calendar.displayName)")
    /// }
    /// ```
    public func listCalendars() async throws -> [Calendar] {
        // Implementation
    }
}
```

### Inline Documentation

Document complex algorithms:

```swift
/// Calculates occurrences of a recurring event within a date range.
///
/// This method implements the recurrence expansion algorithm from RFC 5545.
/// It handles complex recurrence patterns including:
/// - Multiple frequency types (daily, weekly, monthly, yearly)
/// - By-rules (BYDAY, BYMONTH, etc.)
/// - Exception dates (EXDATE)
/// - Exception modifications (EXDATE with RECURRENCE-ID)
///
/// - Parameters:
///   - event: The recurring event to expand.
///   - range: The date range to generate occurrences within.
/// - Returns: An array of ``EventOccurrence`` objects representing each occurrence.
/// - Complexity: O(n) where n is the number of occurrences in the range.
///
private func expandRecurrence(
    for event: Event,
    in range: DateInterval
) -> [EventOccurrence] {
    // Step 1: Parse RRULE
    guard let rrule = event.recurrenceRule else {
        return [EventOccurrence(event: event, date: event.startDate)]
    }

    // Step 2: Generate candidates based on frequency
    let candidates = generateCandidates(from: event.startDate, rrule: rrule, until: range.end)

    // Step 3: Filter by by-rules
    let filtered = applyByRules(candidates, rrule: rrule)

    // Step 4: Remove exception dates
    let withoutExceptions = filtered.filter { !event.exceptionDates.contains($0) }

    // Step 5: Apply COUNT or UNTIL limits
    let limited = applyLimits(withoutExceptions, rrule: rrule)

    return limited.map { EventOccurrence(event: event, date: $0) }
}
```

---

## Summary

### Key Takeaways

1. **Use Swift 6.0+ features**: Leverage strict concurrency, typed throws, and modern patterns
2. **Default to simplicity**: Start with single-threaded code, add concurrency where needed
3. **Embrace async/await**: Use structured concurrency for all asynchronous operations
4. **Make it Sendable**: Ensure thread-safe data passing with Sendable conformance
5. **Protocol-oriented**: Design with protocols for flexibility and testability
6. **Value semantics**: Prefer structs over classes for data models
7. **Comprehensive docs**: Document all public APIs with DocC
8. **Test thoroughly**: Write unit tests, integration tests, and use mocks

### Recommended Dependencies

- **Alamofire**: For HTTP networking (battle-tested, supports custom methods)
- **XMLCoder**: For XML encoding/decoding (or use native XMLParser for more control)
- Native Swift types wherever possible

### Anti-Patterns to Avoid

- ❌ Completion handlers (use async/await instead)
- ❌ Global mutable state (use actors)
- ❌ Force unwrapping (use guard/if let)
- ❌ Stringly-typed APIs (use enums and types)
- ❌ Large monolithic types (break into focused components)
- ❌ Missing error context (provide rich error information)

### Next Steps

1. Set up Swift Package structure
2. Implement core protocols and types
3. Build network layer with WebDAV support
4. Implement iCalendar and vCard parsers
5. Build CalDAV and CardDAV clients
6. Add comprehensive tests
7. Document everything with DocC
