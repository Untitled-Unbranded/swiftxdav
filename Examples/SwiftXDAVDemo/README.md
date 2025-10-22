# SwiftXDAV Demo App

A multiplatform (iOS/macOS) example application demonstrating the SwiftXDAV framework.

## Features

This demo app provides read-only access to:

- **CalDAV**
  - List calendars
  - View events (next 90 days)
  - View todos/tasks

- **CardDAV**
  - List address books
  - View contacts

## Supported Servers

- iCloud (with app-specific passwords)
- Generic CalDAV/CardDAV servers
- Nextcloud
- Radicale
- Other RFC-compliant servers

**Note:** OAuth2 (Google) is not implemented in this demo, but the framework supports it.

## Building

From the SwiftXDAVDemo directory:

```bash
# Build for macOS
swift build

# Run on macOS
swift run

# Or open in Xcode (requires creating Xcode project)
```

## Usage

1. **Login**
   - Select your server type
   - Enter server URL (auto-filled for common types)
   - Enter username and password
   - For iCloud: use an app-specific password from appleid.apple.com

2. **Browse Data**
   - Navigate to Calendars tab to see your calendars
   - Tap a calendar to load its events
   - Navigate to Address Books tab to see your address books
   - Tap an address book to load its contacts
   - Use the Todos tab to load tasks from a selected calendar

3. **Settings**
   - View connection details
   - See data statistics
   - Clear loaded data
   - Disconnect from server

## Architecture

```
Models/
  ├── ServerType.swift        # Server type enumeration
  └── AppState.swift          # Main app state (@Observable)

ViewModels/
  ├── AuthenticationViewModel.swift  # Authentication logic
  ├── CalDAVViewModel.swift          # CalDAV operations
  └── CardDAVViewModel.swift         # CardDAV operations

Views/
  ├── LoginView.swift         # Authentication UI
  ├── ContentView.swift       # Main container (tabs/sidebar)
  ├── CalendarsView.swift     # Calendar list
  ├── EventsView.swift        # Event list
  ├── TodosView.swift         # Todo/task list
  ├── AddressBooksView.swift  # Address book list
  ├── ContactsView.swift      # Contact list
  └── SettingsView.swift      # Settings and disconnect
```

## Notes

- All operations are **read-only** - no data is modified on the server
- The app uses Swift 6.0 strict concurrency
- UI is built with SwiftUI and works on both iOS and macOS
- Error handling displays user-friendly messages
- Data is displayed as-is from the server (no local storage)

## Testing with iCloud

1. Go to https://appleid.apple.com
2. Sign in with your Apple ID
3. Navigate to Security > App-Specific Passwords
4. Generate a new password
5. Use format: `xxxx-xxxx-xxxx-xxxx`

## Common Issues

**"Authentication failed"**
- Check username and password
- For iCloud: ensure you're using an app-specific password, not your Apple ID password

**"Discovery failed"**
- Verify server URL is correct
- Check that server supports CalDAV/CardDAV
- Ensure network connectivity

**"No calendars found"**
- Server may not have any calendars created
- Check account permissions

## License

This example app is part of the SwiftXDAV project and uses the same MIT license.
