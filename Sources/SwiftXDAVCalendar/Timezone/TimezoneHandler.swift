import Foundation

/// Handles timezone operations for iCalendar data.
///
/// `TimezoneHandler` provides utilities for converting dates between timezones,
/// handling DST transitions, and mapping between iCalendar TZID values and
/// Foundation TimeZone instances.
///
/// ## Topics
///
/// ### Converting Dates
/// - ``convert(_:from:to:)``
/// - ``convertToUTC(_:from:)``
/// - ``convertFromUTC(_:to:)``
///
/// ### Timezone Lookup
/// - ``timezone(for:)``
/// - ``isFloatingTime(_:)``
///
/// ### Usage
///
/// ```swift
/// let handler = TimezoneHandler()
///
/// // Convert a date from one timezone to another
/// if let pstZone = handler.timezone(for: "America/Los_Angeles"),
///    let estZone = handler.timezone(for: "America/New_York") {
///     let converted = handler.convert(date, from: pstZone, to: estZone)
/// }
/// ```
public struct TimezoneHandler: Sendable {

    public init() {}

    /// Convert a date from one timezone to another.
    ///
    /// - Parameters:
    ///   - date: The date to convert.
    ///   - sourceTimezone: The source timezone.
    ///   - targetTimezone: The target timezone.
    /// - Returns: The converted date.
    public func convert(_ date: Date, from sourceTimezone: Foundation.TimeZone, to targetTimezone: Foundation.TimeZone) -> Date {
        // Dates are absolute points in time, so we don't actually need to convert
        // However, we may need to adjust the representation for display purposes
        // For now, return the date as-is since Date is timezone-agnostic
        return date
    }

    /// Convert a date to UTC from a given timezone.
    ///
    /// - Parameters:
    ///   - date: The date to convert.
    ///   - timezone: The source timezone.
    /// - Returns: The date in UTC.
    public func convertToUTC(_ date: Date, from timezone: Foundation.TimeZone) -> Date {
        return date // Date is already in UTC internally
    }

    /// Convert a UTC date to a specific timezone.
    ///
    /// - Parameters:
    ///   - date: The UTC date.
    ///   - timezone: The target timezone.
    /// - Returns: The converted date.
    public func convertFromUTC(_ date: Date, to timezone: Foundation.TimeZone) -> Date {
        return date // Date is already in UTC internally
    }

    /// Get a Foundation TimeZone for an iCalendar TZID.
    ///
    /// This method attempts to map iCalendar timezone identifiers to Foundation TimeZone instances.
    /// It handles common variations and aliases.
    ///
    /// - Parameter tzid: The iCalendar TZID (e.g., "America/Los_Angeles", "UTC", "US-Eastern").
    /// - Returns: A TimeZone instance, or nil if the timezone cannot be determined.
    public func timezone(for tzid: String) -> Foundation.TimeZone? {
        // Try direct lookup first
        if let timezone = Foundation.TimeZone(identifier: tzid) {
            return timezone
        }

        // Handle common aliases and variations
        let normalized = normalizeTZID(tzid)
        if let timezone = Foundation.TimeZone(identifier: normalized) {
            return timezone
        }

        // Try abbreviation lookup
        if let timezone = Foundation.TimeZone(abbreviation: tzid) {
            return timezone
        }

        return nil
    }

    /// Check if a timezone represents floating time (no specific timezone).
    ///
    /// Floating time in iCalendar means the time is local to whatever timezone
    /// the event is being viewed in.
    ///
    /// - Parameter tzid: The timezone identifier, or nil for floating time.
    /// - Returns: True if this represents floating time.
    public func isFloatingTime(_ tzid: String?) -> Bool {
        return tzid == nil || tzid?.isEmpty == true
    }

