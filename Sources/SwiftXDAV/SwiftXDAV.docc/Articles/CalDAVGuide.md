# CalDAV Guide

Master CalDAV operations including calendar discovery, event management, recurring events, and synchronization.

## Overview

CalDAV (Calendar Distributed Authoring and Versioning) is a protocol defined in RFC 4791 that extends WebDAV to provide calendar access and management. SwiftXDAV provides a complete implementation with support for:

- Calendar discovery
- Event CRUD operations (Create, Read, Update, Delete)
- Recurring events with complex recurrence rules
- Timezone handling
- Alarms and reminders
- Efficient synchronization with sync-tokens
- Free/busy queries

## Calendar Discovery

### Discovering the Calendar Home

CalDAV uses a discovery process to find where calendars are stored:

```swift
let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// Discover principal URL (identifies the user)
let principalURL = try await client.discoverPrincipal()
print("Principal: \(principalURL)")

// Discover calendar home URL (where calendars are stored)
let calendarHomeURL = try await client.discoverCalendarHome()
print("Calendar Home: \(calendarHomeURL)")
```

### Listing Calendars

```swift
// List all calendars (automatic discovery)
let calendars = try await client.listCalendars()

// Or list calendars at a specific URL
let calendarsAtHome = try await client.listCalendars(at: calendarHomeURL)

for calendar in calendars {
    print("📅 \(calendar.displayName)")
    print("   URL: \(calendar.url)")
    print("   Color: \(calendar.color ?? "default")")
    print("   Components: \(calendar.supportedComponents)")
    print("   CTag: \(calendar.ctag ?? "none")")
}
```

### Calendar Properties

Calendars include various properties:

```swift
let calendar = calendars.first!

// Display properties
calendar.displayName // "Work Calendar"
calendar.color // "#FF5733"
calendar.description // "My work events"

// Capabilities
calendar.supportedComponents // [.event, .todo]
calendar.supportedReports // Which queries are supported

// Synchronization
calendar.ctag // Collection tag - changes when any event changes
calendar.syncToken // Token for incremental sync
```

## Working with Events

### Fetching Events

```swift
// Fetch all events in a date range
let start = Date()
let end = start.addingTimeInterval(86400 * 30) // 30 days

let events = try await client.fetchEvents(
    from: calendar,
    start: start,
    end: end
)

for event in events {
    print("📆 \(event.summary ?? "Untitled")")
    if let dtstart = event.dtstart {
        print("   Start: \(dtstart)")
    }
    if let dtend = event.dtend {
        print("   End: \(dtend)")
    }
    if let location = event.location {
        print("   Location: \(location)")
    }
}
```

### Fetching a Single Event

```swift
// Fetch by UID
let event = try await client.fetchEvent(
    uid: "12345-67890-ABCDEF",
    from: calendar
)

// Fetch with ETag (for safe updates)
let (event, etag) = try await client.fetchEvent(
    uid: "12345-67890-ABCDEF",
    from: calendar
)
```

### Creating Events

#### Simple Event

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

#### All-Day Event

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Company Holiday"
event.dtstart = Date() // Will be treated as date-only
event.isAllDay = true

try await client.createEvent(event, in: calendar)
```

#### Event with Attendees

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Project Review"
event.dtstart = Date().addingTimeInterval(3600)
event.dtend = event.dtstart?.addingTimeInterval(3600)
event.organizer = VEvent.Organizer(
    email: "organizer@example.com",
    commonName: "John Doe"
)
event.attendees = [
    VEvent.Attendee(
        email: "alice@example.com",
        commonName: "Alice Smith",
        role: .required,
        status: .needsAction
    ),
    VEvent.Attendee(
        email: "bob@example.com",
        commonName: "Bob Jones",
        role: .optional,
        status: .needsAction
    )
]

try await client.createEvent(event, in: calendar)
```

#### Event with Alarms

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Important Meeting"
event.dtstart = Date().addingTimeInterval(3600)
event.dtend = event.dtstart?.addingTimeInterval(3600)

