import Foundation

/// Represents a WebDAV property
///
/// WebDAV properties are name-value pairs associated with resources.
/// Each property has a namespace (usually a URI), a name, and an optional value.
///
/// Properties are used extensively in WebDAV, CalDAV, and CardDAV protocols
/// to store metadata about resources.
///
/// ## Topics
///
/// ### Creating Properties
/// - ``init(namespace:name:value:)``
///
/// ### Property Components
/// - ``namespace``
/// - ``name``
/// - ``value``
///
/// ### Standard Properties
/// - ``DAVPropertyName``
///
/// ## Example
///
/// ```swift
/// let displayName = DAVProperty(
///     namespace: "DAV:",
///     name: "displayname",
///     value: "My Calendar"
/// )
/// ```
public struct DAVProperty: Sendable, Equatable, Hashable {
    /// The XML namespace of the property
    ///
    /// Common namespaces include:
    /// - `DAV:` for WebDAV properties
    /// - `urn:ietf:params:xml:ns:caldav` for CalDAV properties
    /// - `urn:ietf:params:xml:ns:carddav` for CardDAV properties
    public let namespace: String

    /// The property name
    public let name: String

    /// The property value
    ///
    /// This is `nil` when requesting properties (PROPFIND) or when
    /// the property has no value.
    public let value: String?

    /// Creates a new WebDAV property
    ///
    /// - Parameters:
    ///   - namespace: The XML namespace of the property
    ///   - name: The property name
    ///   - value: The property value (optional)
    public init(namespace: String, name: String, value: String? = nil) {
        self.namespace = namespace
        self.name = name
        self.value = value
    }
}

/// Common WebDAV property names
///
/// This type provides convenient access to standard WebDAV properties
/// defined in RFC 4918 and related specifications.
///
/// ## Topics
///
/// ### Resource Properties
/// - ``resourceType``
/// - ``displayName``
/// - ``getContentType``
/// - ``getContentLength``
///
/// ### Metadata Properties
/// - ``getETag``
/// - ``getLastModified``
/// - ``creationDate``
///
/// ### Access Control Properties
/// - ``currentUserPrincipal``
/// - ``supportedLock``
public enum DAVPropertyName {
    /// The type of the resource (collection vs. resource)
    ///
    /// Namespace: `DAV:`
    public static let resourceType = DAVProperty(namespace: "DAV:", name: "resourcetype")

    /// The display name of the resource
    ///
    /// Namespace: `DAV:`
    public static let displayName = DAVProperty(namespace: "DAV:", name: "displayname")

    /// The ETag of the resource
    ///
    /// ETags are used for cache validation and optimistic concurrency control.
    ///
    /// Namespace: `DAV:`
    public static let getETag = DAVProperty(namespace: "DAV:", name: "getetag")

    /// The content type of the resource
    ///
    /// Namespace: `DAV:`
    public static let getContentType = DAVProperty(namespace: "DAV:", name: "getcontenttype")

    /// The last modified date of the resource
    ///
    /// Namespace: `DAV:`
    public static let getLastModified = DAVProperty(namespace: "DAV:", name: "getlastmodified")

    /// The creation date of the resource
    ///
    /// Namespace: `DAV:`
    public static let creationDate = DAVProperty(namespace: "DAV:", name: "creationdate")

    /// The content length (size) of the resource
    ///
    /// Namespace: `DAV:`
    public static let getContentLength = DAVProperty(namespace: "DAV:", name: "getcontentlength")

    /// The current user's principal URL
    ///
    /// Used in WebDAV/CalDAV/CardDAV to discover the authenticated user's principal.
    ///
    /// Namespace: `DAV:`
    public static let currentUserPrincipal = DAVProperty(namespace: "DAV:", name: "current-user-principal")

    /// The lock support for the resource
    ///
    /// Namespace: `DAV:`
    public static let supportedLock = DAVProperty(namespace: "DAV:", name: "supportedlock")
}

/// CalDAV-specific property names
///
/// Properties specific to CalDAV (RFC 4791).
public enum CalDAVPropertyName {
    /// The calendar home set URL
    ///
    /// Namespace: `urn:ietf:params:xml:ns:caldav`
    public static let calendarHomeSet = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:caldav",
        name: "calendar-home-set"
    )

    /// The supported calendar component types (VEVENT, VTODO, etc.)
    ///
    /// Namespace: `urn:ietf:params:xml:ns:caldav`
    public static let supportedCalendarComponentSet = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:caldav",
        name: "supported-calendar-component-set"
    )

    /// The calendar data property
    ///
    /// Used in REPORT responses to return iCalendar data.
    ///
    /// Namespace: `urn:ietf:params:xml:ns:caldav`
    public static let calendarData = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:caldav",
        name: "calendar-data"
    )

    /// The calendar description
    ///
    /// Namespace: `urn:ietf:params:xml:ns:caldav`
    public static let calendarDescription = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:caldav",
        name: "calendar-description"
    )

    /// The calendar timezone
    ///
    /// Namespace: `urn:ietf:params:xml:ns:caldav`
    public static let calendarTimezone = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:caldav",
        name: "calendar-timezone"
    )
}

/// CardDAV-specific property names
///
/// Properties specific to CardDAV (RFC 6352).
public enum CardDAVPropertyName {
    /// The address book home set URL
    ///
    /// Namespace: `urn:ietf:params:xml:ns:carddav`
    public static let addressbookHomeSet = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:carddav",
        name: "addressbook-home-set"
    )

    /// The address book data property
    ///
    /// Used in REPORT responses to return vCard data.
    ///
    /// Namespace: `urn:ietf:params:xml:ns:carddav`
    public static let addressData = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:carddav",
        name: "address-data"
    )

    /// The address book description
    ///
    /// Namespace: `urn:ietf:params:xml:ns:carddav`
    public static let addressbookDescription = DAVProperty(
        namespace: "urn:ietf:params:xml:ns:carddav",
        name: "addressbook-description"
    )
}

/// Apple/iCloud-specific property names
///
/// Properties used by Apple's CalDAV/CardDAV servers.
public enum ApplePropertyName {
    /// The collection tag (ctag) for efficient sync
    ///
    /// CTags change when any resource in a collection changes,
    /// enabling efficient sync detection.
    ///
    /// Namespace: `http://calendarserver.org/ns/`
    public static let getctag = DAVProperty(
        namespace: "http://calendarserver.org/ns/",
        name: "getctag"
    )

    /// The calendar color
    ///
    /// Namespace: `http://apple.com/ns/ical/`
    public static let calendarColor = DAVProperty(
        namespace: "http://apple.com/ns/ical/",
        name: "calendar-color"
    )

    /// The calendar order (for sorting)
    ///
    /// Namespace: `http://apple.com/ns/ical/`
    public static let calendarOrder = DAVProperty(
        namespace: "http://apple.com/ns/ical/",
        name: "calendar-order"
    )
}
