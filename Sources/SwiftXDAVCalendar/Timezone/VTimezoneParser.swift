import Foundation

/// Parser for VTIMEZONE components in iCalendar data.
///
/// `VTimezoneParser` extracts timezone information from VTIMEZONE components,
/// including STANDARD and DAYLIGHT sub-components for handling DST transitions.
///
/// ## Topics
///
/// ### Parsing
/// - ``parse(_:)``
/// - ``extractTZID(from:)``
///
/// ### Usage
///
/// ```swift
/// let parser = VTimezoneParser()
/// let vtimezone = try parser.parse(icalendarData)
/// ```
public struct VTimezoneParser: Sendable {

    public init() {}

    /// Parse a VTIMEZONE component from iCalendar data.
    ///
    /// - Parameter data: The iCalendar data containing a VTIMEZONE component.
    /// - Returns: A VTimeZone instance.
    /// - Throws: ``SwiftXDAVError`` if parsing fails.
    public func parse(_ data: String) throws -> VTimeZone {
        let lines = data.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard lines.contains("BEGIN:VTIMEZONE") else {
            throw SwiftXDAVError.parsingError("Missing BEGIN:VTIMEZONE")
        }

        guard lines.contains("END:VTIMEZONE") else {
            throw SwiftXDAVError.parsingError("Missing END:VTIMEZONE")
        }

        var tzid: String?
        var standardOffset: Int?
        var daylightOffset: Int?

        for line in lines {
            if line.hasPrefix("TZID:") {
                tzid = String(line.dropFirst(5))
            } else if line.hasPrefix("TZOFFSETFROM:") || line.hasPrefix("TZOFFSETTO:") {
                // Parse offset (format: +0500, -0800, etc.)
                let offsetString = String(line.split(separator: ":").last ?? "")
                if let offset = parseOffset(offsetString) {
                    if line.contains("STANDARD") {
                        standardOffset = offset
                    } else if line.contains("DAYLIGHT") {
                        daylightOffset = offset
                    } else {
                        // If not in a sub-component, use as standard
                        standardOffset = offset
                    }
                }
            }
        }

        guard let tzid = tzid else {
            throw SwiftXDAVError.parsingError("Missing TZID in VTIMEZONE")
        }

        return VTimeZone(
            tzid: tzid,
            standardOffset: standardOffset,
            daylightOffset: daylightOffset
        )
    }

    /// Extract TZID from VTIMEZONE data without full parsing.
    ///
    /// - Parameter data: The iCalendar data containing a VTIMEZONE component.
    /// - Returns: The TZID string, or nil if not found.
    public func extractTZID(from data: String) -> String? {
        let lines = data.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("TZID:") {
                return String(trimmed.dropFirst(5))
            }
        }
        return nil
    }

    // MARK: - Private Methods

    /// Parse a timezone offset string to seconds.
    ///
    /// Offset formats: +0500, -0800, +053045, etc.
    ///
    /// - Parameter offsetString: The offset string.
    /// - Returns: Offset in seconds, or nil if invalid.
    private func parseOffset(_ offsetString: String) -> Int? {
        let trimmed = offsetString.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // Determine sign
        let isNegative = trimmed.hasPrefix("-")
        let absString = trimmed.replacingOccurrences(of: "+", with: "").replacingOccurrences(of: "-", with: "")

        // Parse components (HHMM or HHMMSS)
        guard absString.count >= 4 else { return nil }

        let hourString = String(absString.prefix(2))
        let minuteString = String(absString.dropFirst(2).prefix(2))
        let secondString = absString.count >= 6 ? String(absString.dropFirst(4).prefix(2)) : "0"

        guard let hours = Int(hourString),
              let minutes = Int(minuteString),
              let seconds = Int(secondString) else {
            return nil
        }

        let totalSeconds = (hours * 3600) + (minutes * 60) + seconds
        return isNegative ? -totalSeconds : totalSeconds
    }
}
