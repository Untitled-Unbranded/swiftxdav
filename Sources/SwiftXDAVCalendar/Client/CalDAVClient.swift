import Foundation
import SwiftXDAVCore
import SwiftXDAVNetwork

/// A client for interacting with CalDAV servers (RFC 4791)
///
/// `CalDAVClient` provides a high-level interface for discovering calendars,
/// fetching events, and syncing calendar data with CalDAV servers.
///
/// ## Usage
///
/// Create a client with your server URL and credentials:
///
/// ```swift
/// let client = CalDAVClient.iCloud(
///     username: "user@icloud.com",
///     appSpecificPassword: "abcd-efgh-ijkl-mnop"
/// )
/// ```
///
/// List calendars:
///
/// ```swift
/// let calendars = try await client.listCalendars()
/// for calendar in calendars {
///     print("\(calendar.displayName): \(calendar.url)")
/// }
/// ```
///
/// Fetch events:
///
/// ```swift
/// let events = try await client.fetchEvents(
///     from: calendar,
///     start: Date(),
///     end: Date().addingTimeInterval(86400 * 30) // 30 days
/// )
/// ```
///
/// ## Topics
///
/// ### Creating a Client
/// - ``init(httpClient:baseURL:)``
/// - ``iCloud(username:appSpecificPassword:)``
///
/// ### Discovery
/// - ``discoverPrincipal()``
/// - ``discoverCalendarHome()``
///
/// ### Working with Calendars
/// - ``listCalendars()``
/// - ``listCalendars(at:)``
///
/// ### Working with Events
/// - ``fetchEvents(from:start:end:)``
/// - ``createEvent(_:in:)``
/// - ``updateEvent(_:in:etag:)``
/// - ``deleteEvent(uid:from:)``
public actor CalDAVClient {
    internal let httpClient: HTTPClient
    internal let baseURL: URL

    // Cached discovery results
    private var cachedPrincipalURL: URL?
    private var cachedCalendarHomeURL: URL?

    /// Initialize a CalDAV client
    ///
    /// - Parameters:
    ///   - httpClient: The HTTP client to use for requests
    ///   - baseURL: The base URL of the CalDAV server
    public init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    // MARK: - Discovery

    /// Discover the current user's principal URL
    ///
    /// This performs a PROPFIND on the base URL to find the `current-user-principal` property.
    ///
    /// - Returns: The principal URL
    /// - Throws: `SwiftXDAVError` if discovery fails
    public func discoverPrincipal() async throws -> URL {
        if let cached = cachedPrincipalURL {
            return cached
        }

        let request = PropfindRequest(
            url: baseURL,
            depth: 0,
            properties: [DAVPropertyName.currentUserPrincipal]
        )

        let responses = try await request.execute(using: httpClient)

        guard let response = responses.first else {
            throw SwiftXDAVError.notFound
        }

        // Parse the current-user-principal href
        guard let principalHref = response.property(named: "current-user-principal") else {
            throw SwiftXDAVError.parsingError("current-user-principal property not found")
        }

        // Clean up the href (remove XML fragments if present)
        let cleanHref = cleanHref(principalHref)

        guard let principalURL = URL(string: cleanHref, relativeTo: baseURL)?.absoluteURL else {
            throw SwiftXDAVError.invalidData("Invalid principal URL: \(cleanHref)")
        }

        cachedPrincipalURL = principalURL
        return principalURL
    }

    /// Discover the calendar home set URL
    ///
    /// This performs a PROPFIND on the principal URL to find the `calendar-home-set` property.
    ///
    /// - Returns: The calendar home URL
    /// - Throws: `SwiftXDAVError` if discovery fails
    public func discoverCalendarHome() async throws -> URL {
        if let cached = cachedCalendarHomeURL {
            return cached
        }

        let principalURL = try await discoverPrincipal()

        let request = PropfindRequest(
            url: principalURL,
            depth: 0,
            properties: [CalDAVPropertyName.calendarHomeSet]
        )

        let responses = try await request.execute(using: httpClient)

        guard let response = responses.first else {
            throw SwiftXDAVError.notFound
        }

        guard let calendarHomeHref = response.property(named: "calendar-home-set") else {
            throw SwiftXDAVError.parsingError("calendar-home-set property not found")
        }

        // Clean up the href
        let cleanHomeHref = cleanHref(calendarHomeHref)

        guard let calendarHomeURL = URL(string: cleanHomeHref, relativeTo: baseURL)?.absoluteURL else {
            throw SwiftXDAVError.invalidData("Invalid calendar home URL: \(cleanHomeHref)")
        }

        cachedCalendarHomeURL = calendarHomeURL
        return calendarHomeURL
    }

    // MARK: - Calendar Operations

    /// List all calendars for the current user
    ///
    /// - Returns: An array of calendars
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func listCalendars() async throws -> [Calendar] {
        let calendarHome = try await discoverCalendarHome()
        return try await listCalendars(at: calendarHome)
    }

    /// List calendars at a specific URL
    ///
    /// - Parameter url: The URL to query for calendars
    /// - Returns: An array of calendars
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func listCalendars(at url: URL) async throws -> [Calendar] {
        let request = PropfindRequest(
            url: url,
            depth: 1,
            properties: [
                DAVPropertyName.resourceType,
                DAVPropertyName.displayName,
                DAVPropertyName.getETag,
                CalDAVPropertyName.calendarDescription,
                CalDAVPropertyName.supportedCalendarComponentSet,
                CalDAVPropertyName.getctag,
                CalDAVPropertyName.calendarColor,
                CalDAVPropertyName.calendarOrder
            ]
        )

        let responses = try await request.execute(using: httpClient)

        var calendars: [Calendar] = []

        for response in responses {
            // Skip the collection itself (it will be in the response)
            if response.href == url.path || response.href == url.path + "/" {
                continue
            }

            // Check if this is a calendar resource
            guard let resourceType = response.property(named: "resourcetype") else {
                continue
            }

            // Must be a collection and a calendar
            guard resourceType.contains("collection") else {
                continue
            }

            // Some servers include "calendar" in resourcetype, others don't
            // We'll accept any collection under calendar-home as a potential calendar

            guard let displayName = response.property(named: "displayname") else {
                continue
            }

            // Build the calendar URL
            guard let calendarURL = URL(string: response.href, relativeTo: url)?.absoluteURL else {
                continue
            }

            // Parse supported components
            let supportedComponents = parseSupportedComponents(
                response.property(named: "supported-calendar-component-set")
            )

            // Parse color (hex format like #FF5733FF)
            let color = response.property(named: "calendar-color")

            // Parse order
            let order = response.property(named: "calendar-order").flatMap { Int($0) }

            let calendar = Calendar(
                url: calendarURL,
                displayName: displayName,
                description: response.property(named: "calendar-description"),
                ctag: response.property(named: "getctag"),
                etag: response.property(named: "getetag"),
                supportedComponents: supportedComponents,
                color: color,
                order: order
            )

            calendars.append(calendar)
        }

        return calendars
    }

    // MARK: - Event Operations

    /// Fetch events from a calendar within a date range
    ///
    /// This uses the CalDAV `calendar-query` REPORT to efficiently retrieve
    /// only events within the specified time range.
    ///
    /// - Parameters:
    ///   - calendar: The calendar to query
    ///   - start: Start date of the range
    ///   - end: End date of the range
    /// - Returns: An array of events
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func fetchEvents(from calendar: Calendar, start: Date, end: Date) async throws -> [VEvent] {
        let queryXML = buildCalendarQuery(start: start, end: end)

        let response = try await httpClient.request(
            .report,
            url: calendar.url,
            headers: [
                "Content-Type": "application/xml; charset=utf-8",
                "Depth": "1"
            ],
            body: queryXML
        )

        guard response.statusCode == 207 else {
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }

        // Parse multi-status response
        let parser = WebDAVXMLParser()
        let responses = try parser.parse(response.data)

        var events: [VEvent] = []
        let icalParser = ICalendarParser()

        for resp in responses {
            if let calendarData = resp.property(named: "calendar-data"),
               let data = calendarData.data(using: .utf8) {
                do {
                    let ical = try await icalParser.parse(data)
                    events.append(contentsOf: ical.events)
                } catch {
                    // Skip malformed events but continue processing others
                    continue
                }
            }
        }

        return events
    }

    /// Create a new event in a calendar
    ///
    /// - Parameters:
    ///   - event: The event to create
    ///   - calendar: The calendar to create the event in
    /// - Returns: The created event with updated metadata
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func createEvent(_ event: VEvent, in calendar: Calendar) async throws -> VEvent {
        let ical = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let data = try await serializer.serialize(ical)

        let eventURL = calendar.url.appendingPathComponent("\(event.uid).ics")

        let webdav = WebDAVOperations(client: httpClient)
        _ = try await webdav.put(
            data,
            at: eventURL,
            contentType: "text/calendar; charset=utf-8"
        )

        return event
    }

    /// Update an existing event
    ///
    /// - Parameters:
    ///   - event: The event with updated data
    ///   - calendar: The calendar containing the event
    ///   - etag: The current ETag of the event (for conflict detection)
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func updateEvent(_ event: VEvent, in calendar: Calendar, etag: String) async throws {
        let ical = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let data = try await serializer.serialize(ical)

        let eventURL = calendar.url.appendingPathComponent("\(event.uid).ics")

        let webdav = WebDAVOperations(client: httpClient)
        _ = try await webdav.put(
            data,
            at: eventURL,
            contentType: "text/calendar; charset=utf-8",
            ifMatch: etag
        )
    }

    /// Delete an event from a calendar
    ///
    /// - Parameters:
    ///   - uid: The UID of the event to delete
    ///   - calendar: The calendar containing the event
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func deleteEvent(uid: String, from calendar: Calendar) async throws {
        let eventURL = calendar.url.appendingPathComponent("\(uid).ics")

        let webdav = WebDAVOperations(client: httpClient)
        try await webdav.delete(at: eventURL)
    }

    // MARK: - Helper Methods

    /// Clean up href values that may contain XML fragments
    private func cleanHref(_ href: String) -> String {
        // Remove <href> tags if present
        var cleaned = href
        if cleaned.contains("<href>") {
            cleaned = cleaned.replacingOccurrences(of: "<href>", with: "")
                .replacingOccurrences(of: "</href>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    /// Parse supported calendar components from property value
    private func parseSupportedComponents(_ value: String?) -> [CalendarComponentType] {
        guard let value = value else {
            // Default to VEVENT if not specified
            return [.vevent]
        }

        var components: [CalendarComponentType] = []

        if value.contains("VEVENT") {
            components.append(.vevent)
        }
        if value.contains("VTODO") {
            components.append(.vtodo)
        }
        if value.contains("VJOURNAL") {
            components.append(.vjournal)
        }

        return components.isEmpty ? [.vevent] : components
    }

    /// Build a calendar-query REPORT request body
    private func buildCalendarQuery(start: Date, end: Date) -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <C:calendar-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:caldav">
          <D:prop>
            <D:getetag/>
            <C:calendar-data/>
          </D:prop>
          <C:filter>
            <C:comp-filter name="VCALENDAR">
              <C:comp-filter name="VEVENT">
                <C:time-range start="\(start.toICalendarFormat())" end="\(end.toICalendarFormat())"/>
              </C:comp-filter>
            </C:comp-filter>
          </C:filter>
        </C:calendar-query>
        """

        return xml.data(using: .utf8) ?? Data()
    }
}

// MARK: - Convenience Initializers

extension CalDAVClient {
    /// Create a CalDAV client for iCloud
    ///
    /// iCloud requires app-specific passwords for CalDAV access.
    /// Generate one at: https://appleid.apple.com
    ///
    /// - Parameters:
    ///   - username: Your Apple ID (e.g., "user@icloud.com")
    ///   - appSpecificPassword: An app-specific password (format: "xxxx-xxxx-xxxx-xxxx")
    /// - Returns: A configured CalDAV client for iCloud
    public static func iCloud(username: String, appSpecificPassword: String) -> CalDAVClient {
        let baseClient = AlamofireHTTPClient()
        let auth = Authentication.basic(username: username, password: appSpecificPassword)
        let authedClient = AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)

        return CalDAVClient(
            httpClient: authedClient,
            baseURL: URL(string: "https://caldav.icloud.com")!
        )
    }

    /// Create a CalDAV client for Google Calendar
    ///
    /// Google Calendar requires OAuth 2.0 authentication.
    ///
    /// - Parameters:
    ///   - accessToken: OAuth 2.0 access token
    /// - Returns: A configured CalDAV client for Google Calendar
    public static func google(accessToken: String) -> CalDAVClient {
        let baseClient = AlamofireHTTPClient()
        let auth = Authentication.bearer(token: accessToken)
        let authedClient = AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)

        return CalDAVClient(
            httpClient: authedClient,
            baseURL: URL(string: "https://apidata.googleusercontent.com/caldav/v2")!
        )
    }

    /// Create a CalDAV client for Google Calendar with OAuth 2.0 token refresh
    ///
    /// This initializer creates a client that automatically refreshes OAuth 2.0 tokens.
    ///
    /// - Parameters:
    ///   - accessToken: OAuth 2.0 access token
    ///   - refreshToken: OAuth 2.0 refresh token
    ///   - clientID: Google OAuth 2.0 client ID
    ///   - clientSecret: Google OAuth 2.0 client secret
    ///   - expiresAt: When the access token expires
    ///   - onTokenRefresh: Callback invoked when tokens are refreshed (for persistence)
    /// - Returns: A configured CalDAV client for Google Calendar with auto-refresh
    public static func googleWithRefresh(
        accessToken: String,
        refreshToken: String,
        clientID: String,
        clientSecret: String,
        expiresAt: Date? = nil,
        onTokenRefresh: ((String, Date?) -> Void)? = nil
    ) -> CalDAVClient {
        let oauth2Client = OAuth2HTTPClient.google(
            accessToken: accessToken,
            refreshToken: refreshToken,
            clientID: clientID,
            clientSecret: clientSecret,
            expiresAt: expiresAt,
            onTokenRefresh: onTokenRefresh
        )

        return CalDAVClient(
            httpClient: oauth2Client,
            baseURL: URL(string: "https://apidata.googleusercontent.com/caldav/v2")!
        )
    }

    /// Create a CalDAV client for a custom server
    ///
    /// - Parameters:
    ///   - serverURL: The base URL of the CalDAV server
    ///   - username: Username for basic authentication
    ///   - password: Password for basic authentication
    /// - Returns: A configured CalDAV client
    public static func custom(serverURL: URL, username: String, password: String) -> CalDAVClient {
        let baseClient = AlamofireHTTPClient()
        let auth = Authentication.basic(username: username, password: password)
        let authedClient = AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)

        return CalDAVClient(
            httpClient: authedClient,
            baseURL: serverURL
        )
    }
}
