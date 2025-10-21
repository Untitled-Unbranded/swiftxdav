# Phase 9: Server-Specific Implementations - Summary

## Overview

Phase 9 implements server-specific configurations, OAuth 2.0 token management, server detection, and capability discovery. This phase enables SwiftXDAV to work seamlessly with different CalDAV/CardDAV servers including iCloud, Google, Nextcloud, and others.

## Completed Components

### 1. OAuth 2.0 Token Management

#### OAuth2TokenManager (`Sources/SwiftXDAVNetwork/Authentication/OAuth2TokenManager.swift`)
- Actor-based thread-safe token manager
- Automatic token refresh with expiration tracking
- 5-minute expiration buffer to prevent race conditions
- Token refresh callback for persistence
- Google-specific convenience constructor

**Features:**
- `getAccessToken()` - Returns valid token, refreshing if needed
- `forceRefresh()` - Manually trigger token refresh
- `isExpired` - Check token expiration status
- Callback support for token updates (useful for saving to keychain)

#### OAuth2HTTPClient (`Sources/SwiftXDAVNetwork/HTTP/OAuth2HTTPClient.swift`)
- HTTP client with automatic OAuth 2.0 token management
- Automatic retry with fresh token on 401 responses
- Wraps any base HTTP client
- Google-specific convenience constructor

**Features:**
- Automatic token refresh before requests
- Smart 401 handling with token refresh and retry
- Integration with OAuth2TokenManager

### 2. Server Detection & Capabilities

#### ServerCapabilities (`Sources/SwiftXDAVNetwork/WebDAV/ServerCapabilities.swift`)
- Comprehensive capability tracking
- Server type enumeration (iCloud, Google, Nextcloud, etc.)
- Feature detection (CalDAV, CardDAV, sync-collection, scheduling)
- DAV compliance class tracking
- Supported HTTP methods enumeration

**Detected Server Types:**
- iCloud
- Google
- Nextcloud
- ownCloud
- SOGo
- Radicale
- Baikal
- Synology
- Generic (unknown)

**Detected Capabilities:**
- CalDAV support
- CardDAV support
- Sync-collection (RFC 6578)
- Calendar-query REPORT
- Addressbook-query REPORT
- Scheduling extensions (RFC 6638)
- Calendar-proxy support

#### ServerDetector (`Sources/SwiftXDAVNetwork/WebDAV/ServerDetector.swift`)
- Automatic server type detection from URL and headers
- OPTIONS request-based capability discovery
- Server version parsing
- DAV compliance class parsing

**Detection Methods:**
- URL-based detection (e.g., icloud.com → iCloud)
- Server header parsing (e.g., "Nextcloud/25.0.3")
- DAV header analysis for capabilities
- Allow header parsing for supported methods

### 3. Server-Specific Adapters

#### ServerQuirks (`Sources/SwiftXDAVNetwork/WebDAV/ServerDetector.swift`)
- Server-specific behavior adaptations
- Quirks database for known server issues
- Customizable behavior overrides

**Tracked Quirks:**
- Trailing slash requirements for collections
- ETag support
- Conditional request support (If-Match/If-None-Match)
- PROPFIND Depth behavior
- URL encoding in hrefs
- Custom User-Agent requirements
- Maximum batch size for multi-get requests

**Server-Specific Quirks:**
- **iCloud**: Requires trailing slashes, max batch size 50
- **Google**: No trailing slash required, max batch size 100
- **Nextcloud/ownCloud**: Requires trailing slashes, max batch size 100
- **Synology**: URL-encodes hrefs, max batch size 50
- **Generic**: Conservative defaults

#### ServerAdapter (`Sources/SwiftXDAVNetwork/WebDAV/ServerAdapter.swift`)
- URL normalization based on server quirks
- Collection vs resource URL handling
- Href decoding for PROPFIND responses
- Server-specific header application
- Batching utilities for multi-get requests
- Well-known URL construction (RFC 6764)

**Key Methods:**
- `normalizeURL()` - Normalize URLs per server requirements
- `normalizeCollectionURL()` - Ensure proper collection URL format
- `normalizeResourceURL()` - Ensure proper resource URL format
- `decodeHref()` - Decode hrefs from PROPFIND responses
- `applyServerSpecificHeaders()` - Add server-required headers
- `batchHrefs()` - Split hrefs into optimal batches
- `wellKnownCalDAVURL()` - Construct .well-known/caldav URL
- `wellKnownCardDAVURL()` - Construct .well-known/carddav URL

