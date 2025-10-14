import Foundation

/// iCalendar VEVENT component
///
/// `VEvent` represents an event in an iCalendar, such as a meeting or appointment.
///
/// ## Topics
///
/// ### Creating Events
/// - ``init(uid:dtstamp:dtstart:dtend:duration:summary:description:location:status:transparency:organizer:attendees:rrule:exdates:rdates:alarms:categories:sequence:created:lastModified:url:)``
///
/// ### Core Properties
/// - ``uid``
/// - ``dtstamp``
/// - ``dtstart``
/// - ``dtend``
/// - ``duration``
///
/// ### Descriptive Properties
/// - ``summary``
/// - ``description``
/// - ``location``
/// - ``categories``
/// - ``url``
///
/// ### Status and Transparency
/// - ``status``
/// - ``transparency``
///
/// ### Participants
/// - ``organizer``
/// - ``attendees``
///
/// ### Recurrence
/// - ``rrule``
/// - ``exdates``
/// - ``rdates``
///
/// ### Alarms
/// - ``alarms``
///
/// ### Metadata
/// - ``sequence``
/// - ``created``
/// - ``lastModified``
public struct VEvent: Sendable, Equatable {
    /// Unique identifier for this event
    public var uid: String

    /// Date/time stamp when this event was created or last modified
    public var dtstamp: Date

    /// Start date/time of the event
    public var dtstart: Date?

    /// End date/time of the event
    public var dtend: Date?

    /// Duration of the event (alternative to dtend)
    public var duration: TimeInterval?

    /// Short summary or subject of the event
    public var summary: String?

    /// Detailed description of the event
    public var description: String?

    /// Location of the event
    public var location: String?

    /// Event status (tentative, confirmed, cancelled)
    public var status: EventStatus?

    /// Time transparency (opaque or transparent)
    public var transparency: Transparency?

    /// Organizer of the event
    public var organizer: Organizer?

    /// Attendees of the event
    public var attendees: [Attendee]

    /// Recurrence rule
    public var rrule: RecurrenceRule?

    /// Exception dates (dates to exclude from recurrence)
    public var exdates: [Date]

    /// Recurrence dates (additional dates to include)
    public var rdates: [Date]

    /// Alarms for this event
    public var alarms: [VAlarm]

    /// Categories or tags
    public var categories: [String]

    /// Sequence number for updates
    public var sequence: Int

    /// Date/time when this event was created
    public var created: Date?

    /// Date/time when this event was last modified
    public var lastModified: Date?

    /// URL associated with this event
    public var url: URL?

    /// Initialize a VEVENT
    ///
    /// - Parameters:
    ///   - uid: Unique identifier (defaults to new UUID)
    ///   - dtstamp: Date/time stamp (defaults to current date)
    ///   - dtstart: Start date/time
    ///   - dtend: End date/time
    ///   - duration: Duration (alternative to dtend)
    ///   - summary: Event summary
    ///   - description: Event description
    ///   - location: Event location
    ///   - status: Event status
    ///   - transparency: Time transparency
    ///   - organizer: Event organizer
    ///   - attendees: Event attendees
    ///   - rrule: Recurrence rule
    ///   - exdates: Exception dates
    ///   - rdates: Recurrence dates
    ///   - alarms: Event alarms
    ///   - categories: Event categories
    ///   - sequence: Sequence number
    ///   - created: Creation date
    ///   - lastModified: Last modification date
    ///   - url: Associated URL
    public init(
        uid: String = UUID().uuidString,
        dtstamp: Date = Date(),
        dtstart: Date? = nil,
        dtend: Date? = nil,
        duration: TimeInterval? = nil,
        summary: String? = nil,
        description: String? = nil,
        location: String? = nil,
        status: EventStatus? = nil,
        transparency: Transparency? = nil,
        organizer: Organizer? = nil,
        attendees: [Attendee] = [],
        rrule: RecurrenceRule? = nil,
        exdates: [Date] = [],
        rdates: [Date] = [],
        alarms: [VAlarm] = [],
        categories: [String] = [],
        sequence: Int = 0,
        created: Date? = nil,
        lastModified: Date? = nil,
        url: URL? = nil
    ) {
        self.uid = uid
        self.dtstamp = dtstamp
        self.dtstart = dtstart
        self.dtend = dtend
        self.duration = duration
        self.summary = summary
        self.description = description
        self.location = location
        self.status = status
        self.transparency = transparency
        self.organizer = organizer
        self.attendees = attendees
        self.rrule = rrule
        self.exdates = exdates
        self.rdates = rdates
        self.alarms = alarms
        self.categories = categories
        self.sequence = sequence
        self.created = created
        self.lastModified = lastModified
        self.url = url
    }
}

/// Event status values
public enum EventStatus: String, Sendable, Equatable {
    /// Event is tentative
    case tentative = "TENTATIVE"

    /// Event is confirmed
    case confirmed = "CONFIRMED"

    /// Event is cancelled
    case cancelled = "CANCELLED"
}

/// Time transparency values
public enum Transparency: String, Sendable, Equatable {
    /// Time is opaque (blocks time)
    case opaque = "OPAQUE"

    /// Time is transparent (doesn't block time)
    case transparent = "TRANSPARENT"
}

/// Event organizer
public struct Organizer: Sendable, Equatable {
    /// Email address of the organizer
    public var email: String

    /// Common name (display name) of the organizer
    public var commonName: String?

    /// Initialize an organizer
    ///
    /// - Parameters:
    ///   - email: Email address
    ///   - commonName: Display name
    public init(email: String, commonName: String? = nil) {
        self.email = email
        self.commonName = commonName
    }
}

/// Event attendee
public struct Attendee: Sendable, Equatable {
    /// Email address of the attendee
    public var email: String

    /// Common name (display name) of the attendee
    public var commonName: String?

    /// Role of the attendee
    public var role: AttendeeRole

    /// Participation status
    public var status: ParticipationStatus

    /// Whether RSVP is requested
    public var rsvp: Bool

    /// Initialize an attendee
    ///
    /// - Parameters:
    ///   - email: Email address
    ///   - commonName: Display name
    ///   - role: Attendee role
    ///   - status: Participation status
    ///   - rsvp: Whether RSVP is requested
    public init(
        email: String,
        commonName: String? = nil,
        role: AttendeeRole = .reqParticipant,
        status: ParticipationStatus = .needsAction,
        rsvp: Bool = false
    ) {
        self.email = email
        self.commonName = commonName
        self.role = role
        self.status = status
        self.rsvp = rsvp
    }
}

/// Attendee role values
public enum AttendeeRole: String, Sendable, Equatable {
    /// Chair (meeting organizer)
    case chair = "CHAIR"

    /// Required participant
    case reqParticipant = "REQ-PARTICIPANT"

    /// Optional participant
    case optParticipant = "OPT-PARTICIPANT"

    /// Non-participant (informational)
    case nonParticipant = "NON-PARTICIPANT"
}

/// Participation status values
public enum ParticipationStatus: String, Sendable, Equatable {
    /// Needs action (no response yet)
    case needsAction = "NEEDS-ACTION"

    /// Accepted
    case accepted = "ACCEPTED"

    /// Declined
    case declined = "DECLINED"

    /// Tentatively accepted
    case tentative = "TENTATIVE"

    /// Delegated to another attendee
    case delegated = "DELEGATED"
}
