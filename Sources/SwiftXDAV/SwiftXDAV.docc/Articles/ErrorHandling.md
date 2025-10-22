# Error Handling

Learn how to handle errors effectively when working with SwiftXDAV.

## Overview

SwiftXDAV uses Swift's typed error system to provide precise error handling. All operations can throw `SwiftXDAVError`, which provides detailed information about what went wrong and why.

## Error Types

### SwiftXDAVError

The main error type used throughout SwiftXDAV:

```swift
public enum SwiftXDAVError: Error {
    // Authentication errors
    case authenticationFailed
    case unauthorized

    // Network errors
    case networkError(Error)
    case requestFailed(statusCode: Int, message: String?)

    // Server errors
    case serverError(statusCode: Int, message: String?)
    case preconditionFailed
    case notFound
    case conflict

    // Parsing errors
    case parsingError(String)
    case invalidData(String)
    case unsupportedFormat(String)

    // Synchronization errors
    case syncTokenInvalid
    case etagMismatch

    // Discovery errors
    case discoveryFailed(String)
    case unsupportedServer

    // General errors
    case invalidURL(String)
    case missingProperty(String)
    case internalError(String)
}
```

## Basic Error Handling

### Catching Specific Errors

```swift
import SwiftXDAV

do {
    let calendars = try await client.listCalendars()
    // Process calendars
} catch SwiftXDAVError.authenticationFailed {
    print("Authentication failed - check credentials")
} catch SwiftXDAVError.unauthorized {
    print("Unauthorized - permissions may have been revoked")
} catch SwiftXDAVError.networkError(let underlyingError) {
    print("Network error: \(underlyingError.localizedDescription)")
} catch SwiftXDAVError.serverError(let statusCode, let message) {
    print("Server error \(statusCode): \(message ?? "unknown")")
} catch {
    print("Unexpected error: \(error)")
}
```

### Pattern Matching

```swift
func handleError(_ error: Error) {
    guard let davError = error as? SwiftXDAVError else {
        print("Unknown error: \(error)")
        return
    }

    switch davError {
    case .authenticationFailed, .unauthorized:
        // Show login screen
        showLoginScreen()

    case .networkError:
        // Show offline message
        showOfflineMessage()

    case .serverError(let statusCode, _) where statusCode >= 500:
        // Server is having issues, try again later
        showRetryLater()

    case .parsingError(let details):
        // Log parsing error for debugging
        logError("Parsing failed: \(details)")

    case .syncTokenInvalid:
        // Fall back to full sync
        performFullSync()

    case .preconditionFailed, .etagMismatch:
        // Conflict detected, refetch and retry
        handleConflict()

    default:
        // Generic error handling
        showGenericError(davError)
    }
}
```

## Authentication Errors

### Failed Authentication

```swift
do {
    let client = CalDAVClient.iCloud(
        username: username,
        appSpecificPassword: password
    )
    let calendars = try await client.listCalendars()
} catch SwiftXDAVError.authenticationFailed {
    // Invalid credentials
    showError(message: "Invalid username or password")
    showLoginScreen()
} catch SwiftXDAVError.unauthorized {
    // Valid credentials but insufficient permissions
    showError(message: "Account doesn't have CalDAV access")
}
```

### OAuth Token Expiration

```swift
do {
    let calendars = try await client.listCalendars()
} catch SwiftXDAVError.authenticationFailed {
    // Try to refresh token
    do {
        try await tokenManager.refreshToken()
        // Retry the operation
        let calendars = try await client.listCalendars()
    } catch {
        // Refresh failed - need to re-authenticate
        showLoginScreen()
    }
}
```

## Network Errors

### Handling Connection Issues

```swift
do {
    let calendars = try await client.listCalendars()
} catch SwiftXDAVError.networkError(let underlyingError) {
    let nsError = underlyingError as NSError

    if nsError.domain == NSURLErrorDomain {
        switch nsError.code {
        case NSURLErrorNotConnectedToInternet:
            showOfflineAlert()

        case NSURLErrorTimedOut:
            showTimeoutAlert()

        case NSURLErrorCannotFindHost:
            showError(message: "Server not found")

        case NSURLErrorSecureConnectionFailed:
            showError(message: "SSL/TLS error - check server certificate")

        default:
            showError(message: "Network error: \(underlyingError.localizedDescription)")
        }
    }
}
```

### Retry with Exponential Backoff

```swift
func fetchWithRetry<T>(
    maxAttempts: Int = 3,
    operation: @escaping () async throws -> T
) async throws -> T {
    var lastError: Error?
    var delay: TimeInterval = 1.0

    for attempt in 1...maxAttempts {
        do {
            return try await operation()
        } catch SwiftXDAVError.networkError(let error) {
            lastError = error
            print("Attempt \(attempt) failed: \(error)")

            if attempt < maxAttempts {
                print("Retrying in \(delay) seconds...")
                try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                delay *= 2 // Exponential backoff
            }
        } catch {
            // Don't retry non-network errors
            throw error
        }
    }

    throw lastError!
}

// Usage
let calendars = try await fetchWithRetry {
    try await client.listCalendars()
}
```

