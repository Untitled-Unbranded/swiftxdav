# SwiftXDAV

A modern, Swift 6.0+ framework for CalDAV, CardDAV, and WebDAV integration on Apple platforms.

[![Swift](https://img.shields.io/badge/Swift-6.0+-orange.svg)](https://swift.org)
[![Platforms](https://img.shields.io/badge/Platforms-iOS%20|%20macOS%20|%20tvOS%20|%20watchOS%20|%20visionOS-blue.svg)](https://developer.apple.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)

## Features

### Core Capabilities

- ✅ **CalDAV Support** (RFC 4791) - Full calendar server integration
- ✅ **CardDAV Support** (RFC 6352) - Complete contact server support
- ✅ **WebDAV Foundation** (RFC 4918) - Built on standards-compliant WebDAV
- ✅ **iCalendar Parser** (RFC 5545) - Parse and generate VEVENT, VTODO, VTIMEZONE
- ✅ **vCard Parser** (RFC 6350) - Handle vCard 3.0 and 4.0 formats
- ✅ **Recurrence Engine** - Calculate recurring event instances
- ✅ **Timezone Support** - Full VTIMEZONE handling
- ✅ **Efficient Sync** - Incremental sync with sync-tokens and ETags

### Server Support

- **iCloud** - Tested with iCloud CalDAV/CardDAV (requires app-specific passwords)
- **Google** - Full support for Google Calendar and Contacts (OAuth 2.0)
- **Self-Hosted** - Works with Nextcloud, ownCloud, Radicale, SOGo, Baikal, Synology
- **Generic** - Any RFC-compliant CalDAV/CardDAV server

### Modern Swift

- **Swift 6.0+ Concurrency** - Async/await throughout, actor-based state management
- **Type-Safe** - Leverages Swift's type system for safety
- **Sendable** - Thread-safe data types for concurrent access
- **Typed Errors** - Precise error handling with context
- **Protocol-Oriented** - Flexible, testable architecture

## Requirements

- **Swift**: 6.0 or later
- **Platforms**:
  - iOS 15.0+
  - macOS 12.0+
  - tvOS 15.0+
  - watchOS 8.0+
  - visionOS 1.0+

## Installation

### Swift Package Manager

Add SwiftXDAV to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/untitled-unbranded/swiftxdav.git", from: "1.0.0")
]
```

Or in Xcode:
1. File → Add Package Dependencies...
2. Enter: `https://github.com/untitled-unbranded/swiftxdav.git`
3. Select version and add to your target

## Quick Start

### CalDAV - List Calendars and Fetch Events

```swift
import SwiftXDAVCalendar
import SwiftXDAVNetwork

// Create a CalDAV client for iCloud
let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// List all calendars
let calendars = try await client.listCalendars()
for calendar in calendars {
    print("📅 \(calendar.displayName)")
}

// Fetch events from a calendar
let calendar = calendars.first!
let start = Date()
let end = Date().addingTimeInterval(7 * 24 * 3600) // 7 days

let events = try await client.fetchEvents(
    from: calendar,
    start: start,
    end: end
)

for event in events {
    print("Event: \(event.summary ?? "Untitled")")
    print("  Start: \(event.dtstart)")
    print("  End: \(event.dtend)")
}
```

### CalDAV - Create and Update Events

```swift
// Create a new event
var event = VEvent(
    uid: UUID().uuidString,
    dtstart: Date(),
    dtend: Date().addingTimeInterval(3600),
    summary: "Team Meeting",
    description: "Discuss project progress"
)

// Create on server
let createdEventURL = try await client.createEvent(
    event,
    in: calendar
)

// Update the event
event.summary = "Team Standup (Updated)"
try await client.updateEvent(event, at: createdEventURL)

// Delete the event
try await client.deleteEvent(at: createdEventURL)
```

### CalDAV - Sync with Incremental Updates

```swift
// Initial sync
var syncToken: SyncToken? = nil
let result = try await client.syncCalendar(calendar, token: syncToken)

// Process changes
for changedEvent in result.created + result.updated {
    print("New/Updated: \(changedEvent.summary ?? "Untitled")")
}

for deletedURL in result.deleted {
    print("Deleted: \(deletedURL)")
}

// Save the new sync token for next time
syncToken = result.newSyncToken

// Later: incremental sync (only fetches changes)
let deltaResult = try await client.syncCalendar(calendar, token: syncToken)
// Process only the changes since last sync...
```

### CardDAV - Contacts Management

```swift
import SwiftXDAVContacts

// Create a CardDAV client for iCloud
let client = CardDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// List address books
let addressBooks = try await client.listAddressBooks()

// Fetch all contacts
let addressBook = addressBooks.first!
let contacts = try await client.fetchContacts(from: addressBook)

for contact in contacts {
    print("Contact: \(contact.fullName)")
    if let email = contact.emails.first {
        print("  Email: \(email.value)")
    }
}

// Create a new contact
var contact = VCard(
    uid: UUID().uuidString,
    fullName: "John Doe",
    version: .v4
)
contact.emails = [
    VCard.Email(value: "john@example.com", types: [.work])
]

let createdContactURL = try await client.createContact(
    contact,
    in: addressBook
)
```

### Google Calendar with OAuth 2.0

```swift
// Create OAuth 2.0 token manager
let tokenManager = OAuth2TokenManager.google(
    accessToken: "ya29.a0...",
    refreshToken: "1//0g...",
    clientID: "your-client-id.apps.googleusercontent.com",
    clientSecret: "your-client-secret",
    expiresAt: Date().addingTimeInterval(3600)
)

// Create authenticated HTTP client
let httpClient = OAuth2HTTPClient(
    baseClient: AlamofireHTTPClient(),
    tokenManager: tokenManager
)

// Create CalDAV client with OAuth
let client = CalDAVClient.google(oauthClient: httpClient)

// Use normally - token refresh is automatic
let calendars = try await client.listCalendars()
```

### Working with Recurring Events

```swift
import SwiftXDAVCalendar

// Create a weekly recurring event
var event = VEvent(
    uid: UUID().uuidString,
    dtstart: Date(),
    dtend: Date().addingTimeInterval(3600),
    summary: "Weekly Team Meeting"
)

// Add recurrence rule: every Monday
event.recurrenceRule = RecurrenceRule(
    frequency: .weekly,
    byDay: [.monday],
    count: 10 // 10 occurrences
)

// Calculate all occurrences in a date range
let start = Date()
let end = Date().addingTimeInterval(90 * 24 * 3600) // 90 days

let occurrences = RecurrenceEngine.calculateOccurrences(
    for: event,
    in: DateInterval(start: start, end: end)
)

print("Found \(occurrences.count) occurrences:")
for occurrence in occurrences {
    print("  - \(occurrence)")
}
```

### Parsing iCalendar Data

```swift
import SwiftXDAVCalendar

let icalData = """
BEGIN:VCALENDAR
VERSION:2.0
PRODID:-//Example//Example Calendar//EN
BEGIN:VEVENT
UID:event-123
DTSTART:20250115T140000Z
DTEND:20250115T150000Z
SUMMARY:Project Review
LOCATION:Conference Room A
DESCRIPTION:Quarterly project review meeting
END:VEVENT
END:VCALENDAR
"""

let parser = ICalendarParser()
let calendar = try await parser.parse(icalData.data(using: .utf8)!)

print("Calendar: \(calendar.prodid)")
for event in calendar.events {
    print("Event: \(event.summary ?? "Untitled")")
    print("  Start: \(event.dtstart)")
    print("  Location: \(event.location ?? "N/A")")
}
```

### Generating iCalendar Data

```swift
import SwiftXDAVCalendar

// Create calendar with event
var calendar = ICalendar(
    prodid: "-//My App//My App 1.0//EN",
    version: "2.0"
)

let event = VEvent(
    uid: UUID().uuidString,
    dtstart: Date(),
    dtend: Date().addingTimeInterval(3600),
    summary: "Important Meeting"
)

calendar.events = [event]

// Serialize to iCalendar format
let serializer = ICalendarSerializer()
let icalString = serializer.serialize(calendar)

print(icalString)
// Output:
// BEGIN:VCALENDAR
// VERSION:2.0
// PRODID:-//My App//My App 1.0//EN
// BEGIN:VEVENT
// UID:...
// DTSTART:20250121T...
// ...
```

### Server Detection and Capabilities

```swift
import SwiftXDAVNetwork

let httpClient = AlamofireHTTPClient.basicAuth(
    username: "user",
    password: "pass"
)

let detector = ServerDetector(httpClient: httpClient)
let baseURL = URL(string: "https://cloud.example.com")!

// Detect server capabilities
let capabilities = try await detector.detectCapabilities(baseURL: baseURL)

print("Server: \(capabilities.serverType)")
print("Supports CalDAV: \(capabilities.supportsCalDAV)")
print("Supports CardDAV: \(capabilities.supportsCardDAV)")
print("Supports Sync: \(capabilities.supportsSyncCollection)")
print("DAV Compliance: \(capabilities.davCompliance)")

// Get server-specific quirks for better compatibility
let quirks = ServerQuirks.quirks(for: capabilities.serverType)
print("Requires trailing slash: \(quirks.requiresTrailingSlash)")
print("Max batch size: \(quirks.maxMultiGetSize)")
```

## Architecture

SwiftXDAV is organized into modular packages:

- **SwiftXDAVCore** - Core types, protocols, errors, and utilities
- **SwiftXDAVNetwork** - HTTP client, authentication, WebDAV protocol
- **SwiftXDAVCalendar** - CalDAV client, iCalendar parser, recurrence engine
- **SwiftXDAVContacts** - CardDAV client, vCard parser

This modular design allows you to import only what you need.

## Documentation

### API Documentation

- **Online**: Full API documentation hosted at [untitled-unbranded.github.io/swiftxdav/documentation/swiftxdav/](https://untitled-unbranded.github.io/swiftxdav/documentation/swiftxdav/) (once GitHub Pages is configured)
- **Local**: Generate with `swift package generate-documentation --target SwiftXDAV`

### Guides

- **GitHub Pages Setup**: See `docs/GITHUB_PAGES_SETUP.md` for hosting documentation
- **Implementation Guide**: See `docs/research/IMPLEMENTATION_PLAN.md`
- **RFC Standards**: See `docs/research/RFC_STANDARDS.md`
- **Server Details**: See `docs/research/SERVER_IMPLEMENTATIONS.md`

## Testing

SwiftXDAV includes comprehensive unit tests (>80% coverage) and integration tests.

Run tests:
```bash
swift test
```

Run tests with coverage:
```bash
swift test --enable-code-coverage
```

## Authentication

### Basic Authentication (iCloud, Self-Hosted)

```swift
let client = AlamofireHTTPClient.basicAuth(
    username: "user",
    password: "password"
)
```

### OAuth 2.0 (Google)

```swift
let tokenManager = OAuth2TokenManager.google(
    accessToken: "...",
    refreshToken: "...",
    clientID: "...",
    clientSecret: "..."
)

let httpClient = OAuth2HTTPClient(
    baseClient: AlamofireHTTPClient(),
    tokenManager: tokenManager
)
```

### iCloud App-Specific Passwords

For iCloud, you must generate an app-specific password at https://appleid.apple.com:

```swift
let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)
```

## Error Handling

SwiftXDAV uses typed errors for precise handling:

```swift
do {
    let calendars = try await client.listCalendars()
} catch SwiftXDAVError.unauthorized {
    // Invalid credentials
    print("Authentication failed")
} catch SwiftXDAVError.networkError(let underlying) {
    // Network issue
    print("Network error: \(underlying)")
} catch SwiftXDAVError.parsingError(let message) {
    // Invalid data
    print("Parsing failed: \(message)")
} catch SwiftXDAVError.notFound {
    // Resource not found
    print("Calendar not found")
} catch {
    // Other errors
    print("Unexpected error: \(error)")
}
```

## Best Practices

### 1. Use Sync Tokens for Efficiency

Always use sync-collection when possible to minimize bandwidth:

```swift
// Store sync token persistently
var syncToken = loadSyncToken()

// Sync with token
let result = try await client.syncCalendar(calendar, token: syncToken)

// Save new token
saveSyncToken(result.newSyncToken)
```

### 2. Handle ETags for Conflict Resolution

Use ETags to detect and handle concurrent modifications:

```swift
// Fetch with ETag
let (event, etag) = try await client.fetchEvent(at: eventURL)

// Modify event
var modifiedEvent = event
modifiedEvent.summary = "Updated Title"

// Update with ETag check
do {
    try await client.updateEvent(
        modifiedEvent,
        at: eventURL,
        ifMatch: etag
    )
} catch SwiftXDAVError.preconditionFailed(let serverEtag) {
    // Someone else modified it
    // Fetch latest version and retry or merge
}
```

### 3. Respect Server Limits

Different servers have different batch size limits:

```swift
let capabilities = try await detector.detectCapabilities(baseURL: serverURL)
let quirks = ServerQuirks.quirks(for: capabilities.serverType)

// Use appropriate batch size
let maxBatchSize = quirks.maxMultiGetSize
```

### 4. Use Actors for Thread Safety

SwiftXDAV clients are actors - always use `await`:

```swift
// ✅ Correct
let calendars = try await client.listCalendars()

// ❌ Won't compile
let calendars = client.listCalendars() // Error: actor-isolated
```

## Platform Considerations

### iOS/iPadOS

- Use `@MainActor` for UI updates after async operations
- Consider background refresh for sync operations
- Handle app lifecycle (save sync tokens before termination)

### macOS

- Consider menu bar integration for quick access
- Use NSUserActivity for handoff between devices

### watchOS

- Keep operations lightweight (limited memory)
- Consider watch complications for quick data display

### visionOS

- Design for spatial computing experiences
- Consider immersive calendar/contact views

## Contributing

Contributions are welcome! Please:

1. Read `CLAUDE.md` for project principles
2. Follow Swift 6.0 best practices (see `docs/research/SWIFT_6_BEST_PRACTICES.md`)
3. Write comprehensive tests (maintain >80% coverage)
4. Add DocC documentation for public APIs
5. Ensure all tests pass: `swift test`

## License

MIT License - see [LICENSE](LICENSE) file for details.

## Acknowledgments

- Built on RFC standards: WebDAV (4918), CalDAV (4791), CardDAV (6352)
- Inspired by DAVx5, dav4jvm, iCal4j, and ez-vcard
- Powered by [Alamofire](https://github.com/Alamofire/Alamofire) for HTTP networking

## Support

- **Issues**: Report bugs at https://github.com/untitled-unbranded/swiftxdav/issues
- **Documentation**: Full API docs available via DocC
- **RFC Standards**: See `docs/research/` for protocol details

---

**Made with ❤️ and Swift 6.0**
