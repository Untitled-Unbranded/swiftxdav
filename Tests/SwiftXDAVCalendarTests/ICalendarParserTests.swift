import XCTest
@testable import SwiftXDAVCalendar
@testable import SwiftXDAVCore

final class ICalendarParserTests: XCTestCase {

    // MARK: - Basic Parsing Tests

    func testParseEmptyCalendar() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        CALSCALE:GREGORIAN
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.version, "2.0")
        XCTAssertEqual(calendar.prodid, "-//Test//Test 1.0//EN")
        XCTAssertEqual(calendar.calscale, "GREGORIAN")
        XCTAssertEqual(calendar.events.count, 0)
        XCTAssertEqual(calendar.todos.count, 0)
    }

    func testParseSimpleEvent() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-event-123
        DTSTAMP:20250101T120000Z
        DTSTART:20250110T100000Z
        DTEND:20250110T110000Z
        SUMMARY:Team Meeting
        DESCRIPTION:Discuss project updates
        LOCATION:Conference Room A
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)

        let event = calendar.events[0]
        XCTAssertEqual(event.uid, "test-event-123")
        XCTAssertEqual(event.summary, "Team Meeting")
        XCTAssertEqual(event.description, "Discuss project updates")
        XCTAssertEqual(event.location, "Conference Room A")
        XCTAssertNotNil(event.dtstart)
        XCTAssertNotNil(event.dtend)
    }

    func testParseEventWithStatus() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-event-456
        DTSTAMP:20250101T120000Z
        DTSTART:20250110T100000Z
        SUMMARY:Cancelled Meeting
        STATUS:CANCELLED
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].status, .cancelled)
    }

    func testParseEventWithTransparency() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-event-789
        DTSTAMP:20250101T120000Z
        DTSTART:20250110T100000Z
        SUMMARY:Out of Office
        TRANSP:TRANSPARENT
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].transparency, .transparent)
    }

    func testParseEventWithCategories() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-event-cat
        DTSTAMP:20250101T120000Z
        DTSTART:20250110T100000Z
        SUMMARY:Workshop
        CATEGORIES:Training,Development
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].categories, ["Training", "Development"])
    }

    func testParseEventWithURL() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-event-url
        DTSTAMP:20250101T120000Z
        DTSTART:20250110T100000Z
        SUMMARY:Online Meeting
        URL:https://meet.example.com/room123
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].url?.absoluteString, "https://meet.example.com/room123")
    }

    func testParseMultipleEvents() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:event-1
        DTSTAMP:20250101T120000Z
        DTSTART:20250110T100000Z
        SUMMARY:First Event
        END:VEVENT
        BEGIN:VEVENT
        UID:event-2
        DTSTAMP:20250101T120000Z
        DTSTART:20250111T100000Z
        SUMMARY:Second Event
        END:VEVENT
        BEGIN:VEVENT
        UID:event-3
        DTSTAMP:20250101T120000Z
        DTSTART:20250112T100000Z
        SUMMARY:Third Event
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 3)
        XCTAssertEqual(calendar.events[0].summary, "First Event")
        XCTAssertEqual(calendar.events[1].summary, "Second Event")
        XCTAssertEqual(calendar.events[2].summary, "Third Event")
    }

    // MARK: - Text Escaping Tests

    func testParseEscapedText() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-escape
        DTSTAMP:20250101T120000Z
        SUMMARY:Meeting\\; Notes\\, Actions
        DESCRIPTION:Line 1\\nLine 2\\nLine 3
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].summary, "Meeting; Notes, Actions")
        XCTAssertEqual(calendar.events[0].description, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - Line Folding Tests

    func testParseUnfoldedLines() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-unfold
        DTSTAMP:20250101T120000Z
        SUMMARY:This is a very long summary that has been folded across mult
         iple lines to comply with the 75 character limit per line in iCalendar
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].summary, "This is a very long summary that has been folded across multiple lines to comply with the 75 character limit per line in iCalendar")
    }

    // MARK: - VTODO Tests

    func testParseTodo() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VTODO
        UID:todo-123
        DTSTAMP:20250101T120000Z
        DTSTART:20250110T100000Z
        DUE:20250115T170000Z
        SUMMARY:Complete report
        DESCRIPTION:Finish Q4 financial report
        STATUS:IN-PROCESS
        PRIORITY:1
        PERCENT-COMPLETE:50
        END:VTODO
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.todos.count, 1)

        let todo = calendar.todos[0]
        XCTAssertEqual(todo.uid, "todo-123")
        XCTAssertEqual(todo.summary, "Complete report")
        XCTAssertEqual(todo.description, "Finish Q4 financial report")
        XCTAssertEqual(todo.status, .inProcess)
        XCTAssertEqual(todo.priority, 1)
        XCTAssertEqual(todo.percentComplete, 50)
        XCTAssertNotNil(todo.dtstart)
        XCTAssertNotNil(todo.due)
    }

    // MARK: - VTIMEZONE Tests

    func testParseTimezone() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VTIMEZONE
        TZID:America/New_York
        END:VTIMEZONE
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.timezones.count, 1)
        XCTAssertEqual(calendar.timezones[0].tzid, "America/New_York")
    }

    // MARK: - Error Handling Tests

    func testParseInvalidUTF8() async throws {
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        let parser = ICalendarParser()

        do {
            _ = try await parser.parse(invalidData)
            XCTFail("Should have thrown parsingError")
        } catch SwiftXDAVError.parsingError(let message) {
            XCTAssertTrue(message.contains("UTF-8"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    func testParseMissingColon() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        INVALID_LINE_WITHOUT_COLON
        END:VCALENDAR
        """

        let parser = ICalendarParser()

        do {
            _ = try await parser.parse(ical.data(using: .utf8)!)
            XCTFail("Should have thrown parsingError")
        } catch SwiftXDAVError.parsingError(let message) {
            XCTAssertTrue(message.contains("colon"))
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - Method Property Test

    func testParseCalendarWithMethod() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        METHOD:REQUEST
        BEGIN:VEVENT
        UID:test-request
        DTSTAMP:20250101T120000Z
        SUMMARY:Meeting Request
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.method, "REQUEST")
    }

    // MARK: - Sequence Test

    func testParseEventWithSequence() async throws {
        let ical = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test 1.0//EN
        BEGIN:VEVENT
        UID:test-sequence
        DTSTAMP:20250101T120000Z
        SUMMARY:Updated Event
        SEQUENCE:3
        END:VEVENT
        END:VCALENDAR
        """

        let parser = ICalendarParser()
        let calendar = try await parser.parse(ical.data(using: .utf8)!)

        XCTAssertEqual(calendar.events.count, 1)
        XCTAssertEqual(calendar.events[0].sequence, 3)
    }
}
