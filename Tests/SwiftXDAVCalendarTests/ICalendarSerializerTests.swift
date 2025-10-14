import XCTest
@testable import SwiftXDAVCalendar
@testable import SwiftXDAVCore

final class ICalendarSerializerTests: XCTestCase {

    // MARK: - Basic Serialization Tests

    func testSerializeEmptyCalendar() async throws {
        let calendar = ICalendar()
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("BEGIN:VCALENDAR"))
        XCTAssertTrue(text.contains("VERSION:2.0"))
        XCTAssertTrue(text.contains("PRODID:-//SwiftXDAV//SwiftXDAV 1.0//EN"))
        XCTAssertTrue(text.contains("CALSCALE:GREGORIAN"))
        XCTAssertTrue(text.contains("END:VCALENDAR"))
    }

    func testSerializeSimpleEvent() async throws {
        let event = VEvent(
            uid: "test-123",
            dtstamp: Date(timeIntervalSince1970: 1704110400), // 2024-01-01 12:00:00 UTC
            dtstart: Date(timeIntervalSince1970: 1704715200),  // 2024-01-08 12:00:00 UTC
            dtend: Date(timeIntervalSince1970: 1704718800),    // 2024-01-08 13:00:00 UTC
            summary: "Team Meeting",
            description: "Discuss Q1 goals",
            location: "Room 101"
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("BEGIN:VEVENT"))
        XCTAssertTrue(text.contains("UID:test-123"))
        XCTAssertTrue(text.contains("SUMMARY:Team Meeting"))
        XCTAssertTrue(text.contains("DESCRIPTION:Discuss Q1 goals"))
        XCTAssertTrue(text.contains("LOCATION:Room 101"))
        XCTAssertTrue(text.contains("END:VEVENT"))
    }

    func testSerializeEventWithStatus() async throws {
        let event = VEvent(
            uid: "test-status",
            status: .confirmed
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("STATUS:CONFIRMED"))
    }

    func testSerializeEventWithTransparency() async throws {
        let event = VEvent(
            uid: "test-transp",
            transparency: .transparent
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("TRANSP:TRANSPARENT"))
    }

    func testSerializeEventWithOrganizer() async throws {
        let organizer = Organizer(email: "john@example.com", commonName: "John Doe")
        let event = VEvent(
            uid: "test-organizer",
            summary: "Meeting",
            organizer: organizer
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("ORGANIZER"))
        XCTAssertTrue(text.contains("CN=\"John Doe\""))
        XCTAssertTrue(text.contains("mailto:john@example.com"))
    }

    func testSerializeEventWithAttendees() async throws {
        let attendee1 = Attendee(
            email: "alice@example.com",
            commonName: "Alice Smith",
            role: .reqParticipant,
            status: .accepted,
            rsvp: true
        )
        let attendee2 = Attendee(
            email: "bob@example.com",
            commonName: "Bob Jones",
            role: .optParticipant,
            status: .tentative,
            rsvp: false
        )

        let event = VEvent(
            uid: "test-attendees",
            summary: "Team Sync",
            attendees: [attendee1, attendee2]
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        // Unfold lines for easier testing (remove CRLF followed by space)
        let unfolded = text.replacingOccurrences(of: "\r\n ", with: "")

        XCTAssertTrue(unfolded.contains("ATTENDEE"))
        XCTAssertTrue(unfolded.contains("CN=\"Alice Smith\""))
        XCTAssertTrue(unfolded.contains("mailto:alice@example.com"))
        XCTAssertTrue(unfolded.contains("ROLE=REQ-PARTICIPANT"))
        XCTAssertTrue(unfolded.contains("PARTSTAT=ACCEPTED"))
        XCTAssertTrue(unfolded.contains("RSVP=TRUE"))

        XCTAssertTrue(unfolded.contains("CN=\"Bob Jones\""))
        XCTAssertTrue(unfolded.contains("mailto:bob@example.com"))
        XCTAssertTrue(unfolded.contains("ROLE=OPT-PARTICIPANT"))
        XCTAssertTrue(unfolded.contains("PARTSTAT=TENTATIVE"))
    }

    func testSerializeEventWithCategories() async throws {
        let event = VEvent(
            uid: "test-categories",
            summary: "Workshop",
            categories: ["Training", "Development", "Team"]
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("CATEGORIES:Training,Development,Team"))
    }

    func testSerializeEventWithURL() async throws {
        let event = VEvent(
            uid: "test-url",
            summary: "Online Meeting",
            url: URL(string: "https://meet.example.com/room123")
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("URL:https://meet.example.com/room123"))
    }

    func testSerializeEventWithSequence() async throws {
        let event = VEvent(
            uid: "test-sequence",
            summary: "Updated Meeting",
            sequence: 5
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("SEQUENCE:5"))
    }

    // MARK: - Text Escaping Tests

    func testSerializeEscapedText() async throws {
        let event = VEvent(
            uid: "test-escape",
            summary: "Meeting; with, special\\characters",
            description: "Line 1\nLine 2\nLine 3"
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("SUMMARY:Meeting\\; with\\, special\\\\characters"))
        XCTAssertTrue(text.contains("DESCRIPTION:Line 1\\nLine 2\\nLine 3"))
    }

    // MARK: - Line Folding Tests

    func testSerializeLineFolding() async throws {
        let longSummary = String(repeating: "A", count: 100)
        let event = VEvent(
            uid: "test-folding",
            summary: longSummary
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        // Check that line folding occurred (line break + space)
        XCTAssertTrue(text.contains("\r\n "))
    }

    // MARK: - VTODO Tests

    func testSerializeTodo() async throws {
        let todo = VTodo(
            uid: "todo-123",
            dtstart: Date(timeIntervalSince1970: 1704110400),
            due: Date(timeIntervalSince1970: 1704715200),
            summary: "Complete report",
            description: "Finish Q4 report",
            status: .inProcess,
            priority: 1,
            percentComplete: 50
        )

        let calendar = ICalendar(todos: [todo])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("BEGIN:VTODO"))
        XCTAssertTrue(text.contains("UID:todo-123"))
        XCTAssertTrue(text.contains("SUMMARY:Complete report"))
        XCTAssertTrue(text.contains("DESCRIPTION:Finish Q4 report"))
        XCTAssertTrue(text.contains("STATUS:IN-PROCESS"))
        XCTAssertTrue(text.contains("PRIORITY:1"))
        XCTAssertTrue(text.contains("PERCENT-COMPLETE:50"))
        XCTAssertTrue(text.contains("END:VTODO"))
    }

    // MARK: - VTIMEZONE Tests

    func testSerializeTimezone() async throws {
        let tz = VTimeZone(tzid: "America/New_York")
        let calendar = ICalendar(timezones: [tz])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("BEGIN:VTIMEZONE"))
        XCTAssertTrue(text.contains("TZID:America/New_York"))
        XCTAssertTrue(text.contains("END:VTIMEZONE"))
    }

    // MARK: - VALARM Tests

    func testSerializeAlarmRelative() async throws {
        let alarm = VAlarm(
            action: .display,
            trigger: .relative(-900), // 15 minutes before
            description: "Meeting reminder"
        )

        let event = VEvent(
            uid: "test-alarm",
            summary: "Meeting",
            alarms: [alarm]
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("BEGIN:VALARM"))
        XCTAssertTrue(text.contains("ACTION:DISPLAY"))
        XCTAssertTrue(text.contains("TRIGGER:-PT15M"))
        XCTAssertTrue(text.contains("DESCRIPTION:Meeting reminder"))
        XCTAssertTrue(text.contains("END:VALARM"))
    }

    func testSerializeAlarmAbsolute() async throws {
        let triggerDate = Date(timeIntervalSince1970: 1704110400)
        let alarm = VAlarm(
            action: .audio,
            trigger: .absolute(triggerDate)
        )

        let event = VEvent(
            uid: "test-alarm-abs",
            summary: "Meeting",
            alarms: [alarm]
        )

        let calendar = ICalendar(events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("BEGIN:VALARM"))
        XCTAssertTrue(text.contains("ACTION:AUDIO"))
        XCTAssertTrue(text.contains("TRIGGER;VALUE=DATE-TIME:"))
        XCTAssertTrue(text.contains("END:VALARM"))
    }

    // MARK: - Duration Formatting Tests

    func testFormatDuration() async throws {
        // Test 1 hour 30 minutes (5400 seconds)
        let alarm1 = VAlarm(
            action: .display,
            trigger: .relative(-5400)
        )
        let event1 = VEvent(uid: "test-dur-1", alarms: [alarm1])
        let calendar1 = ICalendar(events: [event1])
        let serializer = ICalendarSerializer()
        let text1 = try await serializer.serializeToString(calendar1)

        XCTAssertTrue(text1.contains("TRIGGER:-PT1H30M"))

        // Test 1 day (86400 seconds)
        let alarm2 = VAlarm(
            action: .display,
            trigger: .relative(-86400)
        )
        let event2 = VEvent(uid: "test-dur-2", alarms: [alarm2])
        let calendar2 = ICalendar(events: [event2])
        let text2 = try await serializer.serializeToString(calendar2)

        XCTAssertTrue(text2.contains("TRIGGER:-P1D"))
    }

    // MARK: - Multiple Events Tests

    func testSerializeMultipleEvents() async throws {
        let event1 = VEvent(uid: "event-1", summary: "First")
        let event2 = VEvent(uid: "event-2", summary: "Second")
        let event3 = VEvent(uid: "event-3", summary: "Third")

        let calendar = ICalendar(events: [event1, event2, event3])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        // Count BEGIN:VEVENT occurrences
        let count = text.components(separatedBy: "BEGIN:VEVENT").count - 1
        XCTAssertEqual(count, 3)

        XCTAssertTrue(text.contains("SUMMARY:First"))
        XCTAssertTrue(text.contains("SUMMARY:Second"))
        XCTAssertTrue(text.contains("SUMMARY:Third"))
    }

    // MARK: - Method Property Test

    func testSerializeCalendarWithMethod() async throws {
        let event = VEvent(uid: "test-method", summary: "Meeting Request")
        let calendar = ICalendar(method: "REQUEST", events: [event])
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        XCTAssertTrue(text.contains("METHOD:REQUEST"))
    }

    // MARK: - Round-trip Tests

    func testRoundTrip() async throws {
        // Create a calendar
        let originalEvent = VEvent(
            uid: "roundtrip-123",
            dtstart: Date(timeIntervalSince1970: 1704110400),
            summary: "Test Event",
            description: "Testing round-trip",
            location: "Office",
            status: .confirmed
        )
        let originalCalendar = ICalendar(events: [originalEvent])

        // Serialize it
        let serializer = ICalendarSerializer()
        let data = try await serializer.serialize(originalCalendar)

        // Parse it back
        let parser = ICalendarParser()
        let parsedCalendar = try await parser.parse(data)

        // Verify
        XCTAssertEqual(parsedCalendar.events.count, 1)
        XCTAssertEqual(parsedCalendar.events[0].uid, "roundtrip-123")
        XCTAssertEqual(parsedCalendar.events[0].summary, "Test Event")
        XCTAssertEqual(parsedCalendar.events[0].description, "Testing round-trip")
        XCTAssertEqual(parsedCalendar.events[0].location, "Office")
        XCTAssertEqual(parsedCalendar.events[0].status, .confirmed)
    }

    // MARK: - CRLF Ending Test

    func testSerializeUsesCRLF() async throws {
        let calendar = ICalendar()
        let serializer = ICalendarSerializer()
        let text = try await serializer.serializeToString(calendar)

        // Should use \r\n (CRLF) not just \n
        XCTAssertTrue(text.contains("\r\n"))
        XCTAssertTrue(text.hasSuffix("\r\n"))
    }
}