### 4. Enhanced Client Convenience Methods

#### CalDAVClient Extensions
Already implemented convenience methods:
- `.iCloud(username:appSpecificPassword:)` - Basic auth for iCloud
- `.google(accessToken:)` - Bearer token for Google
- `.custom(serverURL:username:password:)` - Generic server

**New Methods:**
- `.googleWithRefresh(accessToken:refreshToken:clientID:clientSecret:expiresAt:onTokenRefresh:)`
  - Full OAuth 2.0 with automatic token refresh
  - Token refresh callback for persistence
  - Automatic retry on 401

#### CardDAVClient Extensions
Matching enhancements:
- `.iCloud(username:appSpecificPassword:)` - Basic auth for iCloud
- `.google(accessToken:)` - Bearer token for Google
- `.custom(serverURL:username:password:)` - Generic server
- `.googleWithRefresh(...)` - Full OAuth 2.0 with auto-refresh

### 5. Comprehensive Tests

#### ServerDetectorTests
- Server type detection from URLs
- Server type detection from Server headers
- CalDAV capability detection
- CardDAV capability detection
- Scheduling support detection
- HTTP method parsing
- Mock HTTP client for testing

#### ServerAdapterTests
- URL normalization (collections vs resources)
- Trailing slash handling per server type
- Href decoding (URL-encoded vs plain)
- User-Agent customization
- Server-specific header application
- Batch size limits per server
- Href batching logic
- Well-known URL construction

#### OAuth2TokenManagerTests
- Token expiration detection
- Expiration buffer handling
- Token refresh callback mechanism
- Google helper constructor
- Access token retrieval

## Usage Examples

### iCloud with Basic Auth
```swift
let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

let calendars = try await client.listCalendars()
```

### Google with OAuth 2.0 (Simple)
```swift
let client = CalDAVClient.google(accessToken: "ya29.abc...")
let calendars = try await client.listCalendars()
```

### Google with OAuth 2.0 (With Auto-Refresh)
```swift
let client = CalDAVClient.googleWithRefresh(
    accessToken: "ya29.abc...",
    refreshToken: "1//0g...",
    clientID: "client-id.apps.googleusercontent.com",
    clientSecret: "secret",
    expiresAt: Date().addingTimeInterval(3600),
    onTokenRefresh: { newToken, expiresAt in
        // Save new token to keychain
        KeychainHelper.save(token: newToken)
    }
)

// Tokens automatically refresh when needed
let calendars = try await client.listCalendars()
```

### Server Detection
```swift
let detector = ServerDetector(httpClient: client)
let capabilities = try await detector.detectCapabilities(
    baseURL: URL(string: "https://dav.example.com")!
)

print("Server type: \(capabilities.serverType)")
print("CalDAV: \(capabilities.supportsCalDAV)")
print("CardDAV: \(capabilities.supportsCardDAV)")
print("Sync: \(capabilities.supportsSyncCollection)")

// Adapt behavior based on capabilities
if capabilities.supportsSyncCollection {
    // Use efficient sync-token based sync
} else {
    // Fall back to ETag-based sync
}
```

### Server Adapter
```swift
let adapter = ServerAdapter(serverType: .iCloud)

// Normalize URLs per server requirements
let collectionURL = adapter.normalizeCollectionURL(url)
let resourceURL = adapter.normalizeResourceURL(url)

// Apply server-specific headers
var headers: [String: String] = [:]
adapter.applyServerSpecificHeaders(to: &headers)

// Batch requests optimally
let hrefs = (0..<200).map { "/calendar/event\($0).ics" }
let batches = adapter.batchHrefs(hrefs)
// For iCloud: 4 batches of 50, 50, 50, 50
// For Google: 2 batches of 100, 100
```

### Custom Server
```swift
let client = CalDAVClient.custom(
    serverURL: URL(string: "https://nextcloud.example.com/remote.php/dav")!,
    username: "user",
    password: "password"
)

// Auto-detect capabilities
let detector = ServerDetector(httpClient: client.httpClient)
let capabilities = try await detector.detectCapabilities(
    baseURL: client.baseURL
)

// Create adapter for server-specific handling
let adapter = ServerAdapter(serverType: capabilities.serverType)
```

## Architecture Decisions

### 1. Actor-Based Token Management
OAuth2TokenManager is an actor to ensure thread-safe token refresh without data races. This is critical in Swift 6.0's strict concurrency model.

