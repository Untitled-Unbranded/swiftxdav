# Authentication

Learn how to authenticate with different CalDAV and CardDAV servers using various authentication methods.

## Overview

SwiftXDAV supports multiple authentication methods to work with different servers:

- **Basic Authentication**: Username and password (most common)
- **OAuth 2.0**: For Google Calendar/Contacts and other OAuth-enabled servers
- **App-Specific Passwords**: For iCloud (required with 2FA)
- **Bearer Tokens**: For custom authentication schemes

## Basic Authentication

Basic Authentication is the most common method and works with most CalDAV/CardDAV servers.

### Standard Basic Auth

```swift
import SwiftXDAV

// Create HTTP client with basic auth
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .basic(
        username: "user@example.com",
        password: "your-password"
    )
)

// Create CalDAV client
let client = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://caldav.example.com")!
)
```

### Self-Hosted Servers

Most self-hosted servers use basic authentication:

#### Nextcloud

```swift
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .basic(
        username: "your-username",
        password: "your-password"
    )
)

let client = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://nextcloud.example.com/remote.php/dav")!
)
```

#### Radicale

```swift
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .basic(
        username: "your-username",
        password: "your-password"
    )
)

let client = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://radicale.example.com/your-username")!
)
```

#### SOGo

```swift
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .basic(
        username: "your-username",
        password: "your-password"
    )
)

let client = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://sogo.example.com/SOGo/dav")!
)
```

#### Baikal

```swift
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .basic(
        username: "your-username",
        password: "your-password"
    )
)

let client = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://baikal.example.com/dav.php")!
)
```

## iCloud Authentication

iCloud requires **app-specific passwords** when two-factor authentication (2FA) is enabled.

### Generating App-Specific Passwords

