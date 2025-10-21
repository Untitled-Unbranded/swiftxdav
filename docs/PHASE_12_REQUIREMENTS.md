# Phase 12: Testing, Documentation, and Google API Integration

**Status:** 📋 PLANNED
**Date:** 2025-10-21

## Overview

Phase 12 is the final phase of the SwiftXDAV implementation. It focuses on production readiness, comprehensive testing, documentation, and adding direct Google API support.

## Requirements

### 1. Google API Direct Integration ⭐ NEW

Instead of using Google's limited CalDAV/CardDAV support, implement direct API clients using Google's native APIs.

#### Google Calendar API v3

**Why Direct API?**
- Google's CalDAV implementation is limited and has quirks
- Native API provides better performance and features
- Access to Google-specific features (colors, reminders, attachments)
- Better sync performance with native sync tokens
- More reliable OAuth 2.0 integration

**Implementation Tasks:**
- Create `GoogleCalendarClient` using Google Calendar API v3
- OAuth 2.0 authentication flow
- Calendar list and discovery
- Event CRUD operations (Create, Read, Update, Delete)
- Event search and filtering
- Batch operations for efficiency
- Sync token-based synchronization
- Recurring event expansion (Google handles this server-side)
- Attendee management
- Attachment support
- Color and visibility settings

**API Endpoints:**
- `GET /calendars/{calendarId}/events` - List events
- `GET /calendars/{calendarId}/events/{eventId}` - Get event
- `POST /calendars/{calendarId}/events` - Create event
- `PUT /calendars/{calendarId}/events/{eventId}` - Update event
- `DELETE /calendars/{calendarId}/events/{eventId}` - Delete event
- `POST /calendars/{calendarId}/events/import` - Import event
- `GET /users/me/calendarList` - List calendars

**Files to Create:**
- `Sources/SwiftXDAVGoogleCalendar/Client/GoogleCalendarClient.swift`
- `Sources/SwiftXDAVGoogleCalendar/Models/GoogleEvent.swift`
- `Sources/SwiftXDAVGoogleCalendar/Models/GoogleCalendar.swift`
- `Sources/SwiftXDAVGoogleCalendar/Auth/GoogleOAuth.swift`
- `Tests/SwiftXDAVGoogleCalendarTests/`

#### Google People API (Contacts)

**Why Direct API?**
- Google's CardDAV is very limited
- Native API provides full contact features
- Access to Google-specific data (photos, relationships, organizations)
- Better sync with native sync tokens

**Implementation Tasks:**
- Create `GooglePeopleClient` using People API v1
- OAuth 2.0 authentication flow
- Contact list and discovery
- Contact CRUD operations
- Contact groups (labels)
- Batch operations
- Sync token-based synchronization
- Photo handling
- Custom fields support

**API Endpoints:**
- `GET /people/me/connections` - List contacts
- `GET /people/{resourceName}` - Get contact
- `POST /people:createContact` - Create contact
- `PATCH /people/{resourceName}:updateContact` - Update contact
- `DELETE /people/{resourceName}:deleteContact` - Delete contact
- `GET /contactGroups` - List contact groups
- `POST /people:batchGet` - Batch get contacts

**Files to Create:**
- `Sources/SwiftXDAVGooglePeople/Client/GooglePeopleClient.swift`
- `Sources/SwiftXDAVGooglePeople/Models/GooglePerson.swift`
- `Sources/SwiftXDAVGooglePeople/Models/GoogleContactGroup.swift`
- `Sources/SwiftXDAVGooglePeople/Auth/GoogleOAuth.swift` (shared with Calendar)
- `Tests/SwiftXDAVGooglePeopleTests/`

#### Package.swift Updates

Add new library products:
```swift
.library(name: "SwiftXDAVGoogleCalendar", targets: ["SwiftXDAVGoogleCalendar"]),
.library(name: "SwiftXDAVGooglePeople", targets: ["SwiftXDAVGooglePeople"]),
```

### 2. GitHub Pages Documentation Pipeline ⭐ NEW

Automatically generate and publish DocC documentation to GitHub Pages.

#### GitHub Actions Workflow

**File:** `.github/workflows/documentation.yml`

**Triggers:**
- Push to `main` branch (with changes to Swift files)
- Manual workflow dispatch
- Release tags

**Steps:**
1. Checkout repository
2. Setup Swift environment
3. Build DocC documentation
4. Convert DocC archive to static HTML
5. Deploy to GitHub Pages

**Tools:**
- Swift-DocC
- Swift-DocC-Render (for static site generation)
- GitHub Pages deployment action

**Features:**
- Versioned documentation (main + releases)
- Automatic index page with module navigation
- Search functionality
- Dark mode support
- Mobile responsive

**Files to Create:**
- `.github/workflows/documentation.yml` - Main workflow
- `.github/workflows/documentation-pr.yml` - PR preview (optional)
- `Documentation.docc/` - Documentation catalog with articles
- `README.md` - Update with link to documentation

#### Documentation Structure