    /// Get the offset from UTC for a timezone at a specific date.
    ///
    /// - Parameters:
    ///   - timezone: The timezone.
    ///   - date: The date to check (important for DST).
    /// - Returns: The offset in seconds from UTC.
    public func utcOffset(for timezone: Foundation.TimeZone, at date: Date) -> Int {
        return timezone.secondsFromGMT(for: date)
    }

    /// Check if a timezone observes DST at a specific date.
    ///
    /// - Parameters:
    ///   - timezone: The timezone.
    ///   - date: The date to check.
    /// - Returns: True if DST is in effect at the given date.
    public func isDaylightSavingTime(in timezone: Foundation.TimeZone, at date: Date) -> Bool {
        return timezone.isDaylightSavingTime(for: date)
    }

    /// Get the next DST transition date for a timezone after a given date.
    ///
    /// - Parameters:
    ///   - timezone: The timezone.
    ///   - date: The starting date.
    /// - Returns: The next DST transition date, or nil if unavailable.
    public func nextDSTTransition(for timezone: Foundation.TimeZone, after date: Date) -> Date? {
        return timezone.nextDaylightSavingTimeTransition(after: date)
    }

    // MARK: - Private Methods

    /// Normalize a TZID to a Foundation TimeZone identifier.
    private func normalizeTZID(_ tzid: String) -> String {
        var normalized = tzid

        // Remove common prefixes
        if normalized.hasPrefix("/") {
            normalized = String(normalized.dropFirst())
        }

        // Handle Microsoft timezone IDs (often used in Exchange/Outlook)
        let microsoftMappings: [String: String] = [
            "Eastern Standard Time": "America/New_York",
            "Central Standard Time": "America/Chicago",
            "Mountain Standard Time": "America/Denver",
            "Pacific Standard Time": "America/Los_Angeles",
            "GMT Standard Time": "Europe/London",
            "W. Europe Standard Time": "Europe/Paris",
            "Central European Standard Time": "Europe/Warsaw",
            "Tokyo Standard Time": "Asia/Tokyo",
            "China Standard Time": "Asia/Shanghai",
            "AUS Eastern Standard Time": "Australia/Sydney"
        ]

        if let mapping = microsoftMappings[tzid] {
            return mapping
        }

        // Handle legacy TZID formats
        if normalized.hasPrefix("US/") || normalized.hasPrefix("US-") {
            let location = normalized.replacingOccurrences(of: "US/", with: "").replacingOccurrences(of: "US-", with: "")
            switch location {
            case "Eastern": return "America/New_York"
            case "Central": return "America/Chicago"
            case "Mountain": return "America/Denver"
            case "Pacific": return "America/Los_Angeles"
            default: break
            }
        }

        return normalized
    }
}

// MARK: - Date Extension

extension Date {
    /// Create a date in a specific timezone from components.
    ///
    /// - Parameters:
    ///   - year: Year component.
    ///   - month: Month component (1-12).
    ///   - day: Day component (1-31).
    ///   - hour: Hour component (0-23).
    ///   - minute: Minute component (0-59).
    ///   - second: Second component (0-59).
    ///   - timezone: The timezone for the components.
    /// - Returns: A Date instance, or nil if the components are invalid.
    public static func from(
        year: Int,
        month: Int,
        day: Int,
        hour: Int = 0,
        minute: Int = 0,
        second: Int = 0,
        in timezone: Foundation.TimeZone
    ) -> Date? {
        var calendar = Foundation.Calendar.current
        calendar.timeZone = timezone

        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.second = second

        return calendar.date(from: components)
    }

    /// Extract components in a specific timezone.
    ///
    /// - Parameter timezone: The timezone to use for extraction.
    /// - Returns: Date components in the specified timezone.
    public func components(in timezone: Foundation.TimeZone) -> DateComponents {
        var calendar = Foundation.Calendar.current
        calendar.timeZone = timezone

        return calendar.dateComponents(
            [.year, .month, .day, .hour, .minute, .second, .weekday, .timeZone],
            from: self
        )
    }
}