1. Go to [appleid.apple.com](https://appleid.apple.com)
2. Sign in with your Apple ID
3. Navigate to **Security**
4. Under **App-Specific Passwords**, click **Generate Password**
5. Enter a label (e.g., "My Calendar App")
6. Copy the generated password (format: `xxxx-xxxx-xxxx-xxxx`)

### Using iCloud with SwiftXDAV

```swift
import SwiftXDAV

// Use the convenience method
let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// Or create manually
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .basic(
        username: "user@icloud.com",
        password: "abcd-efgh-ijkl-mnop"
    )
)

let calDAVClient = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://caldav.icloud.com")!
)

let cardDAVClient = CardDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://contacts.icloud.com")!
)
```

### Important Notes for iCloud

- App-specific passwords are **required** if 2FA is enabled
- Regular passwords will **not work** with 2FA enabled
- Each app should have its own app-specific password
- Passwords can be revoked at any time from appleid.apple.com
- Format is always `xxxx-xxxx-xxxx-xxxx` (16 characters with dashes)

## OAuth 2.0 Authentication

OAuth 2.0 is required for Google Calendar/Contacts and other OAuth-enabled services.

### Setting Up Google OAuth

1. Go to [Google Cloud Console](https://console.cloud.google.com)
2. Create a new project or select existing
3. Enable **Calendar API** and/or **People API**
4. Create OAuth 2.0 credentials:
   - Go to **APIs & Services > Credentials**
   - Click **Create Credentials > OAuth 2.0 Client ID**
   - Choose application type (iOS, macOS, etc.)
   - Add redirect URI (e.g., `com.yourapp:/oauth/callback`)

### OAuth Flow with SwiftXDAV

```swift
import SwiftXDAV

// Create token manager
let tokenManager = OAuth2TokenManager(
    clientID: "your-client-id.apps.googleusercontent.com",
    clientSecret: "your-client-secret",
    redirectURI: "com.yourapp:/oauth/callback",
    tokenURL: URL(string: "https://oauth2.googleapis.com/token")!,
    authURL: URL(string: "https://accounts.google.com/o/oauth2/v2/auth")!
)

// Step 1: Get authorization URL
let authURL = tokenManager.authorizationURL(
    scopes: [
        "https://www.googleapis.com/auth/calendar",
        "https://www.googleapis.com/auth/contacts"
    ]
)

// Step 2: Open URL in browser or web view
#if os(iOS)
UIApplication.shared.open(authURL)
#elseif os(macOS)
NSWorkspace.shared.open(authURL)
#endif

// Step 3: Handle redirect (in your app delegate or scene delegate)
func handleOAuthCallback(url: URL) async {
    // Extract authorization code from URL
    guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
          let code = components.queryItems?.first(where: { $0.name == "code" })?.value else {
        return
    }

    // Exchange code for token
    do {
        try await tokenManager.exchangeCode(code)
        print("Authentication successful!")

        // Create clients
        let calDAVClient = CalDAVClient.google(tokenManager: tokenManager)
        let cardDAVClient = CardDAVClient.google(tokenManager: tokenManager)

        // Use clients
        let calendars = try await calDAVClient.listCalendars()
        print("Found \(calendars.count) calendars")
    } catch {
        print("Authentication failed: \(error)")
    }
}
```

### Token Refresh

OAuth tokens expire and need to be refreshed:

```swift
// The token manager automatically refreshes expired tokens
let calDAVClient = CalDAVClient.google(tokenManager: tokenManager)

// This will automatically refresh the token if expired
do {
    let calendars = try await calDAVClient.listCalendars()
} catch SwiftXDAVError.authenticationFailed {
    // Token refresh failed - user needs to re-authenticate
    let authURL = tokenManager.authorizationURL(scopes: [...])
    // Show auth URL to user
}
```

### Persisting OAuth Tokens

Store tokens securely between app launches:

```swift
import Security

actor SecureTokenStorage {
    func saveToken(_ token: OAuth2Token) throws {
        let data = try JSONEncoder().encode(token)

        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "oauth_token",
            kSecValueData as String: data
        ]

        // Delete any existing token
        SecItemDelete(query as CFDictionary)

        // Add new token
        let status = SecItemAdd(query as CFDictionary, nil)
        guard status == errSecSuccess else {
            throw SwiftXDAVError.invalidData("Failed to save token: \(status)")
        }
    }

    func loadToken() throws -> OAuth2Token? {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "oauth_token",
            kSecReturnData as String: true
        ]

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)

        guard status == errSecSuccess,
              let data = result as? Data else {
            return nil
        }

        return try JSONDecoder().decode(OAuth2Token.self, from: data)
    }

    func deleteToken() throws {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrAccount as String: "oauth_token"
        ]

        SecItemDelete(query as CFDictionary)
    }
}

// Usage
let storage = SecureTokenStorage()

// After successful OAuth
if let token = tokenManager.currentToken {
    try await storage.saveToken(token)
}

// On app launch
if let savedToken = try await storage.loadToken() {
    tokenManager.restoreToken(savedToken)
    let client = CalDAVClient.google(tokenManager: tokenManager)
}
```

## Bearer Token Authentication

For custom authentication schemes using bearer tokens:

```swift
let httpClient = AuthenticatedHTTPClient(
    baseClient: AlamofireHTTPClient(),
    authentication: .bearer(token: "your-bearer-token")
)

let client = CalDAVClient(
    httpClient: httpClient,
    baseURL: URL(string: "https://api.example.com/caldav")!
)
```

## Custom Authentication

Implement `HTTPClient` protocol for custom authentication:

```swift
actor CustomAuthHTTPClient: HTTPClient {
    private let baseClient: HTTPClient
    private let apiKey: String

    init(baseClient: HTTPClient, apiKey: String) {
        self.baseClient = baseClient
        self.apiKey = apiKey
    }

    func request(
        method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        // Add custom authentication header
        var authHeaders = headers ?? [:]
        authHeaders["X-API-Key"] = apiKey

        return try await baseClient.request(
            method: method,
            url: url,
            headers: authHeaders,
            body: body
        )
    }
}

// Usage
let customClient = CustomAuthHTTPClient(
    baseClient: AlamofireHTTPClient(),
    apiKey: "your-api-key"
)

let calDAVClient = CalDAVClient(
    httpClient: customClient,
    baseURL: URL(string: "https://api.example.com/caldav")!
)
```

## Security Best Practices

### 1. Never Hardcode Credentials

```swift
// ❌ Bad - credentials in code
let client = CalDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// ✅ Good - credentials from secure storage or user input
let username = try await keychain.getString(key: "username")
let password = try await keychain.getString(key: "password")
let client = CalDAVClient.iCloud(
    username: username,
    appSpecificPassword: password
)
```

### 2. Use HTTPS Only

```swift
// ✅ Good
let url = URL(string: "https://caldav.example.com")!

// ❌ Bad - unencrypted
let url = URL(string: "http://caldav.example.com")!
```

### 3. Store Tokens Securely

Use Keychain for storing sensitive data:

```swift
import Security

func saveToKeychain(key: String, value: String) throws {
    guard let data = value.data(using: .utf8) else {
        throw SwiftXDAVError.invalidData("Invalid string")
    }

    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecValueData as String: data,
        kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlock
    ]

    SecItemDelete(query as CFDictionary)
    let status = SecItemAdd(query as CFDictionary, nil)

    guard status == errSecSuccess else {
        throw SwiftXDAVError.invalidData("Keychain save failed: \(status)")
    }
}

func loadFromKeychain(key: String) throws -> String? {
    let query: [String: Any] = [
        kSecClass as String: kSecClassGenericPassword,
        kSecAttrAccount as String: key,
        kSecReturnData as String: true
    ]

    var result: AnyObject?
    let status = SecItemCopyMatching(query as CFDictionary, &result)

    guard status == errSecSuccess,
          let data = result as? Data,
          let string = String(data: data, encoding: .utf8) else {
        return nil
    }

    return string
}
```

### 4. Handle Authentication Errors Gracefully

```swift
do {
    let calendars = try await client.listCalendars()
} catch SwiftXDAVError.authenticationFailed {
    // Show login screen
    await showLoginScreen()
} catch SwiftXDAVError.unauthorized {
    // Credentials expired, refresh or re-authenticate
    await refreshCredentials()
}
```

### 5. Clear Credentials on Logout

```swift
func logout() async throws {
    // Clear OAuth tokens
    try await tokenStorage.deleteToken()

    // Clear basic auth credentials
    try deleteFromKeychain(key: "username")
    try deleteFromKeychain(key: "password")

    // Clear any cached data
    await localCache.clear()
}
```

## Testing Authentication

### Mock Authentication for Tests

```swift
actor MockHTTPClient: HTTPClient {
    var shouldFailAuth = false

    func request(
        method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        if shouldFailAuth {
            throw SwiftXDAVError.authenticationFailed
        }

        // Return mock response
        return HTTPResponse(
            statusCode: 200,
            headers: [:],
            body: Data()
        )
    }
}

// In tests
let mockClient = MockHTTPClient()
let calDAVClient = CalDAVClient(
    httpClient: mockClient,
    baseURL: URL(string: "https://test.example.com")!
)

// Test authentication failure
mockClient.shouldFailAuth = true
do {
    let calendars = try await calDAVClient.listCalendars()
    XCTFail("Should have thrown authentication error")
} catch SwiftXDAVError.authenticationFailed {
    // Expected
}
```

## Troubleshooting

### Common Authentication Issues

#### 401 Unauthorized

```swift
// Possible causes:
// 1. Wrong username or password
// 2. 2FA required but not using app-specific password (iCloud)
// 3. OAuth token expired
// 4. Account locked or disabled

// Solution: Verify credentials and check server requirements
```

#### 403 Forbidden

```swift
// Possible causes:
// 1. Account doesn't have permission to access CalDAV/CardDAV
// 2. Server requires specific scopes (OAuth)
// 3. IP address blocked

// Solution: Check account permissions and OAuth scopes
```

#### SSL/TLS Errors

```swift
// If using self-signed certificates (development only):
let httpClient = AlamofireHTTPClient(allowInvalidCertificates: true)

// ⚠️ WARNING: Never use this in production!
```

## See Also

- ``AuthenticatedHTTPClient``
- ``OAuth2HTTPClient``
- ``OAuth2TokenManager``
- ``HTTPClient``
- <doc:GettingStarted>
- <doc:ErrorHandling>
