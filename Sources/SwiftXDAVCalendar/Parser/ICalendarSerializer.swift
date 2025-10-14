import Foundation
import SwiftXDAVCore

/// Serializer for iCalendar data (RFC 5545)
///
/// `ICalendarSerializer` converts structured iCalendar models into text format.
/// It handles line folding, text escaping, and proper formatting.
///
/// ## Usage
///
/// ```swift
/// let calendar = ICalendar(events: [event])
/// let serializer = ICalendarSerializer()
/// let data = try await serializer.serialize(calendar)
/// ```
///
/// ## Topics
///
/// ### Serializing
/// - ``serialize(_:)``
/// - ``serializeToString(_:)``
public actor ICalendarSerializer {
    /// Initialize a serializer
    public init() {}

    /// Serialize iCalendar to data
    ///
    /// - Parameter calendar: Calendar to serialize
    /// - Returns: iCalendar data in UTF-8 encoding
    /// - Throws: `SwiftXDAVError.invalidData` if encoding fails
    public func serialize(_ calendar: ICalendar) async throws -> Data {
        let text = try serializeToString(calendar)
        guard let data = text.data(using: .utf8) else {
            throw SwiftXDAVError.invalidData("Failed to encode as UTF-8")
        }
        return data
    }

    /// Serialize to string
    ///
    /// - Parameter calendar: Calendar to serialize
    /// - Returns: iCalendar text
    public func serializeToString(_ calendar: ICalendar) throws -> String {
        var lines: [String] = []

        lines.append("BEGIN:VCALENDAR")
        lines.append("VERSION:\(calendar.version)")
        lines.append("PRODID:\(calendar.prodid)")
        lines.append("CALSCALE:\(calendar.calscale)")

        if let method = calendar.method {
            lines.append("METHOD:\(method)")
        }

        // Add timezones first
        for tz in calendar.timezones {
            lines.append(contentsOf: serializeVTimeZone(tz))
        }

        // Add events
        for event in calendar.events {
            lines.append(contentsOf: serializeVEvent(event))
        }

        // Add todos
        for todo in calendar.todos {
            lines.append(contentsOf: serializeVTodo(todo))
        }

        lines.append("END:VCALENDAR")

        // Fold lines and join with CRLF
        return foldLines(lines).joined(separator: "\r\n") + "\r\n"
    }

    /// Serialize VEVENT component
    private func serializeVEvent(_ event: VEvent) -> [String] {
        var lines: [String] = []

        lines.append("BEGIN:VEVENT")
        lines.append("UID:\(event.uid)")
        lines.append("DTSTAMP:\(event.dtstamp.toICalendarFormat())")

        if let dtstart = event.dtstart {
            lines.append("DTSTART:\(dtstart.toICalendarFormat())")
        }

        if let dtend = event.dtend {
            lines.append("DTEND:\(dtend.toICalendarFormat())")
        }

        if let duration = event.duration {
            lines.append("DURATION:\(formatDuration(duration))")
        }

        if let summary = event.summary {
            lines.append("SUMMARY:\(escapeText(summary))")
        }

        if let description = event.description {
            lines.append("DESCRIPTION:\(escapeText(description))")
        }

        if let location = event.location {
            lines.append("LOCATION:\(escapeText(location))")
        }

        if let status = event.status {
            lines.append("STATUS:\(status.rawValue)")
        }

        if let transparency = event.transparency {
            lines.append("TRANSP:\(transparency.rawValue)")
        }

        if let organizer = event.organizer {
            var organizerLine = "ORGANIZER"
            if let cn = organizer.commonName {
                organizerLine += ";CN=\"\(escapeText(cn))\""
            }
            organizerLine += ":mailto:\(organizer.email)"
            lines.append(organizerLine)
        }

        for attendee in event.attendees {
            var attendeeLine = "ATTENDEE"
            if let cn = attendee.commonName {
                attendeeLine += ";CN=\"\(escapeText(cn))\""
            }
            attendeeLine += ";ROLE=\(attendee.role.rawValue)"
            attendeeLine += ";PARTSTAT=\(attendee.status.rawValue)"
            if attendee.rsvp {
                attendeeLine += ";RSVP=TRUE"
            }
            attendeeLine += ":mailto:\(attendee.email)"
            lines.append(attendeeLine)
        }

        if !event.categories.isEmpty {
            lines.append("CATEGORIES:\(event.categories.joined(separator: ","))")
        }

        if event.sequence > 0 {
            lines.append("SEQUENCE:\(event.sequence)")
        }

        if let created = event.created {
            lines.append("CREATED:\(created.toICalendarFormat())")
        }

        if let lastModified = event.lastModified {
            lines.append("LAST-MODIFIED:\(lastModified.toICalendarFormat())")
        }

        if let url = event.url {
            lines.append("URL:\(url.absoluteString)")
        }

        // Serialize alarms
        for alarm in event.alarms {
            lines.append(contentsOf: serializeVAlarm(alarm))
        }

        lines.append("END:VEVENT")

        return lines
    }

    /// Serialize VTODO component
    private func serializeVTodo(_ todo: VTodo) -> [String] {
        var lines: [String] = []

        lines.append("BEGIN:VTODO")
        lines.append("UID:\(todo.uid)")
        lines.append("DTSTAMP:\(todo.dtstamp.toICalendarFormat())")

        if let dtstart = todo.dtstart {
            lines.append("DTSTART:\(dtstart.toICalendarFormat())")
        }

        if let due = todo.due {
            lines.append("DUE:\(due.toICalendarFormat())")
        }

        if let completed = todo.completed {
            lines.append("COMPLETED:\(completed.toICalendarFormat())")
        }

        if let summary = todo.summary {
            lines.append("SUMMARY:\(escapeText(summary))")
        }

        if let description = todo.description {
            lines.append("DESCRIPTION:\(escapeText(description))")
        }

        if let status = todo.status {
            lines.append("STATUS:\(status.rawValue)")
        }

        if let priority = todo.priority {
            lines.append("PRIORITY:\(priority)")
        }

        if let percentComplete = todo.percentComplete {
            lines.append("PERCENT-COMPLETE:\(percentComplete)")
        }

        lines.append("END:VTODO")

        return lines
    }

    /// Serialize VTIMEZONE component
    private func serializeVTimeZone(_ tz: VTimeZone) -> [String] {
        var lines: [String] = []

        lines.append("BEGIN:VTIMEZONE")
        lines.append("TZID:\(tz.tzid)")

        // Simplified - full timezone serialization would include STANDARD and DAYLIGHT components

        lines.append("END:VTIMEZONE")

        return lines
    }

    /// Serialize VALARM component
    private func serializeVAlarm(_ alarm: VAlarm) -> [String] {
        var lines: [String] = []

        lines.append("BEGIN:VALARM")
        lines.append("ACTION:\(alarm.action.rawValue)")

        switch alarm.trigger {
        case .relative(let interval):
            lines.append("TRIGGER:\(formatDuration(interval))")
        case .absolute(let date):
            lines.append("TRIGGER;VALUE=DATE-TIME:\(date.toICalendarFormat())")
        }

        if let duration = alarm.duration {
            lines.append("DURATION:\(formatDuration(duration))")
        }

        if let repeatCount = alarm.repeat {
            lines.append("REPEAT:\(repeatCount)")
        }

        if let description = alarm.description {
            lines.append("DESCRIPTION:\(escapeText(description))")
        }

        if let summary = alarm.summary {
            lines.append("SUMMARY:\(escapeText(summary))")
        }

        lines.append("END:VALARM")

        return lines
    }

    /// Escape text per RFC 5545
    private func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    /// Format duration as ISO 8601 duration (e.g., "PT1H30M")
    private func formatDuration(_ duration: TimeInterval) -> String {
        let isNegative = duration < 0
        let absDuration = abs(duration)

        var result = isNegative ? "-P" : "P"

        let days = Int(absDuration / 86400)
        let hours = Int((absDuration.truncatingRemainder(dividingBy: 86400)) / 3600)
        let minutes = Int((absDuration.truncatingRemainder(dividingBy: 3600)) / 60)
        let seconds = Int(absDuration.truncatingRemainder(dividingBy: 60))

        if days > 0 {
            result += "\(days)D"
        }

        if hours > 0 || minutes > 0 || seconds > 0 {
            result += "T"
            if hours > 0 {
                result += "\(hours)H"
            }
            if minutes > 0 {
                result += "\(minutes)M"
            }
            if seconds > 0 {
                result += "\(seconds)S"
            }
        }

        return result == "P" || result == "-P" ? "PT0S" : result
    }

    /// Fold long lines to max 75 octets per RFC 5545
    ///
    /// Lines longer than 75 octets are folded by inserting a CRLF followed by a space.
    private func foldLines(_ lines: [String]) -> [String] {
        lines.flatMap { line in
            // Count octets (bytes), not characters
            guard let data = line.data(using: .utf8) else {
                return [line]
            }

            if data.count <= 75 {
                return [line]
            }

            var result: [String] = []
            var remainingData = data
            var isFirstLine = true

            while !remainingData.isEmpty {
                // For first line, use 75 octets, for continuation lines use 74 (to account for leading space)
                let maxOctets = isFirstLine ? 75 : 74

                if remainingData.count <= maxOctets {
                    if let str = String(data: remainingData, encoding: .utf8) {
                        result.append(isFirstLine ? str : " \(str)")
                    }
                    break
                }

                // Find a safe split point (don't break UTF-8 sequences)
                var splitPoint = maxOctets
                while splitPoint > 0 {
                    let chunk = remainingData.prefix(splitPoint)
                    if let str = String(data: chunk, encoding: .utf8) {
                        result.append(isFirstLine ? str : " \(str)")
                        remainingData = remainingData.dropFirst(splitPoint)
                        isFirstLine = false
                        break
                    }
                    splitPoint -= 1
                }

                if splitPoint == 0 {
                    // Couldn't find a valid split point, just break here
                    break
                }
            }

            return result
        }
    }
}
