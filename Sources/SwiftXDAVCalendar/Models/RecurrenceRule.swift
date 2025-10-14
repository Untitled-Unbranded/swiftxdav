import Foundation

/// iCalendar recurrence rule (RRULE)
///
/// `RecurrenceRule` represents the recurrence pattern for repeating events.
///
/// **Note:** This is a simplified implementation. Full recurrence expansion
/// will be added in Phase 11 (Advanced Features).
///
/// ## Topics
///
/// ### Creating Recurrence Rules
/// - ``init(frequency:interval:count:until:byDay:byMonthDay:byMonth:bySetPos:weekStart:)``
public struct RecurrenceRule: Sendable, Equatable {
    /// Recurrence frequency
    public var frequency: RecurrenceFrequency

    /// Interval between occurrences (default is 1)
    public var interval: Int

    /// Total count of occurrences (mutually exclusive with until)
    public var count: Int?

    /// End date for recurrence (mutually exclusive with count)
    public var until: Date?

    /// Days of the week (e.g., MO, TU, WE)
    public var byDay: [WeekDay]?

    /// Days of the month (1-31)
    public var byMonthDay: [Int]?

    /// Months (1-12)
    public var byMonth: [Int]?

    /// Set position (e.g., first, last)
    public var bySetPos: [Int]?

    /// Week start day
    public var weekStart: WeekDay?

    /// Initialize a recurrence rule
    ///
    /// - Parameters:
    ///   - frequency: Recurrence frequency
    ///   - interval: Interval between occurrences
    ///   - count: Total count of occurrences
    ///   - until: End date for recurrence
    ///   - byDay: Days of the week
    ///   - byMonthDay: Days of the month
    ///   - byMonth: Months
    ///   - bySetPos: Set positions
    ///   - weekStart: Week start day
    public init(
        frequency: RecurrenceFrequency,
        interval: Int = 1,
        count: Int? = nil,
        until: Date? = nil,
        byDay: [WeekDay]? = nil,
        byMonthDay: [Int]? = nil,
        byMonth: [Int]? = nil,
        bySetPos: [Int]? = nil,
        weekStart: WeekDay? = nil
    ) {
        self.frequency = frequency
        self.interval = interval
        self.count = count
        self.until = until
        self.byDay = byDay
        self.byMonthDay = byMonthDay
        self.byMonth = byMonth
        self.bySetPos = bySetPos
        self.weekStart = weekStart
    }
}

/// Recurrence frequency values
public enum RecurrenceFrequency: String, Sendable, Equatable {
    /// Every second
    case secondly = "SECONDLY"

    /// Every minute
    case minutely = "MINUTELY"

    /// Every hour
    case hourly = "HOURLY"

    /// Every day
    case daily = "DAILY"

    /// Every week
    case weekly = "WEEKLY"

    /// Every month
    case monthly = "MONTHLY"

    /// Every year
    case yearly = "YEARLY"
}

/// Day of the week
public enum WeekDay: String, Sendable, Equatable {
    /// Sunday
    case sunday = "SU"

    /// Monday
    case monday = "MO"

    /// Tuesday
    case tuesday = "TU"

    /// Wednesday
    case wednesday = "WE"

    /// Thursday
    case thursday = "TH"

    /// Friday
    case friday = "FR"

    /// Saturday
    case saturday = "SA"
}
