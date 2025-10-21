import Foundation

/// An iterator for generating recurrence rule occurrences on-demand.
///
/// `RecurrenceIterator` provides a memory-efficient way to iterate through
/// recurrence occurrences without generating them all in advance. This is especially
/// useful for infinite or very long recurrence rules.
///
/// ## Topics
///
/// ### Creating an Iterator
/// - ``init(event:startingFrom:)``
///
/// ### Iterating
/// - ``next()``
/// - ``hasNext``
///
/// ### Usage
///
/// ```swift
/// let iterator = RecurrenceIterator(event: event, startingFrom: Date())
///
/// while let occurrence = try await iterator.next() {
///     print("Next occurrence: \(occurrence)")
///
///     // Break after 10 occurrences
///     if processedCount >= 10 { break }
/// }
/// ```
public actor RecurrenceIterator: Sendable {

    private let event: VEvent
    private let dtstart: Date
    private let rrule: RecurrenceRule?
    private let calendar: Foundation.Calendar
    private var currentDate: Date
    private var occurrenceCount: Int
    private var iterationCount: Int
    private let maxIterations: Int

    /// Initialize a recurrence iterator.
    ///
    /// - Parameters:
    ///   - event: The event to iterate occurrences for.
    ///   - startDate: The date to start iteration from (defaults to event's dtstart).
    public init(event: VEvent, startingFrom startDate: Date? = nil) {
        self.event = event
        let effectiveStart = event.dtstart ?? Date()
        self.dtstart = effectiveStart
        self.rrule = event.rrule
        self.calendar = Foundation.Calendar.current
        self.currentDate = startDate ?? effectiveStart
        self.occurrenceCount = 0
        self.iterationCount = 0
        self.maxIterations = RecurrenceEngine.maxOccurrences * 10
    }

    /// Get the next occurrence.
    ///
    /// - Returns: The next occurrence date, or nil if there are no more occurrences.
    /// - Throws: ``SwiftXDAVError`` if iteration fails.
    public func next() throws -> Date? {
        // Non-recurring event
        guard let rrule = rrule else {
            if occurrenceCount == 0 {
                occurrenceCount += 1
                return dtstart
            }
            return nil
        }

        // Check limits
        if let count = rrule.count, occurrenceCount >= count {
            return nil
        }

        if iterationCount >= maxIterations {
            return nil
        }

        // Search for next valid occurrence
        while iterationCount < maxIterations {
            iterationCount += 1

            // Check until limit
            if let until = rrule.until, currentDate > until {
                return nil
            }

            // Check if current date matches recurrence pattern
            if matchesByRules(date: currentDate, rrule: rrule) {
                // Check if not in EXDATE
                if !event.exdates.isEmpty && event.exdates.contains(where: { normalizeDate($0) == normalizeDate(currentDate) }) {
                    // Skip this occurrence, continue to next
                    currentDate = try advanceDate(currentDate, by: rrule.frequency, interval: max(1, rrule.interval))
                    continue
                }

                occurrenceCount += 1
                let occurrence = currentDate

                // Advance for next iteration
                currentDate = try advanceDate(currentDate, by: rrule.frequency, interval: max(1, rrule.interval))

                return occurrence
            }

            // Advance to next candidate
            currentDate = try advanceDate(currentDate, by: rrule.frequency, interval: max(1, rrule.interval))
        }

        return nil
    }

    /// Check if there might be more occurrences.
    ///
    /// Note: This is a heuristic check and may return true even if next() will return nil.
    public var hasNext: Bool {
        guard let rrule = rrule else {
            return occurrenceCount == 0
        }

        if let count = rrule.count {
            return occurrenceCount < count
        }

        if let until = rrule.until {
            return currentDate <= until
        }

        return iterationCount < maxIterations
    }

    // MARK: - Private Methods

    /// Check if a date matches the BY-rules of a recurrence rule.
    private func matchesByRules(date: Date, rrule: RecurrenceRule) -> Bool {
        let components = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: date)

        // BYMONTH
        if let byMonth = rrule.byMonth, !byMonth.isEmpty {
            guard let month = components.month, byMonth.contains(month) else {
                return false
            }
        }

        // BYMONTHDAY
        if let byMonthDay = rrule.byMonthDay, !byMonthDay.isEmpty {
            guard let day = components.day else {
                return false
            }

            let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
            let matchesPositive = byMonthDay.contains(day)
            let matchesNegative = byMonthDay.contains { $0 < 0 && (daysInMonth + $0 + 1) == day }

            if !matchesPositive && !matchesNegative {
                return false
            }
        }

        // BYDAY
        if let byDay = rrule.byDay, !byDay.isEmpty {
            guard let weekday = components.weekday else {
                return false
            }

            let weekDayMatches = byDay.contains { weekDayItem in
                weekDayItem.weekdayValue == weekday
            }

            if !weekDayMatches {
                return false
            }
        }

        return true
    }

    /// Advance a date according to the recurrence frequency.
    private func advanceDate(_ date: Date, by frequency: RecurrenceFrequency, interval: Int) throws -> Date {
        switch frequency {
        case .secondly:
            return calendar.date(byAdding: .second, value: interval, to: date) ?? date
        case .minutely:
            return calendar.date(byAdding: .minute, value: interval, to: date) ?? date
        case .hourly:
            return calendar.date(byAdding: .hour, value: interval, to: date) ?? date
        case .daily:
            return calendar.date(byAdding: .day, value: interval, to: date) ?? date
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: interval, to: date) ?? date
        case .monthly:
            return calendar.date(byAdding: .month, value: interval, to: date) ?? date
        case .yearly:
            return calendar.date(byAdding: .year, value: interval, to: date) ?? date
        }
    }

    /// Normalize a date by removing sub-second precision.
    private func normalizeDate(_ date: Date) -> Date {
        let timeInterval = floor(date.timeIntervalSinceReferenceDate)
        return Date(timeIntervalSinceReferenceDate: timeInterval)
    }
}
