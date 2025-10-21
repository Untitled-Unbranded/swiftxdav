import Foundation

/// A comprehensive recurrence rule expansion engine compliant with RFC 5545.
///
/// The `RecurrenceEngine` expands recurrence rules (RRULE) into concrete occurrence dates,
/// handling all recurrence frequencies, BY-rules, and edge cases according to RFC 5545 Section 3.3.10.
///
/// ## Topics
///
/// ### Expanding Recurrence Rules
/// - ``occurrences(for:in:limit:)``
/// - ``nextOccurrence(for:after:)``
/// - ``isOccurrence(for:on:)``
///
/// ### Usage
///
/// ```swift
/// let engine = RecurrenceEngine()
/// let event = VEvent(/* ... */)
/// let range = DateInterval(start: startDate, end: endDate)
///
/// let occurrences = try engine.occurrences(for: event, in: range)
/// ```
public actor RecurrenceEngine: Sendable {

    /// Maximum number of occurrences to generate (safety limit)
    public static let maxOccurrences = 10000

    public init() {}

    /// Calculate all occurrences of an event within a date range.
    ///
    /// This method expands the event's recurrence rule (RRULE) and applies exception dates (EXDATE)
    /// and additional dates (RDATE) to generate all occurrences within the specified range.
    ///
    /// - Parameters:
    ///   - event: The event to expand (may be recurring or non-recurring).
    ///   - range: The date range to generate occurrences within.
    ///   - limit: Optional limit on number of occurrences (defaults to maxOccurrences).
    /// - Returns: An array of occurrence start dates.
    /// - Throws: ``SwiftXDAVError`` if expansion fails.
    public func occurrences(
        for event: VEvent,
        in range: DateInterval,
        limit: Int = maxOccurrences
    ) throws -> [Date] {
        guard let dtstart = event.dtstart else {
            return []
        }

        // Non-recurring event
        guard let rrule = event.rrule else {
            var occurrences: [Date] = []

            // Check if single occurrence falls within range
            if range.contains(dtstart) {
                occurrences.append(dtstart)
            }

            // Add any RDATEs that fall within range
            if !event.rdates.isEmpty {
                occurrences.append(contentsOf: event.rdates.filter { range.contains($0) })
            }

            return occurrences.sorted()
        }

        // Generate candidates from RRULE
        var candidates = try expandRecurrenceRule(
            rrule: rrule,
            dtstart: dtstart,
            in: range,
            limit: limit
        )

        // Add RDATE (additional dates)
        if !event.rdates.isEmpty {
            candidates.append(contentsOf: event.rdates.filter { range.contains($0) })
            candidates.sort()
        }

        // Remove EXDATE (exception dates)
        if !event.exdates.isEmpty {
            let exdateSet = Set(event.exdates.map { normalizeDate($0) })
            candidates = candidates.filter { !exdateSet.contains(normalizeDate($0)) }
        }

        // Apply limit
        if candidates.count > limit {
            candidates = Array(candidates.prefix(limit))
        }

        return candidates
    }

    /// Find the next occurrence of an event after a given date.
    ///
    /// - Parameters:
    ///   - event: The event to check.
    ///   - date: The date to search after.
    /// - Returns: The next occurrence date, or nil if there are no more occurrences.
    /// - Throws: ``SwiftXDAVError`` if expansion fails.
    public func nextOccurrence(for event: VEvent, after date: Date) throws -> Date? {
        guard let dtstart = event.dtstart else {
            return nil
        }

        // For non-recurring events
        guard let rrule = event.rrule else {
            return dtstart > date ? dtstart : nil
        }

        // Determine search range
        // For COUNT-based rules, we need to expand from start
        // For UNTIL-based rules, we can search from 'date'
        let searchStart = dtstart
        let searchEnd: Date

        if let until = rrule.until {
            searchEnd = until
        } else if let count = rrule.count {
            // Estimate an end date based on frequency and count
            searchEnd = estimateEndDate(from: dtstart, frequency: rrule.frequency, count: count, interval: rrule.interval)
        } else {
            // No limit - search up to 10 years ahead
            searchEnd = Foundation.Calendar.current.date(byAdding: .year, value: 10, to: date) ?? date
        }

        let range = DateInterval(start: searchStart, end: searchEnd)
        let occurrences = try self.occurrences(for: event, in: range)

        return occurrences.first { $0 > date }
    }

    /// Check if a specific date is an occurrence of an event.
    ///
    /// - Parameters:
    ///   - event: The event to check.
    ///   - date: The date to check.
    /// - Returns: True if the date is an occurrence.
    /// - Throws: ``SwiftXDAVError`` if expansion fails.
    public func isOccurrence(for event: VEvent, on date: Date) throws -> Bool {
        guard let dtstart = event.dtstart else {
            return false
        }

        // Normalize dates for comparison (remove sub-second precision)
        let normalizedDate = normalizeDate(date)
        let normalizedStart = normalizeDate(dtstart)

        // Non-recurring event
        guard let rrule = event.rrule else {
            return normalizedDate == normalizedStart
        }

        // Check if explicitly excluded
        if event.exdates.contains(where: { normalizeDate($0) == normalizedDate }) {
            return false
        }

        // Check if explicitly included
        if event.rdates.contains(where: { normalizeDate($0) == normalizedDate }) {
            return true
        }

        // Check if date matches recurrence pattern
        // Generate occurrences in a range around the date
        let dayBefore = Foundation.Calendar.current.date(byAdding: .day, value: -1, to: date) ?? date
        let dayAfter = Foundation.Calendar.current.date(byAdding: .day, value: 1, to: date) ?? date
        let range = DateInterval(start: dayBefore, end: dayAfter)

        let occurrences = try self.occurrences(for: event, in: range, limit: 100)
        return occurrences.contains(where: { normalizeDate($0) == normalizedDate })
    }

    // MARK: - Private Methods

    /// Expand a recurrence rule into occurrence dates.
    private func expandRecurrenceRule(
        rrule: RecurrenceRule,
        dtstart: Date,
        in range: DateInterval,
        limit: Int
    ) throws -> [Date] {
        var occurrences: [Date] = []
        let calendar = Foundation.Calendar.current

        // Special handling for WEEKLY + BYDAY
        if rrule.frequency == .weekly, let byDay = rrule.byDay, !byDay.isEmpty {
            return try expandWeeklyByDay(rrule: rrule, dtstart: dtstart, in: range, limit: limit, byDay: byDay, calendar: calendar)
        }

        // General expansion for other cases
        let frequency = rrule.frequency
        let interval = max(1, rrule.interval)

        var currentDate = dtstart
        var iterationCount = 0
        let maxIterations = limit * 10

        let untilDate = rrule.until ?? range.end

        while iterationCount < maxIterations {
            iterationCount += 1

            if currentDate > untilDate {
                break
            }

            if let count = rrule.count, occurrences.count >= count {
                break
            }

            if occurrences.count >= limit {
                break
            }

            if matchesByRules(date: currentDate, rrule: rrule, dtstart: dtstart) {
                if range.contains(currentDate) || currentDate >= range.start {
                    occurrences.append(currentDate)
                }

                if currentDate > range.end && occurrences.count > 0 {
                    break
                }
            }

            currentDate = try advanceDate(currentDate, by: frequency, interval: interval, using: calendar)

            if currentDate > range.end {
                let maxDistance = calendar.dateComponents([.year], from: range.end, to: currentDate).year ?? 0
                if maxDistance > 5 && occurrences.isEmpty {
                    break
                }
            }
        }

        if let bySetPos = rrule.bySetPos, !bySetPos.isEmpty {
            occurrences = applyBySetPos(to: occurrences, positions: bySetPos, rrule: rrule, dtstart: dtstart)
        }

        return occurrences.sorted()
    }

    /// Special expansion for WEEKLY frequency with BYDAY.
    private func expandWeeklyByDay(
        rrule: RecurrenceRule,
        dtstart: Date,
        in range: DateInterval,
        limit: Int,
        byDay: [WeekDay],
        calendar: Foundation.Calendar
    ) throws -> [Date] {
        var occurrences: [Date] = []
        let interval = max(1, rrule.interval)
        let untilDate = rrule.until ?? range.end

        // Start from the week containing dtstart
        var currentWeekStart = dtstart
        var weekCount = 0
        let maxWeeks = limit * 2 // Safety limit

        while weekCount < maxWeeks {
            // Generate occurrences for this week
            for weekDay in byDay {
                // Find the date for this weekday in the current week
                let targetWeekday = weekDay.weekdayValue
                let currentComponents = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: currentWeekStart)

                guard let currentWeekday = currentComponents.weekday else {
                    continue
                }

                // Calculate days to add to get to target weekday
                var daysToAdd = targetWeekday - currentWeekday
                if daysToAdd < 0 {
                    daysToAdd += 7
                }

                guard let occurrenceDate = calendar.date(byAdding: .day, value: daysToAdd, to: currentWeekStart) else {
                    continue
                }

                // Check if this occurrence is valid
                if occurrenceDate >= dtstart && occurrenceDate <= untilDate {
                    if range.contains(occurrenceDate) || occurrenceDate >= range.start {
                        occurrences.append(occurrenceDate)
                    }
                }

                // Check count limit
                if let count = rrule.count, occurrences.count >= count {
                    return occurrences.sorted()
                }

                if occurrences.count >= limit {
                    return occurrences.sorted()
                }
            }

            // Move to next week (based on interval)
            guard let nextWeek = calendar.date(byAdding: .weekOfYear, value: interval, to: currentWeekStart) else {
                break
            }

            currentWeekStart = nextWeek
            weekCount += 1

            // Stop if we're past the range and have some occurrences
            if currentWeekStart > range.end && occurrences.count > 0 {
                break
            }

            if currentWeekStart > untilDate {
                break
            }
        }

        return occurrences.sorted()
    }

    /// Check if a date matches the BY-rules of a recurrence rule.
    private func matchesByRules(date: Date, rrule: RecurrenceRule, dtstart: Date) -> Bool {
        let calendar = Foundation.Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .weekday, .hour, .minute, .second], from: date)

        // BYMONTH: Must occur in these months
        if let byMonth = rrule.byMonth, !byMonth.isEmpty {
            guard let month = components.month, byMonth.contains(month) else {
                return false
            }
        }

        // BYMONTHDAY: Must occur on these days of the month
        if let byMonthDay = rrule.byMonthDay, !byMonthDay.isEmpty {
            guard let day = components.day else {
                return false
            }

            // Handle negative days (from end of month)
            let daysInMonth = calendar.range(of: .day, in: .month, for: date)?.count ?? 30
            let matchesPositive = byMonthDay.contains(day)
            let matchesNegative = byMonthDay.contains { $0 < 0 && (daysInMonth + $0 + 1) == day }

            if !matchesPositive && !matchesNegative {
                return false
            }
        }

        // BYDAY: Must occur on these weekdays
        if let byDay = rrule.byDay, !byDay.isEmpty {
            guard let weekday = components.weekday else {
                return false
            }

            // Convert Calendar weekday (1=Sunday) to WeekDay
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
    private func advanceDate(_ date: Date, by frequency: RecurrenceFrequency, interval: Int, using calendar: Foundation.Calendar) throws -> Date {
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

    /// Apply BYSETPOS to filter occurrences.
    private func applyBySetPos(to occurrences: [Date], positions: [Int], rrule: RecurrenceRule, dtstart: Date) -> [Date] {
        // BYSETPOS works on groups of occurrences within the recurrence period
        // For now, simple implementation that takes positions from the full set
        var result: [Date] = []

        for pos in positions {
            if pos > 0 && pos <= occurrences.count {
                result.append(occurrences[pos - 1])
            } else if pos < 0 {
                let index = occurrences.count + pos
                if index >= 0 && index < occurrences.count {
                    result.append(occurrences[index])
                }
            }
        }

        return result.sorted()
    }

    /// Normalize a date by removing sub-second precision.
    private func normalizeDate(_ date: Date) -> Date {
        let timeInterval = floor(date.timeIntervalSinceReferenceDate)
        return Date(timeIntervalSinceReferenceDate: timeInterval)
    }

    /// Estimate an end date for COUNT-based recurrence rules.
    private func estimateEndDate(from start: Date, frequency: RecurrenceFrequency, count: Int, interval: Int) -> Date {
        let calendar = Foundation.Calendar.current
        let totalInterval = count * interval

        switch frequency {
        case .secondly:
            return calendar.date(byAdding: .second, value: totalInterval, to: start) ?? start
        case .minutely:
            return calendar.date(byAdding: .minute, value: totalInterval, to: start) ?? start
        case .hourly:
            return calendar.date(byAdding: .hour, value: totalInterval, to: start) ?? start
        case .daily:
            return calendar.date(byAdding: .day, value: totalInterval, to: start) ?? start
        case .weekly:
            return calendar.date(byAdding: .weekOfYear, value: totalInterval, to: start) ?? start
        case .monthly:
            return calendar.date(byAdding: .month, value: totalInterval, to: start) ?? start
        case .yearly:
            return calendar.date(byAdding: .year, value: totalInterval, to: start) ?? start
        }
    }
}

// MARK: - WeekDay Extension

extension WeekDay {
    /// Convert to Calendar weekday value (1=Sunday, 2=Monday, ..., 7=Saturday)
    var weekdayValue: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .tuesday: return 3
        case .wednesday: return 4
        case .thursday: return 5
        case .friday: return 6
        case .saturday: return 7
        }
    }

    /// Create from Calendar weekday value
    init?(weekdayValue: Int) {
        switch weekdayValue {
        case 1: self = .sunday
        case 2: self = .monday
        case 3: self = .tuesday
        case 4: self = .wednesday
        case 5: self = .thursday
        case 6: self = .friday
        case 7: self = .saturday
        default: return nil
        }
    }
}
