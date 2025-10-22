# Getting Started with SwiftXDAV

Learn how to integrate SwiftXDAV into your project and start working with CalDAV and CardDAV servers.

## Installation

### Swift Package Manager

Add SwiftXDAV to your `Package.swift`:

```swift
dependencies: [
    .package(url: "https://github.com/yourusername/swiftxdav.git", from: "1.0.0")
]
```

Or in Xcode:

1. Go to **File > Add Package Dependencies**
2. Enter the repository URL
3. Choose your version requirements

## Basic Setup

### iCloud CalDAV

To connect to iCloud CalDAV, you'll need an app-specific password:

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Navigate to **Security > App-Specific Passwords**
3. Generate a new password for your app

```swift
import SwiftXDAV

let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// Discover and list calendars
let calendars = try await client.listCalendars()
print("Found \(calendars.count) calendars")
```

### Google Calendar

For Google Calendar, you'll need OAuth 2.0 credentials:

1. Create a project in [Google Cloud Console](https://console.cloud.google.com)
2. Enable the **Calendar API**
3. Create OAuth 2.0 credentials
4. Add your redirect URI

```swift
import SwiftXDAV

// Create token manager
let tokenManager = OAuth2TokenManager(
    clientID: "your-client-id.apps.googleusercontent.com",
    clientSecret: "your-client-secret",
    redirectURI: "your-app://oauth/callback"
)

// Get authorization URL and open in browser
let authURL = tokenManager.authorizationURL(
    scopes: ["https://www.googleapis.com/auth/calendar"]
)

// After user authorizes, exchange code for token
try await tokenManager.exchangeCode("authorization-code-from-redirect")

// Create client
let client = CalDAVClient.google(tokenManager: tokenManager)
```

### Self-Hosted Servers

For self-hosted servers (Nextcloud, Radicale, SOGo, Baikal):

```swift
import SwiftXDAV

// Create HTTP client with basic authentication
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .basic(
        username: "your-username",
        password: "your-password"
    )
)

// Create CalDAV client
let client = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://your-server.com/remote.php/dav")!
)

// Or use server detection
let detector = ServerDetector(httpClient: httpClient)
let serverType = try await detector.detectServerType(
    at: URL(string: "https://your-server.com")!
)

// Create appropriate client based on server type
switch serverType {
case .nextcloud(let baseURL):
    let client = CalDAVClient(httpClient: httpClient, baseURL: baseURL)
case .radicale(let baseURL):
    let client = CalDAVClient(httpClient: httpClient, baseURL: baseURL)
// ... etc
}
```

## Working with Calendars

### List All Calendars

```swift
let calendars = try await client.listCalendars()

for calendar in calendars {
    print("Calendar: \(calendar.displayName)")
    print("  URL: \(calendar.url)")
    print("  Color: \(calendar.color ?? "none")")
    print("  Supported components: \(calendar.supportedComponents)")
}
```

### Fetch Events

```swift
// Fetch events for the next 30 days
let start = Date()
let end = start.addingTimeInterval(86400 * 30)

let events = try await client.fetchEvents(
    from: calendar,
    start: start,
    end: end
)

for event in events {
    print("\(event.summary ?? "Untitled")")
    if let dtstart = event.dtstart {
        print("  Starts: \(dtstart)")
    }
    if let location = event.location {
        print("  Location: \(location)")
    }
}
```

### Create an Event

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Team Meeting"
event.dtstart = Date().addingTimeInterval(3600) // 1 hour from now
event.dtend = event.dtstart?.addingTimeInterval(3600) // 1 hour duration
event.location = "Conference Room A"
event.description = "Quarterly planning meeting"

try await client.createEvent(event, in: calendar)
```

### Update an Event

```swift
// Fetch event with ETag
let (fetchedEvent, etag) = try await client.fetchEvent(
    uid: event.uid,
    from: calendar
)

// Modify event
var updatedEvent = fetchedEvent
updatedEvent.summary = "Updated: Team Meeting"

// Update on server (ETag prevents conflicts)
try await client.updateEvent(updatedEvent, in: calendar, etag: etag)
```

### Delete an Event

```swift
try await client.deleteEvent(uid: event.uid, from: calendar)
```

## Working with Contacts (CardDAV)

### List Address Books

```swift
let cardDAVClient = CardDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

let addressBooks = try await cardDAVClient.listAddressBooks()

for addressBook in addressBooks {
    print("Address Book: \(addressBook.displayName)")
}
```

### Fetch Contacts

```swift
let contacts = try await cardDAVClient.fetchContacts(
    from: addressBooks.first!
)

for contact in contacts {
    print("\(contact.formattedName?.value ?? "Unknown")")

    // Email addresses
    for email in contact.emails {
        print("  Email: \(email.value)")
    }

    // Phone numbers
    for phone in contact.telephones {
        print("  Phone: \(phone.value)")
    }
}
```

### Create a Contact

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "John Doe")
contact.name = VCard.Name(
    familyName: "Doe",
    givenName: "John"
)
contact.emails = [
    VCard.Email(value: "john@example.com", types: [.work])
]
contact.telephones = [
    VCard.Telephone(value: "+1-555-0123", types: [.work, .voice])
]

try await cardDAVClient.createContact(contact, in: addressBook)
```

## Synchronization

SwiftXDAV supports efficient synchronization using sync-tokens:

```swift
// Initial sync (full fetch)
let initialResult = try await client.sync(calendar: calendar, syncToken: nil)
print("Initial sync: \(initialResult.changes.count) changes")

// Save the sync token
let syncToken = initialResult.syncToken

// Later, perform incremental sync
let deltaResult = try await client.sync(
    calendar: calendar,
    syncToken: syncToken
)

// Process only changes since last sync
for change in deltaResult.changes {
    switch change {
    case .added(let event):
        print("New event: \(event.summary ?? "Untitled")")
    case .modified(let event):
        print("Updated event: \(event.summary ?? "Untitled")")
    case .deleted(let uid):
        print("Deleted event: \(uid)")
    }
}

// Save new sync token for next sync
let newSyncToken = deltaResult.syncToken
```

## Error Handling

SwiftXDAV uses typed errors for precise error handling:

```swift
do {
    let calendars = try await client.listCalendars()
    // Process calendars
} catch SwiftXDAVError.authenticationFailed {
    print("Invalid credentials")
} catch SwiftXDAVError.networkError(let underlyingError) {
    print("Network error: \(underlyingError)")
} catch SwiftXDAVError.serverError(let statusCode, let message) {
    print("Server error \(statusCode): \(message)")
} catch SwiftXDAVError.parsingError(let details) {
    print("Failed to parse response: \(details)")
} catch {
    print("Unexpected error: \(error)")
}
```

## Next Steps

- Read the <doc:CalDAVGuide> for detailed calendar operations
- Read the <doc:CardDAVGuide> for detailed contact operations
- Learn about <doc:Authentication> options
- Understand <doc:ErrorHandling> best practices

## See Also

- ``CalDAVClient``
- ``CardDAVClient``
- ``SwiftXDAVError``
