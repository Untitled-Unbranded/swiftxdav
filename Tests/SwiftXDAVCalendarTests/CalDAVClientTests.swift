import XCTest
@testable import SwiftXDAVCalendar
@testable import SwiftXDAVCore
@testable import SwiftXDAVNetwork

final class CalDAVClientTests: XCTestCase {
    // MARK: - Mock HTTP Client

    actor MockHTTPClient: HTTPClient {
        var responses: [URL: HTTPResponse] = [:]
        var requestLog: [(HTTPMethod, URL)] = []

        func addResponse(for url: URL, statusCode: Int, headers: [String: String] = [:], body: String) {
            responses[url] = HTTPResponse(
                statusCode: statusCode,
                headers: headers,
                data: body.data(using: .utf8) ?? Data()
            )
        }

        func request(
            _ method: HTTPMethod,
            url: URL,
            headers: [String: String]?,
            body: Data?
        ) async throws -> HTTPResponse {
            requestLog.append((method, url))

            guard let response = responses[url] else {
                throw SwiftXDAVError.notFound
            }

            return response
        }
    }

    // MARK: - Discovery Tests

    func testDiscoverPrincipal() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/")!

        // Mock the PROPFIND response for current-user-principal
        let principalResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/</d:href>
            <d:propstat>
              <d:prop>
                <d:current-user-principal>
                  <d:href>/principals/user1/</d:href>
                </d:current-user-principal>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        await mockClient.addResponse(
            for: baseURL,
            statusCode: 207,
            body: principalResponse
        )

        let client = CalDAVClient(httpClient: mockClient, baseURL: baseURL)
        let principalURL = try await client.discoverPrincipal()

        XCTAssertEqual(principalURL.absoluteString, "https://example.com/principals/user1/")

