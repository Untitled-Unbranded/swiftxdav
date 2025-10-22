# ``SwiftXDAV``

A modern Swift framework for CalDAV, CardDAV, and WebDAV integration across all Apple platforms.

## Overview

SwiftXDAV provides a complete, type-safe implementation of CalDAV (RFC 4791), CardDAV (RFC 6352), and WebDAV (RFC 4918) protocols for iOS, macOS, tvOS, watchOS, and visionOS. The framework includes full parsers for iCalendar (RFC 5545) and vCard (RFC 6350) formats.

Built with Swift 6.0 and modern concurrency, SwiftXDAV offers:

- **Native Swift Implementation**: No dependencies on legacy C libraries or Java/Kotlin code
- **Strict Concurrency**: Full Swift 6.0 strict concurrency compliance with actors and async/await
- **Type Safety**: Comprehensive error handling with typed throws
- **Server Compatibility**: Works with iCloud, Google Calendar/Contacts, Microsoft Exchange, and self-hosted servers (Nextcloud, Radicale, SOGo, Baikal)
- **Efficient Syncing**: Support for sync-tokens and ETags to minimize data transfer
- **Complete Feature Set**: Recurring events, timezones, scheduling, and more

## Quick Start

### iCloud CalDAV

```swift
import SwiftXDAV

// Create a client for iCloud
let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// List calendars
let calendars = try await client.listCalendars()

// Fetch events
let events = try await client.fetchEvents(
    from: calendars.first!,
    start: Date(),
    end: Date().addingTimeInterval(86400 * 30) // 30 days
)

// Print events
for event in events {
    print("\(event.summary ?? "Untitled"): \(event.dtstart)")
}
```

### Google Calendar

```swift
import SwiftXDAV

// Create OAuth2 token manager
let tokenManager = OAuth2TokenManager(
    clientID: "your-client-id",
    clientSecret: "your-client-secret",
    redirectURI: "your-redirect-uri"
)

// Get authorization URL
let authURL = tokenManager.authorizationURL(
    scopes: ["https://www.googleapis.com/auth/calendar"]
)

// After user authorizes, exchange code for token
try await tokenManager.exchangeCode("authorization-code")

// Create client
let client = CalDAVClient.google(tokenManager: tokenManager)

// Use the client
let calendars = try await client.listCalendars()
```

### CardDAV (Contacts)

```swift
import SwiftXDAV

// Create a CardDAV client
let client = CardDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// List address books
let addressBooks = try await client.listAddressBooks()

// Fetch contacts
let contacts = try await client.fetchContacts(from: addressBooks.first!)

// Print contacts
for contact in contacts {
    print("\(contact.formattedName?.value ?? "Unknown")")
}
```

## Topics

### Essentials

- <doc:GettingStarted>
- <doc:Authentication>
- <doc:ErrorHandling>

### Guides

- <doc:CalDAVGuide>
- <doc:CardDAVGuide>

### CalDAV

- ``CalDAVClient``
- ``Calendar``
- ``VEvent``
- ``VTodo``
- ``RecurrenceRule``
- ``ICalendar``
- ``ICalendarParser``
- ``ICalendarSerializer``

### CardDAV

- ``CardDAVClient``
- ``AddressBook``
- ``VCard``
- ``VCardParser``
- ``VCardSerializer``

### WebDAV & Networking

- ``WebDAVOperations``
- ``HTTPClient``
- ``AuthenticatedHTTPClient``
- ``OAuth2HTTPClient``
- ``ServerDetector``
- ``ServerCapabilities``

### Synchronization

- ``SyncToken``
- ``SyncChange``
- ``SyncResult``
- ``ConflictResolution``

### Core Types

- ``SwiftXDAVError``
- ``DAVProperty``
- ``Resource``

### Advanced Features

- ``RecurrenceEngine``
- ``TimezoneHandler``
- ``VTimezoneParser``

## See Also

- [RFC 4918: WebDAV](https://datatracker.ietf.org/doc/html/rfc4918)
- [RFC 4791: CalDAV](https://datatracker.ietf.org/doc/html/rfc4791)
- [RFC 6352: CardDAV](https://datatracker.ietf.org/doc/html/rfc6352)
- [RFC 5545: iCalendar](https://datatracker.ietf.org/doc/html/rfc5545)
- [RFC 6350: vCard](https://datatracker.ietf.org/doc/html/rfc6350)
