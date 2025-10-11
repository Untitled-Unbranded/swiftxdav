import Foundation

/// Date formatting extensions for iCalendar and ISO 8601 formats
///
/// This extension provides formatters and convenience methods for working with
/// iCalendar date formats (RFC 5545) which are based on ISO 8601.
///
/// ## Topics
///
/// ### Formatters
/// - ``DateFormatter/iso8601``
/// - ``DateFormatter/iso8601DateOnly``
///
/// ### Formatting Dates
/// - ``Date/toICalendarFormat()``
/// - ``Date/toICalendarDateFormat()``
///
/// ### Parsing Dates
/// - ``String/fromICalendarFormat()``
/// - ``String/fromICalendarDateFormat()``
extension DateFormatter {
    /// ISO 8601 date formatter for iCalendar date-time values
    ///
    /// Format: `yyyyMMdd'T'HHmmss'Z'`
    ///
    /// Example: `20231125T143000Z` (November 25, 2023 at 14:30:00 UTC)
    ///
    /// This formatter uses:
    /// - ISO 8601 calendar
    /// - UTC timezone (indicated by 'Z' suffix)
    /// - en_US_POSIX locale for consistent parsing
    public static let iso8601: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        return formatter
    }()

    /// ISO 8601 date-only formatter for iCalendar date values
    ///
    /// Format: `yyyyMMdd`
    ///
    /// Example: `20231125` (November 25, 2023)
    ///
    /// This formatter is used for all-day events and dates without time components.
    public static let iso8601DateOnly: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd"
        return formatter
    }()

    /// ISO 8601 date-time formatter without UTC indicator (for floating times)
    ///
    /// Format: `yyyyMMdd'T'HHmmss`
    ///
    /// Example: `20231125T143000` (November 25, 2023 at 14:30:00 in local time)
    ///
    /// This formatter is used for floating date-times (times without a specific timezone).
    public static let iso8601Floating: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .iso8601)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyyMMdd'T'HHmmss"
        return formatter
    }()
}

extension Date {
    /// Format as iCalendar date-time string (UTC)
    ///
    /// Converts the date to UTC and formats it according to RFC 5545.
    ///
    /// - Returns: A string in the format `yyyyMMdd'T'HHmmss'Z'`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let date = Date()
    /// let icalString = date.toICalendarFormat()
    /// // Returns something like: "20231125T143000Z"
    /// ```
    public func toICalendarFormat() -> String {
        DateFormatter.iso8601.string(from: self)
    }

    /// Format as iCalendar date-only string
    ///
    /// Formats just the date portion without time, useful for all-day events.
    ///
    /// - Returns: A string in the format `yyyyMMdd`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let date = Date()
    /// let icalString = date.toICalendarDateFormat()
    /// // Returns something like: "20231125"
    /// ```
    public func toICalendarDateFormat() -> String {
        DateFormatter.iso8601DateOnly.string(from: self)
    }

    /// Format as iCalendar floating date-time string (no timezone)
    ///
    /// Formats the date without timezone information, for floating times.
    ///
    /// - Returns: A string in the format `yyyyMMdd'T'HHmmss`
    ///
    /// ## Example
    ///
    /// ```swift
    /// let date = Date()
    /// let icalString = date.toICalendarFloatingFormat()
    /// // Returns something like: "20231125T143000"
    /// ```
    public func toICalendarFloatingFormat() -> String {
        DateFormatter.iso8601Floating.string(from: self)
    }
}

extension String {
    /// Parse iCalendar date-time string
    ///
    /// Attempts to parse an iCalendar date-time value. Supports both UTC times
    /// (with 'Z' suffix) and floating times (without timezone).
    ///
    /// - Returns: The parsed date, or `nil` if parsing fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let icalString = "20231125T143000Z"
    /// if let date = icalString.fromICalendarFormat() {
    ///     print("Parsed date: \(date)")
    /// }
    /// ```
    public func fromICalendarFormat() -> Date? {
        // Try with 'Z' suffix first (UTC time)
        if let date = DateFormatter.iso8601.date(from: self) {
            return date
        }

        // Try without 'Z' suffix (floating time)
        if let date = DateFormatter.iso8601Floating.date(from: self) {
            return date
        }

        // Try with timezone parameter (e.g., DTSTART;TZID=America/New_York:20231125T143000)
        // For now, we'll just parse as floating time if no Z suffix
        // Full timezone support will be added in Phase 11

        return nil
    }

    /// Parse iCalendar date-only string
    ///
    /// Parses a date without time component, as used in all-day events.
    ///
    /// - Returns: The parsed date, or `nil` if parsing fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let icalString = "20231125"
    /// if let date = icalString.fromICalendarDateFormat() {
    ///     print("Parsed date: \(date)")
    /// }
    /// ```
    public func fromICalendarDateFormat() -> Date? {
        DateFormatter.iso8601DateOnly.date(from: self)
    }
}

// MARK: - RFC 2822 Date Format (for HTTP headers)

extension DateFormatter {
    /// RFC 2822 date formatter for HTTP headers
    ///
    /// Format: `EEE, dd MMM yyyy HH:mm:ss zzz`
    ///
    /// Example: `Sat, 25 Nov 2023 14:30:00 GMT`
    ///
    /// This formatter is used for HTTP headers like Last-Modified and Date.
    public static let rfc2822: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(abbreviation: "GMT")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss zzz"
        return formatter
    }()
}

extension Date {
    /// Format as RFC 2822 date string (for HTTP headers)
    ///
    /// - Returns: A string in RFC 2822 format
    ///
    /// ## Example
    ///
    /// ```swift
    /// let date = Date()
    /// let httpDate = date.toRFC2822Format()
    /// // Returns something like: "Sat, 25 Nov 2023 14:30:00 GMT"
    /// ```
    public func toRFC2822Format() -> String {
        DateFormatter.rfc2822.string(from: self)
    }
}

extension String {
    /// Parse RFC 2822 date string (from HTTP headers)
    ///
    /// - Returns: The parsed date, or `nil` if parsing fails
    ///
    /// ## Example
    ///
    /// ```swift
    /// let httpDate = "Sat, 25 Nov 2023 14:30:00 GMT"
    /// if let date = httpDate.fromRFC2822Format() {
    ///     print("Parsed date: \(date)")
    /// }
    /// ```
    public func fromRFC2822Format() -> Date? {
        DateFormatter.rfc2822.date(from: self)
    }
}