// Add alarm 15 minutes before
event.alarms = [
    VAlarm(
        action: .display,
        trigger: .relative(seconds: -900), // -15 minutes
        description: "Meeting starts in 15 minutes"
    )
]

try await client.createEvent(event, in: calendar)
```

### Updating Events

Always use ETags to prevent conflicts:

```swift
// Fetch event with current ETag
let (event, etag) = try await client.fetchEvent(
    uid: event.uid,
    from: calendar
)

// Modify event
var updatedEvent = event
updatedEvent.summary = "Updated: \(event.summary ?? "")"
updatedEvent.location = "New Location"

// Update with ETag (fails if event was modified by someone else)
do {
    try await client.updateEvent(updatedEvent, in: calendar, etag: etag)
    print("Event updated successfully")
} catch SwiftXDAVError.preconditionFailed {
    print("Event was modified by someone else, please refetch")
}
```

### Deleting Events

```swift
// Delete by UID
try await client.deleteEvent(uid: event.uid, from: calendar)
```

## Recurring Events

### Creating Recurring Events

#### Daily Recurrence

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Daily Standup"
event.dtstart = Date().addingTimeInterval(3600)
event.dtend = event.dtstart?.addingTimeInterval(1800) // 30 minutes

// Recur daily for 30 occurrences
event.recurrenceRule = RecurrenceRule(
    frequency: .daily,
    count: 30
)

try await client.createEvent(event, in: calendar)
```

#### Weekly Recurrence

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Team Sync"
event.dtstart = Date() // Monday
event.dtend = event.dtstart?.addingTimeInterval(3600)

// Every Monday and Wednesday for 6 months
event.recurrenceRule = RecurrenceRule(
    frequency: .weekly,
    interval: 1,
    byDay: [.monday, .wednesday],
    until: Date().addingTimeInterval(86400 * 180)
)

try await client.createEvent(event, in: calendar)
```

#### Monthly Recurrence

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Monthly Report"
event.dtstart = Date() // e.g., January 15th

// First Monday of each month
event.recurrenceRule = RecurrenceRule(
    frequency: .monthly,
    byDay: [.first(.monday)]
)

try await client.createEvent(event, in: calendar)
```

#### Complex Recurrence

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Quarterly Board Meeting"
event.dtstart = Date()

// Every 3 months, on the 2nd Friday, for 2 years
event.recurrenceRule = RecurrenceRule(
    frequency: .monthly,
    interval: 3,
    byDay: [.second(.friday)],
    count: 8 // 2 years = 8 quarters
)

try await client.createEvent(event, in: calendar)
```

### Exception Dates

Exclude specific occurrences:

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Daily Meeting"
event.dtstart = Date()
event.recurrenceRule = RecurrenceRule(frequency: .daily, count: 30)

// Exclude specific dates (e.g., holidays)
event.exdates = [
    Date().addingTimeInterval(86400 * 7), // Next week
    Date().addingTimeInterval(86400 * 14) // Two weeks from now
]

try await client.createEvent(event, in: calendar)
```

### Expanding Recurrence

Generate all occurrences of a recurring event:

```swift
let recurrenceEngine = RecurrenceEngine()

let occurrences = recurrenceEngine.occurrences(
    for: event,
    in: DateInterval(start: startDate, end: endDate)
)

for occurrence in occurrences {
    print("Occurrence at: \(occurrence)")
}
```

## Synchronization

### Full Sync (Initial)

```swift
// First sync - fetch all events
let result = try await client.sync(calendar: calendar, syncToken: nil)

print("Changes: \(result.changes.count)")
for change in result.changes {
    switch change {
    case .added(let event):
        // Store event in local database
        print("New event: \(event.summary ?? "Untitled")")
    case .modified(let event):
        // Update event in local database
        print("Updated event: \(event.summary ?? "Untitled")")
    case .deleted(let uid):
        // Delete event from local database
        print("Deleted event: \(uid)")
    }
}

// Save sync token for next sync
UserDefaults.standard.set(result.syncToken?.token, forKey: "calendarSyncToken")
```

