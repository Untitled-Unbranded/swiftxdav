import XCTest
@testable import SwiftXDAVCalendar

final class RecurrenceEngineTests: XCTestCase {
    var engine: RecurrenceEngine!
    let calendar = Calendar.current

    override func setUp() async throws {
        engine = RecurrenceEngine()
    }

    // MARK: - Non-Recurring Events

    func testNonRecurringEvent() async throws {
        let start = Date()
        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start
        )

        let range = DateInterval(
            start: calendar.date(byAdding: .day, value: -1, to: start)!,
            end: calendar.date(byAdding: .day, value: 1, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 1)
        if let first = occurrences.first {
            XCTAssertEqual(first.timeIntervalSince1970, start.timeIntervalSince1970, accuracy: 1.0)
        } else {
            XCTFail("Expected at least one occurrence")
        }
    }

    func testNonRecurringEventOutsideRange() async throws {
        let start = Date()
        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start
        )

        let range = DateInterval(
            start: calendar.date(byAdding: .day, value: -10, to: start)!,
            end: calendar.date(byAdding: .day, value: -5, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 0)
    }

    // MARK: - Daily Recurrence

    func testDailyRecurrence() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 10))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            count: 7
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 10, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 7)

        // Verify daily pattern
        for (index, occurrence) in occurrences.enumerated() {
            let expected = calendar.date(byAdding: .day, value: index, to: start)!
            XCTAssertEqual(occurrence.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testDailyRecurrenceWithInterval() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 3,
            count: 5
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 20, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 5)

        // Every 3 days
        for (index, occurrence) in occurrences.enumerated() {
            let expected = calendar.date(byAdding: .day, value: index * 3, to: start)!
            XCTAssertEqual(occurrence.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    // MARK: - Weekly Recurrence

    func testWeeklyRecurrence() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!  // Monday

        let rrule = RecurrenceRule(
            frequency: .weekly,
            interval: 1,
            count: 4
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 30, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 4)

        // Every week
        for (index, occurrence) in occurrences.enumerated() {
            let expected = calendar.date(byAdding: .weekOfYear, value: index, to: start)!
            XCTAssertEqual(occurrence.timeIntervalSince1970, expected.timeIntervalSince1970, accuracy: 1.0)
        }
    }

    func testWeeklyRecurrenceByDay() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1, hour: 9))!  // Monday Jan 1, 2024

        let rrule = RecurrenceRule(
            frequency: .weekly,
            interval: 1,
            count: 10,
            byDay: [.monday, .wednesday, .friday]
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 30, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 10)

        // Verify each occurrence is on Mon, Wed, or Fri
        for occurrence in occurrences {
            let weekday = calendar.component(.weekday, from: occurrence)
            XCTAssertTrue([2, 4, 6].contains(weekday), "Should be Monday(2), Wednesday(4), or Friday(6)")
        }
    }

    // MARK: - Monthly Recurrence

    func testMonthlyRecurrenceByMonthDay() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!

        let rrule = RecurrenceRule(
            frequency: .monthly,
            interval: 1,
            count: 6,
            byMonthDay: [15]
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .month, value: 12, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 6)

        // Verify each occurrence is on the 15th
        for occurrence in occurrences {
            let day = calendar.component(.day, from: occurrence)
            XCTAssertEqual(day, 15)
        }
    }

    func testMonthlyRecurrenceByDay() async throws {
        // Second Tuesday of each month
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 9))!  // Second Tuesday of Jan 2024

        let rrule = RecurrenceRule(
            frequency: .monthly,
            interval: 1,
            count: 5,
            byDay: [.tuesday]
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .month, value: 12, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        // Verify each occurrence is on Tuesday
        for occurrence in occurrences {
            let weekday = calendar.component(.weekday, from: occurrence)
            XCTAssertEqual(weekday, 3, "Should be Tuesday")
        }
    }

    // MARK: - Yearly Recurrence

    func testYearlyRecurrence() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 6, day: 15))!

        let rrule = RecurrenceRule(
            frequency: .yearly,
            interval: 1,
            count: 5
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .year, value: 10, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 5)

        // Verify each occurrence is on June 15
        for occurrence in occurrences {
            let month = calendar.component(.month, from: occurrence)
            let day = calendar.component(.day, from: occurrence)
            XCTAssertEqual(month, 6)
            XCTAssertEqual(day, 15)
        }
    }

    // MARK: - UNTIL Limit

    func testRecurrenceWithUntil() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let until = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            until: until
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .month, value: 1, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        // Should have occurrences from Jan 1 to Jan 10 (10 days)
        XCTAssertEqual(occurrences.count, 10)

        // Verify all occurrences are before or on until date
        for occurrence in occurrences {
            XCTAssertLessThanOrEqual(occurrence, until)
        }
    }

    // MARK: - EXDATE

    func testRecurrenceWithExdates() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let exdate1 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 3))!
        let exdate2 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 5))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            count: 7
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule,
            exdates: [exdate1, exdate2]
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 10, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        // 7 days minus 2 exceptions = 5 occurrences
        XCTAssertEqual(occurrences.count, 5)

        // Verify excluded dates are not in occurrences
        XCTAssertFalse(occurrences.contains { calendar.isDate($0, inSameDayAs: exdate1) })
        XCTAssertFalse(occurrences.contains { calendar.isDate($0, inSameDayAs: exdate2) })
    }

    // MARK: - RDATE

    func testRecurrenceWithRdates() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let rdate1 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 15))!
        let rdate2 = calendar.date(from: DateComponents(year: 2024, month: 1, day: 20))!

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rdates: [rdate1, rdate2]
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .month, value: 1, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        // Original start + 2 rdates = 3 occurrences
        XCTAssertEqual(occurrences.count, 3)
        XCTAssertTrue(occurrences.contains { calendar.isDate($0, inSameDayAs: start) })
        XCTAssertTrue(occurrences.contains { calendar.isDate($0, inSameDayAs: rdate1) })
        XCTAssertTrue(occurrences.contains { calendar.isDate($0, inSameDayAs: rdate2) })
    }

    // MARK: - Next Occurrence

    func testNextOccurrence() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            count: 10
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let searchDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 3))!
        let next = try await engine.nextOccurrence(for: event, after: searchDate)

        XCTAssertNotNil(next)
        XCTAssertTrue(next! > searchDate)

        let expected = calendar.date(from: DateComponents(year: 2024, month: 1, day: 4))!
        XCTAssertTrue(calendar.isDate(next!, inSameDayAs: expected))
    }

    func testNextOccurrenceNoMore() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            count: 5
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let searchDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 10))!
        let next = try await engine.nextOccurrence(for: event, after: searchDate)

        XCTAssertNil(next)
    }

    // MARK: - Is Occurrence

    func testIsOccurrence() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            count: 10
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let checkDate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 5))!
        let isOccurrence = try await engine.isOccurrence(for: event, on: checkDate)

        XCTAssertTrue(isOccurrence)
    }

    func testIsNotOccurrence() async throws {
        let start = calendar.date(from: DateComponents(year: 2024, month: 1, day: 1))!
        let exdate = calendar.date(from: DateComponents(year: 2024, month: 1, day: 5))!

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            count: 10
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule,
            exdates: [exdate]
        )

        let isOccurrence = try await engine.isOccurrence(for: event, on: exdate)

        XCTAssertFalse(isOccurrence)
    }

    // MARK: - Edge Cases

    func testEmptyEvent() async throws {
        let event = VEvent(
            uid: "test@example.com",
            dtstamp: Date()
        )

        let range = DateInterval(
            start: Date(),
            end: calendar.date(byAdding: .day, value: 7, to: Date())!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 0)
    }

    func testRecurrenceWithZeroCount() async throws {
        let start = Date()

        let rrule = RecurrenceRule(
            frequency: .daily,
            interval: 1,
            count: 0
        )

        let event = VEvent(
            uid: "test@example.com",
            dtstamp: start,
            dtstart: start,
            rrule: rrule
        )

        let range = DateInterval(
            start: start,
            end: calendar.date(byAdding: .day, value: 10, to: start)!
        )

        let occurrences = try await engine.occurrences(for: event, in: range)

        XCTAssertEqual(occurrences.count, 0)
    }
}
