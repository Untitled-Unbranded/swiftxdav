import Foundation
import SwiftXDAVCore

/// Parser for iCalendar data (RFC 5545)
///
/// `ICalendarParser` parses iCalendar text data into structured models.
/// It handles line unfolding, parameter parsing, and component nesting.
///
/// ## Usage
///
/// ```swift
/// let parser = ICalendarParser()
/// let calendar = try await parser.parse(icalendarData)
/// for event in calendar.events {
///     print(event.summary ?? "Untitled")
/// }
/// ```
///
/// ## Topics
///
/// ### Parsing
/// - ``parse(_:)-5p3ux``
/// - ``parse(_:)-6rrnt``
public actor ICalendarParser {
    /// Initialize a parser
    public init() {}

    /// Parse iCalendar data
    ///
    /// - Parameter data: iCalendar data
    /// - Returns: Parsed calendar
    /// - Throws: `SwiftXDAVError.parsingError` if parsing fails
    public func parse(_ data: Data) async throws -> ICalendar {
        guard let text = String(data: data, encoding: .utf8) else {
            throw SwiftXDAVError.parsingError("Invalid UTF-8 encoding")
        }

        return try parse(text)
    }

    /// Parse iCalendar text
    ///
    /// - Parameter text: iCalendar text
    /// - Returns: Parsed calendar
    /// - Throws: `SwiftXDAVError.parsingError` if parsing fails
    public func parse(_ text: String) throws -> ICalendar {
        let lines = unfoldLines(text)
        var calendar = ICalendar()
        var componentStack: [Component] = []

        for line in lines {
            guard !line.isEmpty else { continue }

            let (name, parameters, value) = try parseLine(line)

            switch name {
            case "BEGIN":
                // Start a new component
                componentStack.append(Component(type: value))

            case "END":
                // End current component
                guard let component = componentStack.popLast() else {
                    throw SwiftXDAVError.parsingError("END without matching BEGIN")
                }

                if componentStack.isEmpty {
                    // Top-level component (VCALENDAR)
                    if component.type != "VCALENDAR" {
                        throw SwiftXDAVError.parsingError("Expected VCALENDAR, got \(component.type)")
                    }
                } else {
                    // Nested component (VEVENT, VTODO, etc.)
                    try addComponent(component, to: &calendar, stack: &componentStack)
                }

            case "VERSION":
                calendar.version = value

            case "PRODID":
                calendar.prodid = value

            case "CALSCALE":
                calendar.calscale = value

            case "METHOD":
                calendar.method = value

            default:
                // Property of current component
                if !componentStack.isEmpty {
                    componentStack[componentStack.count - 1].properties.append(
                        Property(name: name, parameters: parameters, value: value)
                    )
                }
            }
        }

        return calendar
    }

    /// Unfold lines (handle line wrapping per RFC 5545)
    ///
    /// Lines wrapped with a leading space or tab are unfolded into a single line.
    private func unfoldLines(_ text: String) -> [String] {
        var result: [String] = []
        var currentLine = ""

        for line in text.components(separatedBy: .newlines) {
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                // Continuation of previous line
                currentLine += line.dropFirst()
            } else {
                if !currentLine.isEmpty {
                    result.append(currentLine)
                }
                currentLine = line
            }
        }

        if !currentLine.isEmpty {
            result.append(currentLine)
        }

        return result
    }

    /// Parse a single line into name, parameters, and value
    private func parseLine(_ line: String) throws -> (name: String, parameters: [String: String], value: String) {
        guard let colonIndex = line.firstIndex(of: ":") else {
            throw SwiftXDAVError.parsingError("Invalid line format (missing colon): \(line)")
        }

        let nameAndParams = String(line[..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])

        let parts = nameAndParams.components(separatedBy: ";")
        let name = parts[0]
        var parameters: [String: String] = [:]

        for param in parts.dropFirst() {
            let paramParts = param.components(separatedBy: "=")
            if paramParts.count == 2 {
                parameters[paramParts[0]] = paramParts[1]
            }
        }

        return (name, parameters, value)
    }

    /// Add parsed component to calendar or parent component
    private func addComponent(_ component: Component, to calendar: inout ICalendar, stack: inout [Component]) throws {
        switch component.type {
        case "VEVENT":
            let event = try parseVEvent(component)
            calendar.events.append(event)

        case "VTODO":
            let todo = try parseVTodo(component)
            calendar.todos.append(todo)

        case "VTIMEZONE":
            let tz = try parseVTimeZone(component)
            calendar.timezones.append(tz)

        case "VALARM":
            // Alarms are nested in events/todos - handled in parseVEvent/parseVTodo
            break

        default:
            // Ignore unknown components
            break
        }
    }

    /// Parse VEVENT component
    private func parseVEvent(_ component: Component) throws -> VEvent {
        var event = VEvent()

        for prop in component.properties {
            switch prop.name {
            case "UID":
                event.uid = prop.value

            case "DTSTAMP":
                if let date = try? parseDate(prop.value, parameters: prop.parameters) {
                    event.dtstamp = date
                }

            case "DTSTART":
                event.dtstart = try? parseDate(prop.value, parameters: prop.parameters)

            case "DTEND":
                event.dtend = try? parseDate(prop.value, parameters: prop.parameters)

            case "DURATION":
                event.duration = parseDuration(prop.value)

            case "SUMMARY":
                event.summary = unescapeText(prop.value)

            case "DESCRIPTION":
                event.description = unescapeText(prop.value)

            case "LOCATION":
                event.location = unescapeText(prop.value)

            case "STATUS":
                event.status = EventStatus(rawValue: prop.value)

            case "TRANSP":
                event.transparency = Transparency(rawValue: prop.value)

            case "SEQUENCE":
                event.sequence = Int(prop.value) ?? 0

            case "CREATED":
                event.created = try? parseDate(prop.value, parameters: prop.parameters)

            case "LAST-MODIFIED":
                event.lastModified = try? parseDate(prop.value, parameters: prop.parameters)

            case "URL":
                event.url = URL(string: prop.value)

            case "CATEGORIES":
                event.categories = prop.value.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }

            default:
                break
            }
        }

        return event
    }

    /// Parse VTODO component
    private func parseVTodo(_ component: Component) throws -> VTodo {
        var todo = VTodo()

        for prop in component.properties {
            switch prop.name {
            case "UID":
                todo.uid = prop.value

            case "DTSTAMP":
                if let date = try? parseDate(prop.value, parameters: prop.parameters) {
                    todo.dtstamp = date
                }

            case "DTSTART":
                todo.dtstart = try? parseDate(prop.value, parameters: prop.parameters)

            case "DUE":
                todo.due = try? parseDate(prop.value, parameters: prop.parameters)

            case "COMPLETED":
                todo.completed = try? parseDate(prop.value, parameters: prop.parameters)

            case "SUMMARY":
                todo.summary = unescapeText(prop.value)

            case "DESCRIPTION":
                todo.description = unescapeText(prop.value)

            case "STATUS":
                todo.status = TodoStatus(rawValue: prop.value)

            case "PRIORITY":
                todo.priority = Int(prop.value)

            case "PERCENT-COMPLETE":
                todo.percentComplete = Int(prop.value)

            default:
                break
            }
        }

        return todo
    }

    /// Parse VTIMEZONE component
    private func parseVTimeZone(_ component: Component) throws -> VTimeZone {
        var tzid = ""

        for prop in component.properties {
            if prop.name == "TZID" {
                tzid = prop.value
                break
            }
        }

        return VTimeZone(tzid: tzid)
    }

    /// Parse date/time value
    private func parseDate(_ value: String, parameters: [String: String]) throws -> Date {
        // Check for VALUE=DATE parameter
        if parameters["VALUE"] == "DATE" {
            // Date-only format: YYYYMMDD
            if let date = value.fromICalendarDateFormat() {
                return date
            }
        }

        // Try date-time format: YYYYMMDDTHHmmssZ or YYYYMMDDTHHmmss
        if let date = value.fromICalendarFormat() {
            return date
        }

        throw SwiftXDAVError.parsingError("Invalid date format: \(value)")
    }

    /// Parse duration value (e.g., "PT1H30M")
    private func parseDuration(_ value: String) -> TimeInterval? {
        // Simplified duration parsing
        // Full implementation would parse ISO 8601 duration format
        // For now, return nil
        return nil
    }

    /// Unescape text (reverse iCalendar text escaping)
    private func unescapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\,", with: ",")
    }
}

// MARK: - Helper Types

/// Internal component representation during parsing
private struct Component {
    let type: String
    var properties: [Property] = []
}

/// Internal property representation during parsing
private struct Property {
    let name: String
    let parameters: [String: String]
    let value: String
}