### Incremental Sync

```swift
// Load previous sync token
let previousToken: String? = UserDefaults.standard.string(forKey: "calendarSyncToken")
let syncToken = previousToken.map { SyncToken(token: $0) }

// Perform incremental sync - only fetches changes
let result = try await client.sync(calendar: calendar, syncToken: syncToken)

print("Changes since last sync: \(result.changes.count)")

// Process changes
for change in result.changes {
    switch change {
    case .added(let event):
        localDatabase.insert(event)
    case .modified(let event):
        localDatabase.update(event)
    case .deleted(let uid):
        localDatabase.delete(uid)
    }
}

// Save new sync token
UserDefaults.standard.set(result.syncToken?.token, forKey: "calendarSyncToken")
```

### Handling Sync Conflicts

```swift
// If sync token is invalid (too old or server doesn't support it)
do {
    let result = try await client.sync(calendar: calendar, syncToken: oldToken)
    // Process changes
} catch SwiftXDAVError.syncTokenInvalid {
    print("Sync token invalid, performing full sync")

    // Fall back to full sync
    let result = try await client.sync(calendar: calendar, syncToken: nil)

    // Replace entire local database
    localDatabase.deleteAll()
    for change in result.changes {
        if case .added(let event) = change {
            localDatabase.insert(event)
        }
    }
}
```

## Timezone Handling

### Events with Timezones

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "International Conference Call"
event.dtstart = Date()
event.dtend = event.dtstart?.addingTimeInterval(3600)

// Explicitly set timezone
event.timezone = TimeZone(identifier: "America/New_York")

try await client.createEvent(event, in: calendar)
```

### Floating Time Events

Events without timezone (interpreted in user's local time):

```swift
var event = VEvent()
event.uid = UUID().uuidString
event.summary = "Local Event"
event.dtstart = Date()
event.dtend = event.dtstart?.addingTimeInterval(3600)
event.timezone = nil // Floating time

try await client.createEvent(event, in: calendar)
```

## Best Practices

### 1. Always Use ETags for Updates

```swift
// ✅ Good
let (event, etag) = try await client.fetchEvent(uid: uid, from: calendar)
var updated = event
updated.summary = "New Summary"
try await client.updateEvent(updated, in: calendar, etag: etag)

// ❌ Bad - race condition possible
var event = try await client.fetchEvent(uid: uid, from: calendar)
event.summary = "New Summary"
try await client.updateEvent(event, in: calendar, etag: nil)
```

### 2. Use Sync Tokens for Efficiency

```swift
// ✅ Good - only fetches changes
let result = try await client.sync(calendar: calendar, syncToken: lastToken)

// ❌ Bad - fetches all events every time
let events = try await client.fetchEvents(from: calendar, start: .distantPast, end: .distantFuture)
```

### 3. Handle Sync Token Invalidation

```swift
do {
    let result = try await client.sync(calendar: calendar, syncToken: token)
} catch SwiftXDAVError.syncTokenInvalid {
    // Fall back to full sync
    let result = try await client.sync(calendar: calendar, syncToken: nil)
}
```

### 4. Cache Calendar Properties

```swift
// Cache calendar list and sync tokens
struct CalendarCache: Codable {
    var calendars: [Calendar]
    var syncTokens: [String: String] // calendar URL -> sync token
    var lastUpdate: Date
}
```

### 5. Batch Operations When Possible

```swift
// Instead of fetching events one by one
let event1 = try await client.fetchEvent(uid: uid1, from: calendar)
let event2 = try await client.fetchEvent(uid: uid2, from: calendar)

// Fetch all events in a range
let events = try await client.fetchEvents(from: calendar, start: start, end: end)
```

## See Also

- ``CalDAVClient``
- ``VEvent``
- ``RecurrenceRule``
- ``RecurrenceEngine``
- ``TimezoneHandler``
- <doc:GettingStarted>
- <doc:ErrorHandling>