        // Verify the request was made
        let requestLog = await mockClient.requestLog
        XCTAssertEqual(requestLog.count, 1)
        XCTAssertEqual(requestLog[0].0, .propfind)
    }

    func testDiscoverCalendarHome() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/")!
        let principalURL = URL(string: "https://example.com/principals/user1/")!

        // Mock principal discovery
        let principalResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/</d:href>
            <d:propstat>
              <d:prop>
                <d:current-user-principal>
                  <d:href>/principals/user1/</d:href>
                </d:current-user-principal>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        // Mock calendar-home-set discovery
        let calendarHomeResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:response>
            <d:href>/principals/user1/</d:href>
            <d:propstat>
              <d:prop>
                <c:calendar-home-set>
                  <d:href>/calendars/user1/</d:href>
                </c:calendar-home-set>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        await mockClient.addResponse(for: baseURL, statusCode: 207, body: principalResponse)
        await mockClient.addResponse(for: principalURL, statusCode: 207, body: calendarHomeResponse)

        let client = CalDAVClient(httpClient: mockClient, baseURL: baseURL)
        let calendarHomeURL = try await client.discoverCalendarHome()

        XCTAssertEqual(calendarHomeURL.absoluteString, "https://example.com/calendars/user1/")
    }

    // MARK: - Calendar Listing Tests

    func testListCalendars() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/")!
        let principalURL = URL(string: "https://example.com/principals/user1/")!
        let calendarHomeURL = URL(string: "https://example.com/calendars/user1/")!

        // Mock discovery responses
        let principalResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/</d:href>
            <d:propstat>
              <d:prop>
                <d:current-user-principal>
                  <d:href>/principals/user1/</d:href>
                </d:current-user-principal>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        let calendarHomeResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:response>
            <d:href>/principals/user1/</d:href>
            <d:propstat>
              <d:prop>
                <c:calendar-home-set>
                  <d:href>/calendars/user1/</d:href>
                </c:calendar-home-set>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        // Mock calendar list response
        let calendarListResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav" xmlns:cs="http://calendarserver.org/ns/">
          <d:response>
            <d:href>/calendars/user1/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype>
                  <d:collection/>
                </d:resourcetype>
                <d:displayname>Calendar Home</d:displayname>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/calendars/user1/personal/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype>
                  <d:collection/>
                  <c:calendar/>
                </d:resourcetype>
                <d:displayname>Personal Calendar</d:displayname>
                <c:calendar-description>My personal events</c:calendar-description>
                <c:supported-calendar-component-set>
                  <c:comp name="VEVENT"/>
                </c:supported-calendar-component-set>
                <cs:getctag>12345</cs:getctag>
                <d:getetag>"abc123"</d:getetag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/calendars/user1/work/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype>
                  <d:collection/>
                  <c:calendar/>
                </d:resourcetype>
                <d:displayname>Work Calendar</d:displayname>
                <c:supported-calendar-component-set>
                  <c:comp name="VEVENT"/>
                  <c:comp name="VTODO"/>
                </c:supported-calendar-component-set>
                <cs:getctag>67890</cs:getctag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        await mockClient.addResponse(for: baseURL, statusCode: 207, body: principalResponse)
        await mockClient.addResponse(for: principalURL, statusCode: 207, body: calendarHomeResponse)
        await mockClient.addResponse(for: calendarHomeURL, statusCode: 207, body: calendarListResponse)

        let client = CalDAVClient(httpClient: mockClient, baseURL: baseURL)
        let calendars = try await client.listCalendars()

        XCTAssertEqual(calendars.count, 2)

        // Check first calendar
        let personal = calendars.first { $0.displayName == "Personal Calendar" }
        XCTAssertNotNil(personal)
        XCTAssertEqual(personal?.description, "My personal events")
        XCTAssertEqual(personal?.ctag, "12345")
        XCTAssertEqual(personal?.etag, "\"abc123\"")
        XCTAssertTrue(personal?.supportsEvents ?? false)
        XCTAssertFalse(personal?.supportsTodos ?? true)

        // Check second calendar
        let work = calendars.first { $0.displayName == "Work Calendar" }
        XCTAssertNotNil(work)
        XCTAssertEqual(work?.ctag, "67890")
        XCTAssertTrue(work?.supportsEvents ?? false)
        XCTAssertTrue(work?.supportsTodos ?? false)
    }

    // MARK: - Event Operations Tests

    func testFetchEvents() async throws {
        let mockClient = MockHTTPClient()
        let calendarURL = URL(string: "https://example.com/calendars/user1/personal/")!

        // Mock calendar-query REPORT response
        let queryResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:caldav">
          <d:response>
            <d:href>/calendars/user1/personal/event1.ics</d:href>
            <d:propstat>
              <d:prop>
                <d:getetag>"etag1"</d:getetag>
                <c:calendar-data>BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        CALSCALE:GREGORIAN
        BEGIN:VEVENT
        UID:event1@example.com
        DTSTAMP:20240101T120000Z
        DTSTART:20240115T140000Z
        DTEND:20240115T150000Z
        SUMMARY:Team Meeting
        LOCATION:Conference Room A
        DESCRIPTION:Weekly team sync
        END:VEVENT
        END:VCALENDAR</c:calendar-data>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        await mockClient.addResponse(for: calendarURL, statusCode: 207, body: queryResponse)

        let client = CalDAVClient(httpClient: mockClient, baseURL: URL(string: "https://example.com/")!)
        let calendar = Calendar(
            url: calendarURL,
            displayName: "Test Calendar"
        )

        let start = Date(timeIntervalSince1970: 1705320000) // 2024-01-15
        let end = Date(timeIntervalSince1970: 1705406400)   // 2024-01-16

        let events = try await client.fetchEvents(from: calendar, start: start, end: end)

        XCTAssertEqual(events.count, 1)
        XCTAssertEqual(events[0].uid, "event1@example.com")
        XCTAssertEqual(events[0].summary, "Team Meeting")
        XCTAssertEqual(events[0].location, "Conference Room A")
        XCTAssertEqual(events[0].description, "Weekly team sync")
    }

    func testCreateEvent() async throws {
        let mockClient = MockHTTPClient()
        let calendarURL = URL(string: "https://example.com/calendars/user1/personal/")!
        let eventURL = calendarURL.appendingPathComponent("test-event.ics")

        // Mock PUT response
        await mockClient.addResponse(
            for: eventURL,
            statusCode: 201,
            headers: ["ETag": "\"new-etag\""],
            body: ""
        )

        let client = CalDAVClient(httpClient: mockClient, baseURL: URL(string: "https://example.com/")!)
        let calendar = Calendar(url: calendarURL, displayName: "Test Calendar")

        let event = VEvent(
            uid: "test-event",
            dtstart: Date(),
            summary: "New Event"
        )

        let createdEvent = try await client.createEvent(event, in: calendar)
        XCTAssertEqual(createdEvent.uid, "test-event")
        XCTAssertEqual(createdEvent.summary, "New Event")

        // Verify PUT request was made
        let requestLog = await mockClient.requestLog
        XCTAssertTrue(requestLog.contains { $0.0 == .put && $0.1 == eventURL })
    }

    func testDeleteEvent() async throws {
        let mockClient = MockHTTPClient()
        let calendarURL = URL(string: "https://example.com/calendars/user1/personal/")!
        let eventURL = calendarURL.appendingPathComponent("event-to-delete.ics")

        // Mock DELETE response
        await mockClient.addResponse(for: eventURL, statusCode: 204, body: "")

        let client = CalDAVClient(httpClient: mockClient, baseURL: URL(string: "https://example.com/")!)
        let calendar = Calendar(url: calendarURL, displayName: "Test Calendar")

        try await client.deleteEvent(uid: "event-to-delete", from: calendar)

        // Verify DELETE request was made
        let requestLog = await mockClient.requestLog
        XCTAssertTrue(requestLog.contains { $0.0 == .delete && $0.1 == eventURL })
    }

    // MARK: - Convenience Initializer Tests

    func testICloudInitializer() {
        let client = CalDAVClient.iCloud(
            username: "test@icloud.com",
            appSpecificPassword: "xxxx-xxxx-xxxx-xxxx"
        )

        // We can't directly test the internal state, but we can verify it was created
        XCTAssertNotNil(client)
    }

    func testGoogleInitializer() {
        let client = CalDAVClient.google(accessToken: "test-token")
        XCTAssertNotNil(client)
    }

    func testCustomServerInitializer() {
        let serverURL = URL(string: "https://caldav.example.com")!
        let client = CalDAVClient.custom(
            serverURL: serverURL,
            username: "user",
            password: "pass"
        )
        XCTAssertNotNil(client)
    }

    // MARK: - Calendar Model Tests

    func testCalendarEquality() {
        let cal1 = Calendar(
            url: URL(string: "https://example.com/cal1")!,
            displayName: "Calendar 1"
        )

        let cal2 = Calendar(
            url: URL(string: "https://example.com/cal1")!,
            displayName: "Calendar 1"
        )

        let cal3 = Calendar(
            url: URL(string: "https://example.com/cal2")!,
            displayName: "Calendar 2"
        )

        XCTAssertEqual(cal1, cal2)
        XCTAssertNotEqual(cal1, cal3)
    }

    func testCalendarSupportsComponents() {
        let eventsOnly = Calendar(
            url: URL(string: "https://example.com/cal")!,
            displayName: "Events",
            supportedComponents: [.vevent]
        )

        XCTAssertTrue(eventsOnly.supportsEvents)
        XCTAssertFalse(eventsOnly.supportsTodos)

        let both = Calendar(
            url: URL(string: "https://example.com/cal")!,
            displayName: "Both",
            supportedComponents: [.vevent, .vtodo]
        )

        XCTAssertTrue(both.supportsEvents)
        XCTAssertTrue(both.supportsTodos)
    }
}
