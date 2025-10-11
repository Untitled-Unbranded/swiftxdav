# Server Implementation Details

This document provides implementation details for specific CalDAV/CardDAV server platforms that SwiftXDAV must support.

## Table of Contents

1. [iCloud](#icloud)
2. [Google Calendar and Contacts](#google-calendar-and-contacts)
3. [Microsoft Exchange and Office.com](#microsoft-exchange-and-officecom)
4. [General Server Requirements](#general-server-requirements)
5. [Testing Strategy](#testing-strategy)

---

## iCloud

### Overview

Apple's iCloud provides CalDAV and CardDAV services for Apple ecosystem users. It follows standards closely but has some Apple-specific extensions and quirks.

### Authentication

**App-Specific Passwords Required**

iCloud requires app-specific passwords for third-party CalDAV/CardDAV access:
- Users cannot use their main Apple ID password
- Must generate 16-character app-specific password from https://appleid.apple.com
- Password format: `xxxx-xxxx-xxxx-xxxx`

**Authentication Method:**
- HTTP Basic Authentication
- Username: Apple ID email address
- Password: App-specific password

```swift
let credential = URLCredential(
    user: "user@icloud.com",
    password: "abcd-efgh-ijkl-mnop",
    persistence: .forSession
)
```

### Discovery

**CalDAV Endpoint:**
```
https://caldav.icloud.com
```

**CardDAV Endpoint:**
```
https://contacts.icloud.com
```

**Well-Known URLs:**
```
https://caldav.icloud.com/.well-known/caldav
https://contacts.icloud.com/.well-known/carddav
```

**Principal Discovery:**
```
PROPFIND https://caldav.icloud.com/
Depth: 0

Request body:
<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:">
  <d:prop>
    <d:current-user-principal/>
  </d:prop>
</d:propfind>

Response:
<d:current-user-principal>
  <d:href>/[UNIQUE-ID]/principal/</d:href>
</d:current-user-principal>
```

### Calendar Home Discovery

```
PROPFIND https://caldav.icloud.com/[UNIQUE-ID]/principal/
Depth: 0

Request body:
<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <c:calendar-home-set/>
  </d:prop>
</d:propfind>

Response:
<c:calendar-home-set>
  <d:href>/[UNIQUE-ID]/calendars/</d:href>
</c:calendar-home-set>
```

### Enumerating Calendars

```
PROPFIND https://caldav.icloud.com/[UNIQUE-ID]/calendars/
Depth: 1

Request body:
<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/">
  <d:prop>
    <d:resourcetype/>
    <d:displayname/>
    <cs:getctag/>
    <c:supported-calendar-component-set/>
    <c:calendar-description/>
    <c:calendar-timezone/>
  </d:prop>
</d:propfind>
```

### iCloud-Specific Properties

iCloud supports Apple calendar extensions:

**Calendar Color:**
```xml
<x1:calendar-color xmlns:x1="http://apple.com/ns/ical/">
  #FF6633FF
</x1:calendar-color>
```

**Calendar Order:**
```xml
<x1:calendar-order xmlns:x1="http://apple.com/ns/ical/">
  5
</x1:calendar-order>
```

### CardDAV Address Book Discovery

```
PROPFIND https://contacts.icloud.com/[UNIQUE-ID]/principal/
Depth: 0

Request body:
<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:card="urn:ietf:params:xml:ns:carddav">
  <d:prop>
    <card:addressbook-home-set/>
  </d:prop>
</d:propfind>

Response:
<card:addressbook-home-set>
  <d:href>/[UNIQUE-ID]/carddavhome/</d:href>
</card:addressbook-home-set>
```

### Limitations and Quirks

1. **Authentication**
   - App-specific passwords only
   - No OAuth support for CalDAV/CardDAV
   - Rate limiting on failed authentication attempts

2. **Sync Tokens**
   - Supports WebDAV Sync (RFC 6578)
   - Sync tokens are opaque strings
   - May expire; client must handle full re-sync

3. **Scheduling**
   - Full CalDAV scheduling support (RFC 6638)
   - Inbox/Outbox collections available
   - Push notifications available via Apple Push Notification service

4. **Large Responses**
   - May return incomplete results for very large collections
   - Use pagination or time-range filters

5. **vCard Version**
   - Primarily uses vCard 3.0
   - Limited vCard 4.0 support

### Best Practices for iCloud

1. **Always use app-specific passwords** in documentation
2. **Implement sync-token support** for efficiency
3. **Handle authentication failures gracefully** (prompt for new password)
4. **Support calendar-color and calendar-order** extensions
5. **Use time-range queries** to limit response sizes
6. **Implement exponential backoff** for rate limiting

### Example Discovery Flow

```swift
// 1. Discover principal
let principalURL = try await discoverPrincipal(baseURL: "https://caldav.icloud.com/")

// 2. Discover calendar home
let calendarHome = try await discoverCalendarHome(principalURL: principalURL)

// 3. List calendars
let calendars = try await listCalendars(calendarHome: calendarHome)

// 4. For each calendar, get events
for calendar in calendars {
    let events = try await fetchEvents(
        calendar: calendar,
        from: Date(),
        to: Date().addingTimeInterval(86400 * 30)
    )
}
```

---

## Google Calendar and Contacts

### Overview

Google provides CalDAV and CardDAV support but strongly encourages using their REST API (Google Calendar API, People API) instead. CalDAV/CardDAV support exists for compatibility.

### Authentication

**OAuth 2.0 Required**

Google requires OAuth 2.0 for CalDAV/CardDAV:
- Cannot use username/password
- Must obtain OAuth 2.0 access token
- Requires app registration in Google Cloud Console

**OAuth Scopes:**
- CalDAV: `https://www.google.com/calendar/dav/`
- CardDAV: `https://www.googleapis.com/auth/carddav`
- Alternative (read/write): `https://www.googleapis.com/auth/calendar`, `https://www.googleapis.com/auth/contacts`

**Using OAuth with CalDAV:**
```
Authorization: Bearer <access-token>
```

### CalDAV Endpoints

**Base URL:**
```
https://apidata.googleusercontent.com/caldav/v2/
```

**Principal URL:**
```
https://apidata.googleusercontent.com/caldav/v2/[email]/user
```

**Calendar Home:**
```
https://apidata.googleusercontent.com/caldav/v2/[email]/events
```

**Primary Calendar ID:**
- User's email address (e.g., `user@gmail.com`)

### Discovery Flow

```
PROPFIND https://apidata.googleusercontent.com/caldav/v2/[email]/user
Depth: 0
Authorization: Bearer <oauth-token>

Request body:
<?xml version="1.0" encoding="UTF-8"?>
<d:propfind xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
  <d:prop>
    <c:calendar-home-set/>
  </d:prop>
</d:propfind>
```

### List Calendars

Google calendars are discovered via the calendar home:

```
PROPFIND https://apidata.googleusercontent.com/caldav/v2/[email]/events
Depth: 1
Authorization: Bearer <oauth-token>
```

### CardDAV Endpoints

**Base URL:**
```
https://www.googleapis.com/.well-known/carddav
```

**Note:** Google CardDAV support is limited. The People API (REST) is strongly recommended instead.

### Google-Specific Features

1. **Event Colors**
   - Google uses its own color extension
   - Not standard CalDAV color

2. **Attendees and Resources**
   - Full support for ATTENDEE property
   - Supports resource calendars (rooms, equipment)

3. **Reminders**
   - VALARM components supported
   - Multiple reminder types (email, popup)

4. **Time Zones**
   - Prefers UTC times
   - Supports VTIMEZONE components
   - Auto-converts to user's timezone

### Limitations

1. **OAuth Only**
   - No basic authentication
   - Must handle token refresh
   - Tokens expire (typically 1 hour)

2. **HTTPS Required**
   - All connections must use TLS
   - Certificate validation enforced

3. **Rate Limiting**
   - Aggressive rate limits
   - Use exponential backoff
   - Batch requests when possible

4. **CardDAV Limited**
   - Basic CardDAV support only
   - Missing features compared to People API
   - Better to use People API directly

5. **No CalDAV Scheduling**
   - Limited scheduling extension support
   - Use Google Calendar API for invitations

### Best Practices for Google

1. **Implement OAuth 2.0 flow** properly
2. **Handle token refresh** automatically
3. **Use batch operations** (calendar-multiget)
4. **Respect rate limits** (exponential backoff)
5. **Consider REST API** for better feature support
6. **Test with multiple Google account types** (personal, Workspace)

### OAuth 2.0 Flow Example

```swift
// 1. Request authorization
let authURL = "https://accounts.google.com/o/oauth2/v2/auth?client_id=\(clientID)&redirect_uri=\(redirectURI)&response_type=code&scope=https://www.googleapis.com/auth/calendar"

// 2. Exchange authorization code for tokens
let tokenURL = "https://oauth2.googleapis.com/token"
let params = [
    "code": authorizationCode,
    "client_id": clientID,
    "client_secret": clientSecret,
    "redirect_uri": redirectURI,
    "grant_type": "authorization_code"
]

// 3. Receive access token and refresh token
let response = try await httpClient.post(tokenURL, params: params)
let accessToken = response["access_token"]
let refreshToken = response["refresh_token"]

// 4. Use access token for CalDAV requests
let request = URLRequest(url: caldavURL)
request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

// 5. Refresh when token expires
let refreshParams = [
    "refresh_token": refreshToken,
    "client_id": clientID,
    "client_secret": clientSecret,
    "grant_type": "refresh_token"
]
let newTokens = try await httpClient.post(tokenURL, params: refreshParams)
```

---

## Microsoft Exchange and Office.com

### Overview

**Important:** Microsoft Exchange and Office.com do **NOT** natively support CalDAV or CardDAV protocols.

### Microsoft's Preferred Protocols

1. **Microsoft Graph API** (Recommended)
   - Modern REST API
   - Full feature support
   - OAuth 2.0 authentication
   - Best performance and features

2. **Exchange Web Services (EWS)**
   - SOAP-based protocol
   - Legacy but still supported
   - More complex than Graph API

3. **Exchange ActiveSync**
   - Mobile synchronization protocol
   - Used by mobile devices
   - Proprietary protocol

### Why No CalDAV/CardDAV?

Microsoft never implemented CalDAV/CardDAV in Exchange or Office.com:
- ActiveSync introduced before CalDAV/CardDAV standardization
- Microsoft Graph API is their modern approach
- No plans to add CalDAV/CardDAV support

### Third-Party Solutions

**DavMail:**
- Acts as a protocol gateway/proxy
- Provides CalDAV/CardDAV interface to Exchange
- Translates CalDAV ↔ EWS or ActiveSync
- Open-source (GPLv2)
- Repository: https://davmail.sourceforge.net/

**Outlook CalDav Synchronizer:**
- Outlook plugin for CalDAV/CardDAV sync
- Bridges Outlook ↔ CalDAV servers
- Open-source
- Repository: https://github.com/aluxnimm/outlookcaldavsynchronizer

### Microsoft Graph API (Recommended Approach)

If supporting Office.com/Exchange is required, use Microsoft Graph API:

**Authentication:**
- OAuth 2.0
- Azure AD app registration required

**Endpoints:**
```
# List calendars
GET https://graph.microsoft.com/v1.0/me/calendars

# List events
GET https://graph.microsoft.com/v1.0/me/calendar/events

# Get specific event
GET https://graph.microsoft.com/v1.0/me/calendar/events/{id}

# Create event
POST https://graph.microsoft.com/v1.0/me/calendar/events

# Update event
PATCH https://graph.microsoft.com/v1.0/me/calendar/events/{id}

# Delete event
DELETE https://graph.microsoft.com/v1.0/me/calendar/events/{id}
```

**Contacts:**
```
# List contacts
GET https://graph.microsoft.com/v1.0/me/contacts

# Create contact
POST https://graph.microsoft.com/v1.0/me/contacts
```

### Implementation Strategy for SwiftXDAV

**Option 1: No Microsoft Support**
- Document that Exchange/Office.com is not supported
- Direct users to native apps or DavMail gateway

**Option 2: Microsoft Graph API Integration**
- Implement separate module for Microsoft Graph
- Not CalDAV/CardDAV, but similar functionality
- Provide unified interface abstracting protocol differences

**Option 3: DavMail Gateway Support**
- Document DavMail setup for users
- Test compatibility with DavMail
- Treat as any other CalDAV/CardDAV server

### Recommendation

**For SwiftXDAV:**
1. **Phase 1**: Focus on true CalDAV/CardDAV servers (iCloud, Google, etc.)
2. **Phase 2**: Consider Microsoft Graph integration as separate module
3. **Documentation**: Clearly state Exchange/Office.com requires Microsoft Graph API or DavMail

### Microsoft Graph Example

```swift
// OAuth 2.0 setup
let scopes = ["Calendars.ReadWrite", "Contacts.ReadWrite"]

// List calendars
let response = try await httpClient.get(
    "https://graph.microsoft.com/v1.0/me/calendars",
    headers: ["Authorization": "Bearer \(accessToken)"]
)

// Create event
let event = [
    "subject": "Team Meeting",
    "start": ["dateTime": "2025-06-11T14:00:00", "timeZone": "Pacific Standard Time"],
    "end": ["dateTime": "2025-06-11T15:00:00", "timeZone": "Pacific Standard Time"],
    "attendees": [
        ["emailAddress": ["address": "person@example.com"], "type": "required"]
    ]
]

let created = try await httpClient.post(
    "https://graph.microsoft.com/v1.0/me/calendar/events",
    body: JSONEncoder().encode(event),
    headers: ["Authorization": "Bearer \(accessToken)", "Content-Type": "application/json"]
)
```

---

## General Server Requirements

### Standard Compliance

All servers should support:

**WebDAV (RFC 4918):**
- PROPFIND
- PROPPATCH
- MKCOL
- COPY, MOVE
- DELETE
- LOCK, UNLOCK (optional but recommended)

**CalDAV (RFC 4791):**
- Calendar collections
- REPORT method (calendar-query, calendar-multiget)
- Calendar data properties
- ETag support

**CardDAV (RFC 6352):**
- Address book collections
- REPORT method (addressbook-query, addressbook-multiget)
- Address data properties
- ETag support

**Optional but Recommended:**
- RFC 6578: WebDAV Sync (sync-collection REPORT)
- RFC 6638: CalDAV Scheduling
- RFC 7809: Time Zones by Reference

### Discovery Flow

Standard discovery sequence:

1. **OPTIONS request** to check DAV support
2. **PROPFIND** for current-user-principal
3. **PROPFIND** for calendar-home-set / addressbook-home-set
4. **PROPFIND** (Depth: 1) to enumerate collections
5. **REPORT** to query data

### Error Handling

Common HTTP status codes:

- **200 OK**: Success
- **201 Created**: Resource created (PUT)
- **204 No Content**: Success with no response body (DELETE, PUT)
- **207 Multi-Status**: Multiple independent operations
- **401 Unauthorized**: Authentication required
- **403 Forbidden**: Access denied
- **404 Not Found**: Resource doesn't exist
- **409 Conflict**: Resource conflict (duplicate UID, etc.)
- **412 Precondition Failed**: ETag mismatch
- **423 Locked**: Resource is locked
- **507 Insufficient Storage**: Server storage full

### ETag Handling

All servers must support ETags for optimistic concurrency:

```
# Get resource with ETag
GET /calendars/home/event1.ics
Response:
ETag: "abc123"

# Update with If-Match
PUT /calendars/home/event1.ics
If-Match: "abc123"
[event data]

# Success if ETag matches, 412 if mismatch
```

### Sync-Token Support

Efficient synchronization:

```
# Initial sync
REPORT /calendars/home/
<?xml version="1.0" encoding="utf-8" ?>
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token/>
  <d:prop>
    <d:getetag/>
  </d:prop>
</d:sync-collection>

Response:
<d:sync-token>http://example.com/sync/123</d:sync-token>
[list of all resources]

# Subsequent sync
REPORT /calendars/home/
<d:sync-collection xmlns:d="DAV:">
  <d:sync-token>http://example.com/sync/123</d:sync-token>
  <d:prop>
    <d:getetag/>
  </d:prop>
</d:sync-collection>

Response:
<d:sync-token>http://example.com/sync/124</d:sync-token>
[only changed/deleted resources since token 123]
```

---

## Testing Strategy

### Test Against Multiple Servers

Ensure compatibility by testing against:

1. **iCloud**
   - Test with personal iCloud account
   - Verify app-specific password flow
   - Test calendar and contact sync

2. **Google**
   - Test OAuth 2.0 flow
   - Test with both Gmail and Google Workspace accounts
   - Verify calendar operations

3. **Self-Hosted Servers**
   - **Radicale**: Python-based, simple server for testing
   - **Nextcloud**: Popular self-hosted solution
   - **SOGo**: Groupware server with CalDAV/CardDAV
   - **Baikal**: Lightweight CalDAV/CardDAV server

### Test Scenarios

**Discovery:**
- [ ] Principal discovery via .well-known URLs
- [ ] Calendar home discovery
- [ ] Address book home discovery
- [ ] Collection enumeration

**Calendar Operations:**
- [ ] Create event
- [ ] Read event
- [ ] Update event (with ETag)
- [ ] Delete event
- [ ] Query events by time range
- [ ] Expand recurring events
- [ ] Handle all-day events
- [ ] Handle events with timezones

**Contact Operations:**
- [ ] Create contact
- [ ] Read contact
- [ ] Update contact (with ETag)
- [ ] Delete contact
- [ ] Search contacts by name
- [ ] Handle photo URLs and embedded photos

**Synchronization:**
- [ ] Initial sync (full fetch)
- [ ] Delta sync (sync-token)
- [ ] ETag-based change detection
- [ ] Conflict resolution
- [ ] Handle deleted resources

**Error Handling:**
- [ ] Network failures
- [ ] Authentication failures
- [ ] Invalid credentials
- [ ] Token expiration (OAuth)
- [ ] Rate limiting
- [ ] Server errors (500)
- [ ] Malformed responses

**Edge Cases:**
- [ ] Large calendars (1000+ events)
- [ ] Large contacts (1000+ contacts)
- [ ] Events with many attendees
- [ ] Recurring events with exceptions
- [ ] Time zone edge cases
- [ ] Daylight saving transitions
- [ ] Non-ASCII characters (emoji, international names)

### Integration Test Setup

```swift
final class iCloudIntegrationTests: XCTestCase {
    var client: CalDAVClient!

    override func setUp() async throws {
        // Load credentials from environment
        guard let url = ProcessInfo.processInfo.environment["ICLOUD_CALDAV_URL"],
              let username = ProcessInfo.processInfo.environment["ICLOUD_USERNAME"],
              let password = ProcessInfo.processInfo.environment["ICLOUD_APP_PASSWORD"] else {
            throw XCTSkip("iCloud credentials not configured")
        }

        let config = CalDAVClientConfiguration.make { config in
            config.baseURL = URL(string: url)!
            config.authentication = .basic(username: username, password: password)
        }

        client = CalDAVClient(configuration: config)
    }

    func testDiscoverCalendars() async throws {
        let calendars = try await client.listCalendars()
        XCTAssertFalse(calendars.isEmpty, "Should discover at least one calendar")
    }

    func testCreateAndDeleteEvent() async throws {
        let calendars = try await client.listCalendars()
        guard let calendar = calendars.first else {
            throw XCTSkip("No calendars available")
        }

        // Create test event
        let event = Event(
            summary: "SwiftXDAV Test Event",
            start: Date(),
            end: Date().addingTimeInterval(3600)
        )

        let created = try await client.createEvent(event, in: calendar)
        XCTAssertNotNil(created.uid)

        // Clean up
        try await client.deleteEvent(withID: created.uid, in: calendar)
    }
}
```

### Continuous Integration

Set up CI to run tests against real servers:

```yaml
# .github/workflows/integration-tests.yml
name: Integration Tests

on: [push, pull_request]

jobs:
  test-icloud:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run iCloud tests
        env:
          ICLOUD_CALDAV_URL: ${{ secrets.ICLOUD_CALDAV_URL }}
          ICLOUD_USERNAME: ${{ secrets.ICLOUD_USERNAME }}
          ICLOUD_APP_PASSWORD: ${{ secrets.ICLOUD_APP_PASSWORD }}
        run: swift test --filter iCloudIntegrationTests

  test-google:
    runs-on: macos-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run Google tests
        env:
          GOOGLE_OAUTH_TOKEN: ${{ secrets.GOOGLE_OAUTH_TOKEN }}
        run: swift test --filter GoogleIntegrationTests
```

---

## Summary

### Server Support Matrix

| Feature | iCloud | Google | Microsoft | Nextcloud | Radicale |
|---------|--------|--------|-----------|-----------|----------|
| CalDAV | ✅ | ✅ | ❌ (Graph API) | ✅ | ✅ |
| CardDAV | ✅ | ⚠️ (Limited) | ❌ (Graph API) | ✅ | ✅ |
| Auth Method | Basic (App Pass) | OAuth 2.0 | OAuth 2.0 | Basic/OAuth | Basic/None |
| Sync Tokens | ✅ | ✅ | N/A | ✅ | ✅ |
| Scheduling | ✅ | ⚠️ (Limited) | N/A | ✅ | ❌ |
| TLS Required | ✅ | ✅ | ✅ | ✅ | Optional |

### Implementation Priorities

1. **Phase 1: Core CalDAV/CardDAV**
   - iCloud (most important for Apple ecosystem)
   - Self-hosted servers (Nextcloud, Radicale)

2. **Phase 2: Google**
   - OAuth 2.0 implementation
   - Google-specific quirks

3. **Phase 3: Microsoft (Optional)**
   - Graph API integration as separate module
   - Document DavMail alternative

### Key Takeaways

1. **iCloud** is the priority target for Apple ecosystem
2. **Google** requires OAuth 2.0, has limitations
3. **Microsoft** requires Graph API, not CalDAV/CardDAV
4. **Test broadly** against multiple server implementations
5. **Handle server-specific quirks** gracefully
6. **Implement proper authentication** for each platform
7. **Use sync tokens** for efficient synchronization
