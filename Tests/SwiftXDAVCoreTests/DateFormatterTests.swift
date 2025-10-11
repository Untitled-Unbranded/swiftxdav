import XCTest
@testable import SwiftXDAVCore

/// Tests for date formatting utilities
final class DateFormatterTests: XCTestCase {

    // MARK: - iCalendar DateTime Format Tests

    func testICalendarDateTimeFormat() {
        // Test a known date/time - use a specific UTC date
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2023
        components.month = 11
        components.day = 25
        components.hour = 13
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        let formatted = date.toICalendarFormat()

        // Should format as yyyyMMdd'T'HHmmss'Z'
        XCTAssertEqual(formatted, "20231125T130000Z")

        // Parse it back
        let parsed = formatted.fromICalendarFormat()
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1.0)
    }

    func testICalendarDateTimeFormatRoundTrip() {
        let originalDate = Date()
        let formatted = originalDate.toICalendarFormat()
        let parsed = formatted.fromICalendarFormat()

        XCTAssertNotNil(parsed)
        // Allow 1 second accuracy due to rounding
        XCTAssertEqual(parsed?.timeIntervalSince1970 ?? 0, originalDate.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - iCalendar Date-Only Format Tests

    func testICalendarDateOnlyFormat() {
        // Test a known date
        let date = Date(timeIntervalSince1970: 1700924400) // 2023-11-25 13:00:00 UTC
        let formatted = date.toICalendarDateFormat()

        // Should format as yyyyMMdd (date only, no time)
        XCTAssertEqual(formatted, "20231125")

        // Parse it back
        let parsed = formatted.fromICalendarDateFormat()
        XCTAssertNotNil(parsed)
    }

    func testICalendarDateOnlyFormatRoundTrip() {
        let originalDate = Date()
        let formatted = originalDate.toICalendarDateFormat()
        let parsed = formatted.fromICalendarDateFormat()

        XCTAssertNotNil(parsed)

        // Compare only the date components (year, month, day)
        let calendar = Calendar.current
        let originalComponents = calendar.dateComponents([.year, .month, .day], from: originalDate)
        let parsedComponents = calendar.dateComponents([.year, .month, .day], from: parsed!)

        XCTAssertEqual(originalComponents.year, parsedComponents.year)
        XCTAssertEqual(originalComponents.month, parsedComponents.month)
        XCTAssertEqual(originalComponents.day, parsedComponents.day)
    }

    // MARK: - iCalendar Floating Time Format Tests

    func testICalendarFloatingTimeFormat() {
        let date = Date(timeIntervalSince1970: 1700924400) // 2023-11-25 13:00:00 UTC
        let formatted = date.toICalendarFloatingFormat()

        // Should format without 'Z' suffix
        XCTAssertTrue(formatted.contains("T"))
        XCTAssertFalse(formatted.hasSuffix("Z"))
    }

    func testParseICalendarFloatingTime() {
        let floatingTime = "20231125T143000"
        let parsed = floatingTime.fromICalendarFormat()

        XCTAssertNotNil(parsed)
    }

    // MARK: - RFC 2822 Format Tests (HTTP Headers)

    func testRFC2822Format() {
        let date = Date(timeIntervalSince1970: 1700924400) // 2023-11-25 13:00:00 UTC
        let formatted = date.toRFC2822Format()

        // Should format as "Day, DD Mon YYYY HH:MM:SS GMT"
        XCTAssertTrue(formatted.contains("2023"))
        XCTAssertTrue(formatted.contains("GMT"))

        // Parse it back
        let parsed = formatted.fromRFC2822Format()
        XCTAssertNotNil(parsed)
        XCTAssertEqual(parsed?.timeIntervalSince1970 ?? 0, date.timeIntervalSince1970, accuracy: 1.0)
    }

    func testRFC2822FormatRoundTrip() {
        let originalDate = Date()
        let formatted = originalDate.toRFC2822Format()
        let parsed = formatted.fromRFC2822Format()

        XCTAssertNotNil(parsed)
        // Allow 1 second accuracy
        XCTAssertEqual(parsed?.timeIntervalSince1970 ?? 0, originalDate.timeIntervalSince1970, accuracy: 1.0)
    }

    // MARK: - Edge Cases

    func testParseInvalidICalendarDateTime() {
        let invalid = "not-a-date"
        let parsed = invalid.fromICalendarFormat()

        XCTAssertNil(parsed)
    }

    func testParseInvalidICalendarDate() {
        let invalid = "99999999"
        let parsed = invalid.fromICalendarDateFormat()

        XCTAssertNil(parsed)
    }

    func testParseInvalidRFC2822() {
        let invalid = "Not a valid date"
        let parsed = invalid.fromRFC2822Format()

        XCTAssertNil(parsed)
    }

    func testICalendarFormatWithMidnight() {
        // Test midnight UTC
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2023
        components.month = 11
        components.day = 25
        components.hour = 0
        components.minute = 0
        components.second = 0
        components.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        let formatted = date.toICalendarFormat()
        XCTAssertEqual(formatted, "20231125T000000Z")
    }

    func testICalendarFormatWithEndOfDay() {
        // Test 23:59:59 UTC
        let calendar = Calendar(identifier: .iso8601)
        var components = DateComponents()
        components.year = 2023
        components.month = 11
        components.day = 25
        components.hour = 23
        components.minute = 59
        components.second = 59
        components.timeZone = TimeZone(secondsFromGMT: 0)

        guard let date = calendar.date(from: components) else {
            XCTFail("Failed to create date")
            return
        }

        let formatted = date.toICalendarFormat()
        XCTAssertEqual(formatted, "20231125T235959Z")
    }
}
