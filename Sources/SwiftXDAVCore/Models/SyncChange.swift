import Foundation

/// Represents a change in a synchronized collection
///
/// When performing a sync, the server returns a list of changes
/// that occurred since the last sync token. Each change can be
/// an addition, modification, or deletion.
public struct SyncChange: Sendable, Equatable {
    /// The type of change
    public let type: ChangeType

    /// The URL of the resource that changed
    public let url: URL

    /// The current ETag of the resource (nil for deletions)
    public let etag: String?

    /// The resource data (nil for deletions)
    public let data: Data?

    /// Initialize a sync change
    ///
    /// - Parameters:
    ///   - type: The type of change
    ///   - url: The URL of the changed resource
    ///   - etag: The current ETag (nil for deletions)
    ///   - data: The resource data (nil for deletions)
    public init(
        type: ChangeType,
        url: URL,
        etag: String?,
        data: Data?
    ) {
        self.type = type
        self.url = url
        self.etag = etag
        self.data = data
    }
}

extension SyncChange {
    /// The type of change that occurred
    public enum ChangeType: String, Sendable, Equatable, Codable {
        /// Resource was added
        case added

        /// Resource was modified
        case modified

        /// Resource was deleted
        case deleted
    }
}

extension SyncChange: CustomStringConvertible {
    public var description: String {
        "SyncChange(\(type): \(url.lastPathComponent), etag: \(etag ?? "nil"))"
    }
}
