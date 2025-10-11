import Foundation

/// Represents a WebDAV resource (file or collection)
///
/// A resource can be either a simple resource (like a calendar event or contact)
/// or a collection (like a calendar or address book).
///
/// ## Topics
///
/// ### Resource Properties
/// - ``url``
/// - ``etag``
/// - ``resourceType``
///
/// ### Resource Types
/// - ``ResourceType``
public protocol Resource: Sendable {
    /// The URL of this resource
    ///
    /// This is the fully qualified URL that can be used to access
    /// this resource on the server.
    var url: URL { get }

    /// The ETag for cache validation
    ///
    /// ETags are used for optimistic concurrency control and
    /// efficient synchronization. The value is `nil` if the
    /// server did not provide an ETag.
    var etag: String? { get }

    /// The type of this resource
    ///
    /// Determines whether this is a simple resource or a collection,
    /// and what kind of specialized collection it might be (calendar,
    /// address book, etc.).
    var resourceType: ResourceType { get }
}

/// The type of a WebDAV resource
///
/// Resource types distinguish between simple resources and collections,
/// and provide additional typing for CalDAV and CardDAV resources.
public enum ResourceType: Sendable, Equatable {
    /// A simple resource (file)
    case resource

    /// A generic collection (directory)
    case collection

    /// A calendar collection (CalDAV)
    case calendar

    /// An address book collection (CardDAV)
    case addressBook
}