```
Documentation.docc/
├── SwiftXDAV.md                    # Landing page
├── GettingStarted.md               # Quick start guide
├── CalDAV/
│   ├── CalDAV-Overview.md
│   ├── CalDAV-Authentication.md
│   └── CalDAV-Sync.md
├── CardDAV/
│   ├── CardDAV-Overview.md
│   └── CardDAV-Sync.md
├── GoogleAPIs/
│   ├── Google-Calendar.md
│   └── Google-Contacts.md
├── Recurrence/
│   └── Recurrence-Rules.md
└── Resources/
    └── images/
```

### 3. Test Quality Standards ⭐ NEW

Ensure all tests are enabled and passing - no disabled/skipped tests in the codebase.

#### Test Audit Tasks

1. **Inventory all tests:**
   - Scan codebase for disabled tests (`XCTSkip`, commented out tests, etc.)
   - Document why each test is disabled
   - Create plan to fix or remove each disabled test

2. **Fix or remove disabled tests:**
   - Fix tests that are failing due to bugs
   - Update tests that are failing due to API changes
   - Remove tests that are no longer relevant
   - NEVER keep disabled tests in the codebase

3. **Test coverage requirements:**
   - Unit test coverage > 80% for all modules
   - Integration tests for each server type:
     - iCloud CalDAV/CardDAV
     - Nextcloud CalDAV/CardDAV
     - Radicale CalDAV/CardDAV
     - Google Calendar API v3
     - Google People API
   - End-to-end tests for complete workflows

4. **CI/CD Integration:**
   - GitHub Actions workflow for running tests
   - Test on multiple Swift versions (6.0+)
   - Test on multiple platforms (macOS, Linux if applicable)
   - Fail CI if any test is disabled
   - Fail CI if coverage drops below threshold

**Files to Create:**
- `.github/workflows/tests.yml` - CI test workflow
- `.github/workflows/coverage.yml` - Coverage reporting
- `Tests/IntegrationTests/` - Server integration tests
- `Tests/E2ETests/` - End-to-end tests

### 4. Comprehensive Unit Tests

Complete test coverage for all modules.

#### Core Module Tests
- ✅ Error types
- ✅ Sync models (Phase 10)
- ⏳ Additional models
- ⏳ Utilities

#### Network Module Tests
- ✅ WebDAV operations (Phase 4)
- ✅ Sync collection (Phase 10)
- ⏳ Authentication flows
- ⏳ Request/response handling

#### Calendar Module Tests
- ✅ iCalendar parser (Phase 5)
- ✅ iCalendar serializer (Phase 5)
- ✅ Recurrence engine (Phase 11)
- ✅ CalDAV client (Phase 7)
- ✅ CalDAV sync (Phase 10)
- ⏳ Timezone handling
- ⏳ Edge cases

#### Contacts Module Tests
- ✅ vCard parser (Phase 6)
- ✅ vCard serializer (Phase 6)
- ✅ CardDAV client (Phase 8)
- ✅ CardDAV sync (Phase 10)
- ⏳ Edge cases

#### Google Calendar Tests (NEW)
- ⏳ OAuth flow
- ⏳ Calendar operations
- ⏳ Event CRUD
- ⏳ Sync operations
- ⏳ Batch operations

#### Google People Tests (NEW)
- ⏳ OAuth flow
- ⏳ Contact operations
- ⏳ Contact CRUD
- ⏳ Contact groups
- ⏳ Sync operations

### 5. Integration Tests

Test against real servers (with test accounts).

#### Test Servers

**iCloud:**
- Use test Apple ID with app-specific password
- Test calendar and contact operations
- Test sync operations

**Google:**
- Use test Google account with OAuth 2.0
- Test Calendar API v3
- Test People API
- Test sync tokens

**Nextcloud:**
- Use public test instance or Docker container
- Test CalDAV and CardDAV
- Test WebDAV sync

**Radicale:**
- Use Docker container for CI
- Test CalDAV and CardDAV
- Test sync-token support

**Files:**
- `Tests/IntegrationTests/iCloudIntegrationTests.swift`
- `Tests/IntegrationTests/GoogleIntegrationTests.swift`
- `Tests/IntegrationTests/NextcloudIntegrationTests.swift`
- `Tests/IntegrationTests/RadicaleIntegrationTests.swift`
- `Tests/IntegrationTests/TestCredentials.swift` (with .gitignore)

### 6. Example Application

Demonstrate framework usage with a real application.

#### Features
- Multi-platform (iOS + macOS with SwiftUI)
- Account management (iCloud, Google, self-hosted)
- Calendar view with events
- Contact list
- Sync status and controls
- Settings and preferences

**Files:**
- `Examples/SwiftXDAVExample/` - Example app project
- `Examples/SwiftXDAVExample/README.md` - Setup instructions

### 7. Documentation

Complete DocC documentation for all public APIs.

#### Requirements
- Every public type must have documentation
- Every public method must have documentation
- Every parameter must be documented
- Usage examples for complex features
- Architecture documentation
- Migration guides (if needed)

