import Foundation

/// A CalDAV calendar collection
///
/// Represents a calendar collection on a CalDAV server. Each calendar can contain
/// events, todos, or other calendar components.
///
/// ## Usage
///
/// ```swift
/// let client = CalDAVClient.iCloud(username: "user@icloud.com", appSpecificPassword: "xxxx-xxxx-xxxx-xxxx")
/// let calendars = try await client.listCalendars()
/// for calendar in calendars {
///     print("\(calendar.displayName): \(calendar.url)")
/// }
/// ```
///
/// ## Topics
///
/// ### Properties
/// - ``url``
/// - ``displayName``
/// - ``description``
/// - ``ctag``
/// - ``supportedComponents``
/// - ``color``
/// - ``order``
public struct Calendar: Sendable, Equatable, Identifiable {
    /// Unique identifier (derived from URL)
    public var id: String {
        url.absoluteString
    }

    /// The URL of this calendar collection
    public let url: URL

    /// Human-readable name of the calendar
    public let displayName: String

    /// Optional description of the calendar
    public let description: String?

    /// Collection tag (ctag) for efficient sync
    ///
    /// The ctag changes whenever any resource in the collection changes.
    /// Useful for determining if a sync is needed.
    public let ctag: String?

    /// ETag for the calendar resource itself
    public let etag: String?

    /// Supported calendar component types (VEVENT, VTODO, etc.)
    public let supportedComponents: [CalendarComponentType]

    /// Calendar color (Apple extension)
    public let color: String?

    /// Calendar display order (Apple extension)
    public let order: Int?

    /// Initialize a calendar
    ///
    /// - Parameters:
    ///   - url: The URL of the calendar collection
    ///   - displayName: Human-readable name
    ///   - description: Optional description
    ///   - ctag: Collection tag for sync
    ///   - etag: Entity tag
    ///   - supportedComponents: Supported component types
    ///   - color: Calendar color (hex format)
    ///   - order: Display order
    public init(
        url: URL,
        displayName: String,
        description: String? = nil,
        ctag: String? = nil,
        etag: String? = nil,
        supportedComponents: [CalendarComponentType] = [.vevent],
        color: String? = nil,
        order: Int? = nil
    ) {
        self.url = url
        self.displayName = displayName
        self.description = description
        self.ctag = ctag
        self.etag = etag
        self.supportedComponents = supportedComponents
        self.color = color
        self.order = order
    }

    /// Check if this calendar supports events
    public var supportsEvents: Bool {
        supportedComponents.contains(.vevent)
    }

    /// Check if this calendar supports todos
    public var supportsTodos: Bool {
        supportedComponents.contains(.vtodo)
    }
}