## Server Errors

### HTTP Status Codes

```swift
do {
    let event = try await client.createEvent(event, in: calendar)
} catch SwiftXDAVError.serverError(let statusCode, let message) {
    switch statusCode {
    case 400:
        showError(message: "Invalid event data: \(message ?? "")")

    case 403:
        showError(message: "Permission denied")

    case 404:
        showError(message: "Calendar not found")

    case 409:
        showError(message: "Conflict - event already exists")

    case 500...599:
        showError(message: "Server error - please try again later")

    default:
        showError(message: "Server error \(statusCode): \(message ?? "unknown")")
    }
}
```

### Service Unavailable

```swift
func isServiceUnavailable(_ error: Error) -> Bool {
    if case SwiftXDAVError.serverError(let statusCode, _) = error,
       statusCode == 503 {
        return true
    }
    return false
}

// Usage
do {
    let calendars = try await client.listCalendars()
} catch let error where isServiceUnavailable(error) {
    // Server is down or under maintenance
    showMaintenanceAlert()
    scheduleRetry(after: 300) // Retry in 5 minutes
}
```

## Parsing Errors

### Invalid iCalendar Data

```swift
do {
    let parser = ICalendarParser()
    let calendar = try parser.parse(data)
} catch SwiftXDAVError.parsingError(let details) {
    print("Failed to parse iCalendar: \(details)")

    // Log for debugging
    logParsingError(details: details, data: data)

    // Skip this event and continue
    continue
} catch SwiftXDAVError.unsupportedFormat(let format) {
    print("Unsupported format: \(format)")
}
```

### Invalid vCard Data

```swift
do {
    let parser = VCardParser()
    let contact = try parser.parse(data)
} catch SwiftXDAVError.parsingError(let details) {
    print("Failed to parse vCard: \(details)")

    // Try to extract what we can
    if let partialContact = tryPartialParse(data) {
        // Use partial data
        return partialContact
    }

    // Otherwise skip
    continue
}
```

## Synchronization Errors

### Invalid Sync Token

```swift
do {
    let result = try await client.sync(
        calendar: calendar,
        syncToken: savedSyncToken
    )
    // Process changes
} catch SwiftXDAVError.syncTokenInvalid {
    print("Sync token invalid - performing full sync")

    // Clear local data and do full sync
    clearLocalData()
    let result = try await client.sync(calendar: calendar, syncToken: nil)
    rebuildLocalDatabase(from: result)
}
```

### ETag Conflicts

```swift
do {
    try await client.updateEvent(event, in: calendar, etag: etag)
} catch SwiftXDAVError.preconditionFailed {
    print("Event was modified by another client")

    // Fetch latest version
    let (latestEvent, latestETag) = try await client.fetchEvent(
        uid: event.uid,
        from: calendar
    )

    // Show conflict resolution UI
    let resolved = try await showConflictResolution(
        local: event,
        remote: latestEvent
    )

    // Retry with latest ETag
    try await client.updateEvent(resolved, in: calendar, etag: latestETag)
} catch SwiftXDAVError.etagMismatch {
    // Similar handling to preconditionFailed
    print("ETag mismatch - refetching")
}
```

## Discovery Errors

### Failed Server Discovery

```swift
let detector = ServerDetector(httpClient: httpClient)

do {
    let serverType = try await detector.detectServerType(at: serverURL)
    // Use detected server type
} catch SwiftXDAVError.discoveryFailed(let reason) {
    print("Discovery failed: \(reason)")
    showError(message: "Could not detect server type. Please enter server details manually.")
} catch SwiftXDAVError.unsupportedServer {
    print("Server doesn't support CalDAV/CardDAV")
    showError(message: "This server doesn't support calendar/contact syncing")
}
```

### Missing Properties

```swift
do {
    let principalURL = try await client.discoverPrincipal()
} catch SwiftXDAVError.missingProperty(let property) {
    print("Server didn't return required property: \(property)")

    // Try alternative discovery method
    if let principalURL = try? await alternativeDiscovery() {
        // Use alternative method
    } else {
        showError(message: "Server doesn't provide required information")
    }
}
```

## User-Friendly Error Messages

### Translating Errors

