import Foundation

/// iCalendar VTIMEZONE component
///
/// `VTimeZone` represents timezone information in an iCalendar.
///
/// **Note:** This is a simplified implementation. Full timezone support
/// will be added in Phase 11 (Advanced Features).
///
/// ## Topics
///
/// ### Creating Timezones
/// - ``init(tzid:standardOffset:daylightOffset:)``
public struct VTimeZone: Sendable, Equatable {
    /// Timezone identifier (e.g., "America/New_York")
    public var tzid: String

    /// Standard time offset from UTC (in seconds)
    public var standardOffset: Int?

    /// Daylight saving time offset from UTC (in seconds)
    public var daylightOffset: Int?

    /// Initialize a VTIMEZONE
    ///
    /// - Parameters:
    ///   - tzid: Timezone identifier
    ///   - standardOffset: Standard time offset from UTC
    ///   - daylightOffset: Daylight saving time offset from UTC
    public init(
        tzid: String,
        standardOffset: Int? = nil,
        daylightOffset: Int? = nil
    ) {
        self.tzid = tzid
        self.standardOffset = standardOffset
        self.daylightOffset = daylightOffset
    }
}