#### Documentation Coverage
- SwiftXDAVCore: 100%
- SwiftXDAVNetwork: 100%
- SwiftXDAVCalendar: 100%
- SwiftXDAVContacts: 100%
- SwiftXDAVGoogleCalendar: 100% (NEW)
- SwiftXDAVGooglePeople: 100% (NEW)

### 8. README and Guides

User-facing documentation for developers using the framework.

#### README.md
- Project overview
- Features list
- Installation instructions (SPM)
- Quick start guide
- Link to full documentation (GitHub Pages)
- Server compatibility matrix
- Requirements and dependencies
- License
- Contributing guidelines

#### Quick Start Guide
- Creating a CalDAV client
- Listing calendars and events
- Creating and updating events
- Synchronization
- Creating a CardDAV client
- Managing contacts
- Using Google APIs directly

## Success Criteria

Phase 12 is complete when ALL of these are true:

### Google API Integration
- [ ] GoogleCalendarClient implemented with full CRUD
- [ ] GooglePeopleClient implemented with full CRUD
- [ ] OAuth 2.0 authentication working
- [ ] Sync token-based sync working for both APIs
- [ ] Batch operations supported
- [ ] Integration tests pass against real Google account

### Documentation
- [ ] GitHub Actions workflow publishes DocC to GitHub Pages
- [ ] Documentation site is live and accessible
- [ ] All public APIs have DocC comments
- [ ] Documentation includes usage examples
- [ ] Getting Started guide complete
- [ ] API reference complete

### Testing
- [ ] NO disabled/skipped tests in codebase
- [ ] All unit tests pass (100%)
- [ ] Unit test coverage > 80%
- [ ] Integration tests pass for all servers:
  - [ ] iCloud CalDAV/CardDAV
  - [ ] Google Calendar API v3
  - [ ] Google People API
  - [ ] Nextcloud CalDAV/CardDAV
  - [ ] Radicale CalDAV/CardDAV
- [ ] End-to-end tests pass
- [ ] CI/CD pipeline runs all tests
- [ ] CI fails if tests are disabled

### Example App
- [ ] Example app builds and runs
- [ ] Demonstrates calendar operations
- [ ] Demonstrates contact operations
- [ ] Shows iCloud integration
- [ ] Shows Google API integration
- [ ] Shows sync operations

### Quality
- [ ] Swift 6.0 strict concurrency compliance
- [ ] No force unwraps or force casts
- [ ] No compiler warnings
- [ ] Code follows Swift API Design Guidelines
- [ ] All TODOs resolved or converted to GitHub issues

### Documentation Files
- [ ] README.md complete with badges
- [ ] CHANGELOG.md maintained
- [ ] LICENSE file present
- [ ] CONTRIBUTING.md present
- [ ] GitHub Pages site live

## Implementation Order

1. **Test Audit and Cleanup** (Week 1)
   - Audit all existing tests
   - Fix or remove disabled tests
   - Ensure 100% tests passing

2. **Google Calendar API Integration** (Week 2)
   - Implement GoogleCalendarClient
   - OAuth 2.0 flow
   - Event CRUD operations
   - Sync implementation
   - Unit and integration tests

3. **Google People API Integration** (Week 3)
   - Implement GooglePeopleClient
   - OAuth 2.0 flow (shared with Calendar)
   - Contact CRUD operations
   - Sync implementation
   - Unit and integration tests

4. **GitHub Pages Documentation** (Week 4)
   - Create GitHub Actions workflow
   - Setup DocC documentation structure
   - Write documentation articles
   - Test and deploy

5. **Example Application** (Week 5)
   - Create SwiftUI example app
   - Implement calendar view
   - Implement contact view
   - Add account management
   - Polish UI/UX

6. **Final Testing and Polish** (Week 6)
   - Complete integration tests
   - End-to-end tests
   - Performance testing
   - Documentation review
   - Final README and guides

## Notes

### Why Google APIs Instead of CalDAV/CardDAV?

**Google Calendar API v3 advantages:**
- More reliable than Google's CalDAV implementation
- Better performance (native protocol)
- Access to Google-specific features
- Better error messages
- Official SDK patterns

**Google People API advantages:**
- Google's CardDAV is extremely limited
- People API provides full contact data
- Better sync performance
- Access to photos and extended fields

### Architecture Implications

With Google API clients, the framework will have:
- **Core protocol support:** WebDAV, CalDAV, CardDAV (for iCloud, Nextcloud, Radicale, etc.)
- **Google-specific clients:** Direct REST API clients
- **Unified interfaces:** Common protocols that both implementations conform to

This provides the best of both worlds:
- Standards-based for open servers
- Native APIs for Google's services

### Testing Strategy

**Unit Tests:** Fast, isolated, no network
**Integration Tests:** Against real servers, with credentials
**E2E Tests:** Complete user workflows

CI runs unit tests on every commit.
Integration tests run nightly or manually (require credentials).

---

**Last Updated:** 2025-10-21
**Phase:** 12 - PLANNED
**Dependencies:** Phases 1-11 complete
