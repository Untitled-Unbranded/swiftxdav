import Foundation
import SwiftXDAVCore

/// CalDAV-specific property definitions (RFC 4791)
///
/// These properties extend the WebDAV property set with calendar-specific properties.
///
/// ## Common CalDAV Properties
///
/// - `calendarHomeSet`: Location of the user's calendar collections
/// - `calendarDescription`: Human-readable description of a calendar
/// - `calendarTimezone`: VTIMEZONE component for the calendar
/// - `supportedCalendarComponentSet`: Which components (VEVENT, VTODO) are supported
/// - `supportedCalendarData`: Which media types are supported
/// - `maxResourceSize`: Maximum size of a calendar resource
/// - `calendarData`: Actual calendar data in REPORT responses
///
public enum CalDAVPropertyName {
    // CalDAV namespace
    public static let caldavNamespace = "urn:ietf:params:xml:ns:caldav"
    public static let calendarServerNamespace = "http://calendarserver.org/ns/"
    public static let appleNamespace = "http://apple.com/ns/ical/"

    // Calendar discovery properties
    public static let calendarHomeSet = DAVProperty(
        namespace: caldavNamespace,
        name: "calendar-home-set"
    )

    public static let calendarUserAddressSet = DAVProperty(
        namespace: caldavNamespace,
        name: "calendar-user-address-set"
    )

    // Calendar properties
    public static let calendarDescription = DAVProperty(
        namespace: caldavNamespace,
        name: "calendar-description"
    )

    public static let calendarTimezone = DAVProperty(
        namespace: caldavNamespace,
        name: "calendar-timezone"
    )

    public static let supportedCalendarComponentSet = DAVProperty(
        namespace: caldavNamespace,
        name: "supported-calendar-component-set"
    )

    public static let supportedCalendarData = DAVProperty(
        namespace: caldavNamespace,
        name: "supported-calendar-data"
    )

    public static let maxResourceSize = DAVProperty(
        namespace: caldavNamespace,
        name: "max-resource-size"
    )

    public static let minDateTime = DAVProperty(
        namespace: caldavNamespace,
        name: "min-date-time"
    )

    public static let maxDateTime = DAVProperty(
        namespace: caldavNamespace,
        name: "max-date-time"
    )

    public static let maxInstances = DAVProperty(
        namespace: caldavNamespace,
        name: "max-instances"
    )

    public static let maxAttendeesPerInstance = DAVProperty(
        namespace: caldavNamespace,
        name: "max-attendees-per-instance"
    )

    // Calendar data property (used in REPORT responses)
    public static let calendarData = DAVProperty(
        namespace: caldavNamespace,
        name: "calendar-data"
    )

    // Scheduling properties (RFC 6638)
    public static let scheduleInboxURL = DAVProperty(
        namespace: caldavNamespace,
        name: "schedule-inbox-URL"
    )

    public static let scheduleOutboxURL = DAVProperty(
        namespace: caldavNamespace,
        name: "schedule-outbox-URL"
    )

    public static let scheduleDefaultCalendarURL = DAVProperty(
        namespace: caldavNamespace,
        name: "schedule-default-calendar-URL"
    )

    // CalendarServer.org extensions (used by many servers)
    public static let getctag = DAVProperty(
        namespace: calendarServerNamespace,
        name: "getctag"
    )

    // Apple extensions
    public static let calendarColor = DAVProperty(
        namespace: appleNamespace,
        name: "calendar-color"
    )

    public static let calendarOrder = DAVProperty(
        namespace: appleNamespace,
        name: "calendar-order"
    )
}

/// CalDAV component types
public enum CalendarComponentType: String, Sendable {
    case vevent = "VEVENT"
    case vtodo = "VTODO"
    case vjournal = "VJOURNAL"
    case vfreebusy = "VFREEBUSY"
}
