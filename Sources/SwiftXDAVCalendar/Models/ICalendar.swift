import Foundation

/// Root iCalendar container (VCALENDAR)
///
/// `ICalendar` represents the root container for iCalendar data,
/// containing events, todos, and timezone definitions.
///
/// ## Usage
///
/// ```swift
/// let calendar = ICalendar(events: [event1, event2])
/// let serializer = ICalendarSerializer()
/// let data = try await serializer.serialize(calendar)
/// ```
///
/// ## Topics
///
/// ### Creating Calendars
/// - ``init(version:prodid:calscale:method:events:todos:timezones:)``
///
/// ### Properties
/// - ``version``
/// - ``prodid``
/// - ``calscale``
/// - ``method``
/// - ``events``
/// - ``todos``
/// - ``timezones``
public struct ICalendar: Sendable, Equatable {
    /// iCalendar version (typically "2.0")
    public var version: String

    /// Product identifier
    public var prodid: String

    /// Calendar scale (typically "GREGORIAN")
    public var calscale: String

    /// iCalendar method (e.g., "REQUEST", "PUBLISH")
    public var method: String?

    /// Events in this calendar
    public var events: [VEvent]

    /// Todos in this calendar
    public var todos: [VTodo]

    /// Timezones defined in this calendar
    public var timezones: [VTimeZone]

    /// Initialize an iCalendar
    ///
    /// - Parameters:
    ///   - version: iCalendar version (defaults to "2.0")
    ///   - prodid: Product identifier
    ///   - calscale: Calendar scale (defaults to "GREGORIAN")
    ///   - method: Optional iCalendar method
    ///   - events: Events in this calendar
    ///   - todos: Todos in this calendar
    ///   - timezones: Timezone definitions
    public init(
        version: String = "2.0",
        prodid: String = "-//SwiftXDAV//SwiftXDAV 1.0//EN",
        calscale: String = "GREGORIAN",
        method: String? = nil,
        events: [VEvent] = [],
        todos: [VTodo] = [],
        timezones: [VTimeZone] = []
    ) {
        self.version = version
        self.prodid = prodid
        self.calscale = calscale
        self.method = method
        self.events = events
        self.todos = todos
        self.timezones = timezones
    }
}