```swift
func userFriendlyMessage(for error: Error) -> String {
    guard let davError = error as? SwiftXDAVError else {
        return "An unexpected error occurred"
    }

    switch davError {
    case .authenticationFailed:
        return "Invalid username or password"

    case .unauthorized:
        return "Your account doesn't have permission to access this resource"

    case .networkError:
        return "Network connection failed. Please check your internet connection."

    case .serverError(let statusCode, _):
        if statusCode >= 500 {
            return "The server is experiencing issues. Please try again later."
        } else {
            return "The server rejected your request"
        }

    case .notFound:
        return "The requested calendar or event was not found"

    case .conflict:
        return "This item already exists"

    case .preconditionFailed, .etagMismatch:
        return "This item was modified by another device. Please refresh and try again."

    case .syncTokenInvalid:
        return "Sync data is outdated. Performing full sync..."

    case .parsingError:
        return "Received invalid data from the server"

    case .invalidData, .unsupportedFormat:
        return "The data format is not supported"

    case .discoveryFailed:
        return "Could not find calendar server. Please check the server address."

    case .unsupportedServer:
        return "This server doesn't support calendar or contact syncing"

    case .invalidURL:
        return "Invalid server address"

    case .missingProperty:
        return "The server didn't provide required information"

    case .internalError:
        return "An internal error occurred"
    }
}

// Usage
do {
    let calendars = try await client.listCalendars()
} catch {
    let message = userFriendlyMessage(for: error)
    showAlert(title: "Error", message: message)
}
```

## Logging and Debugging

### Comprehensive Error Logging

```swift
actor ErrorLogger {
    func log(_ error: Error, context: String) {
        let timestamp = ISO8601DateFormatter().string(from: Date())

        if let davError = error as? SwiftXDAVError {
            print("[\(timestamp)] SwiftXDAV Error in \(context):")
            print("  Type: \(davError)")

            switch davError {
            case .networkError(let underlyingError):
                print("  Underlying: \(underlyingError)")

            case .serverError(let statusCode, let message):
                print("  Status: \(statusCode)")
                print("  Message: \(message ?? "none")")

            case .parsingError(let details):
                print("  Details: \(details)")

            default:
                break
            }
        } else {
            print("[\(timestamp)] Unknown Error in \(context): \(error)")
        }

        // Send to analytics or crash reporting service
        sendToAnalytics(error: error, context: context)
    }

    private func sendToAnalytics(error: Error, context: String) {
        // Integrate with your analytics service
        // e.g., Firebase, Sentry, etc.
    }
}

// Usage
let logger = ErrorLogger()

do {
    let calendars = try await client.listCalendars()
} catch {
    await logger.log(error, context: "Fetching calendars")
    throw error
}
```

### Debug Mode

```swift
#if DEBUG
extension SwiftXDAVError {
    var debugDescription: String {
        switch self {
        case .authenticationFailed:
            return "Authentication failed - check credentials"

        case .networkError(let error):
            let nsError = error as NSError
            return "Network error: \(nsError.domain) code \(nsError.code)"

        case .serverError(let statusCode, let message):
            return "Server error \(statusCode): \(message ?? "no message")"

        case .parsingError(let details):
            return "Parsing error: \(details)"

        case .syncTokenInvalid:
            return "Sync token invalid - need full sync"

        default:
            return "\(self)"
        }
    }
}
#endif
```

## Best Practices

### 1. Always Handle Specific Error Cases

```swift
// ✅ Good - handles specific errors
do {
    let calendars = try await client.listCalendars()
} catch SwiftXDAVError.authenticationFailed {
    showLoginScreen()
} catch SwiftXDAVError.networkError {
    showOfflineAlert()
} catch {
    showGenericError(error)
}

// ❌ Bad - generic error handling only
do {
    let calendars = try await client.listCalendars()
} catch {
    print("Error: \(error)")
}
```

### 2. Don't Swallow Errors

```swift
// ✅ Good - propagates error
func fetchCalendars() async throws -> [Calendar] {
    return try await client.listCalendars()
}

// ❌ Bad - swallows error
func fetchCalendars() async -> [Calendar]? {
    do {
        return try await client.listCalendars()
    } catch {
        return nil // Lost all error information!
    }
}
```

### 3. Provide Context in Errors

```swift
// ✅ Good - adds context
do {
    let event = try await client.fetchEvent(uid: uid, from: calendar)
} catch {
    throw SwiftXDAVError.internalError("Failed to fetch event \(uid): \(error)")
}
```

### 4. Use Result Type for Optional Operations

```swift
func tryFetchEvent(uid: String) async -> Result<VEvent, SwiftXDAVError> {
    do {
        let event = try await client.fetchEvent(uid: uid, from: calendar)
        return .success(event)
    } catch let error as SwiftXDAVError {
        return .failure(error)
    } catch {
        return .failure(.internalError("Unexpected error: \(error)"))
    }
}

// Usage
let result = await tryFetchEvent(uid: "12345")
switch result {
case .success(let event):
    print("Found: \(event.summary ?? "Untitled")")
case .failure(let error):
    print("Error: \(error)")
}
```

### 5. Implement Graceful Degradation

```swift
func fetchAllCalendars() async -> [Calendar] {
    do {
        return try await client.listCalendars()
    } catch SwiftXDAVError.networkError {
        // Return cached calendars if offline
        return await cachedCalendars()
    } catch {
        // Return empty array for other errors
        // Log error for investigation
        await logger.log(error, context: "Fetch calendars")
        return []
    }
}
```

## See Also

- ``SwiftXDAVError``
- <doc:GettingStarted>
- <doc:Authentication>
- <doc:CalDAVGuide>
- <doc:CardDAVGuide>