### 2. Callback-Based Token Persistence
The token refresh callback allows clients to persist updated tokens without coupling the token manager to specific storage mechanisms (Keychain, UserDefaults, etc.).

### 3. Server Detection via OPTIONS
Using OPTIONS requests for capability detection follows RFC 4918 and is widely supported. This is more reliable than URL-based detection alone.

### 4. Quirks Database
Different servers have different behaviors and bugs. The quirks database allows SwiftXDAV to adapt to these differences without branching logic throughout the codebase.

### 5. URL Normalization
Different servers have different expectations for URL formats (trailing slashes, encoding, etc.). The ServerAdapter centralizes this logic.

### 6. Automatic Retry on 401
OAuth2HTTPClient automatically retries requests with a fresh token on 401 responses, making token expiration transparent to client code.

## Testing Strategy

### Unit Tests
- Mock HTTP client for testing without network requests
- Comprehensive coverage of URL normalization logic
- Token expiration edge cases
- Server type detection from headers and URLs
- Quirks database validation

### Integration Tests (Future)
- Test against real iCloud servers
- Test against real Google Calendar API
- Test against self-hosted Radicale (CI)
- Test against Nextcloud demo instances
- Verify OAuth 2.0 refresh flow end-to-end

## Swift 6.0 Compliance

All code follows Swift 6.0 strict concurrency:
- ✅ Actors for mutable state (OAuth2TokenManager, ServerDetector)
- ✅ Sendable types for all public data structures
- ✅ No force unwraps or force casts
- ✅ Proper error handling with typed throws
- ✅ Async/await throughout
- ✅ Full DocC documentation

## Files Created

### Source Files
1. `Sources/SwiftXDAVNetwork/Authentication/OAuth2TokenManager.swift`
2. `Sources/SwiftXDAVNetwork/HTTP/OAuth2HTTPClient.swift`
3. `Sources/SwiftXDAVNetwork/WebDAV/ServerCapabilities.swift`
4. `Sources/SwiftXDAVNetwork/WebDAV/ServerDetector.swift`
5. `Sources/SwiftXDAVNetwork/WebDAV/ServerAdapter.swift`

### Test Files
1. `Tests/SwiftXDAVNetworkTests/OAuth2TokenManagerTests.swift`
2. `Tests/SwiftXDAVNetworkTests/ServerDetectorTests.swift`
3. `Tests/SwiftXDAVNetworkTests/ServerAdapterTests.swift`

### Modified Files
1. `Sources/SwiftXDAVCalendar/Client/CalDAVClient.swift` - Added `.googleWithRefresh()`
2. `Sources/SwiftXDAVContacts/Client/CardDAVClient.swift` - Added `.googleWithRefresh()`

## Next Steps (Phase 10: Synchronization)

With server-specific implementations complete, the next phase will implement:
1. Sync-token based synchronization (RFC 6578)
2. ETag-based synchronization (fallback)
3. Conflict detection and resolution
4. Efficient incremental sync
5. Change tracking and delta updates

## Success Criteria - Phase 9 ✅

- [x] iCloud convenience initializers
- [x] Google OAuth 2.0 support with token refresh
- [x] Server detection and capability discovery
- [x] Server-specific quirks database
- [x] URL normalization and adaptation
- [x] Batching utilities
- [x] Comprehensive tests
- [x] DocC documentation
- [x] Swift 6.0 strict concurrency compliance
- [x] No force unwraps or force casts

## Notes

### Token Refresh Security
The OAuth2TokenManager stores tokens in memory. For production apps, developers should:
1. Store tokens securely in Keychain
2. Use the `onTokenRefresh` callback to persist updated tokens
3. Never log or print tokens
4. Use HTTPS for all token requests

### Server Detection Reliability
Server detection is based on URL patterns and Server headers. Some servers may:
- Not include Server headers (security hardening)
- Use custom URLs that don't match patterns
- Proxy through CDNs that modify headers

The `.generic` server type provides conservative defaults for unknown servers.

### Google Calendar/Contacts
Google's CalDAV/CardDAV support is limited compared to their native APIs. For full functionality, consider using Google Calendar API v3 and People API directly. SwiftXDAV's Google support is best for:
- Simple calendar/contact sync
- Cross-platform compatibility
- Standard CalDAV/CardDAV workflows

For advanced Google features (attendee management, rich scheduling, etc.), use native APIs.

---

**Implementation Date:** 2025-10-21
**Phase:** 9 of 12
**Status:** ✅ Complete
