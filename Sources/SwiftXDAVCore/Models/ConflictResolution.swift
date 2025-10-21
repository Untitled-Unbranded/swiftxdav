import Foundation

/// Represents a conflict between local and remote versions of a resource
///
/// Conflicts occur when a resource is modified both locally and remotely
/// since the last successful sync. The client must decide how to resolve
/// such conflicts.
public struct SyncConflict: Sendable, Equatable {
    /// The URL of the conflicting resource
    public let url: URL

    /// The local version of the resource
    public let localVersion: ConflictVersion

    /// The remote version of the resource
    public let remoteVersion: ConflictVersion

    /// Initialize a sync conflict
    ///
    /// - Parameters:
    ///   - url: The URL of the conflicting resource
    ///   - localVersion: The local version
    ///   - remoteVersion: The remote version
    public init(
        url: URL,
        localVersion: ConflictVersion,
        remoteVersion: ConflictVersion
    ) {
        self.url = url
        self.localVersion = localVersion
        self.remoteVersion = remoteVersion
    }
}

/// Represents a version of a resource in a conflict
public struct ConflictVersion: Sendable, Equatable {
    /// The ETag of this version
    public let etag: String

    /// The resource data
    public let data: Data

    /// When this version was last modified (if known)
    public let lastModified: Date?

    /// Initialize a conflict version
    ///
    /// - Parameters:
    ///   - etag: The ETag of this version
    ///   - data: The resource data
    ///   - lastModified: When this version was last modified
    public init(etag: String, data: Data, lastModified: Date? = nil) {
        self.etag = etag
        self.data = data
        self.lastModified = lastModified
    }
}

/// Strategy for resolving conflicts during synchronization
///
/// When a resource is modified both locally and remotely, the client
/// must decide which version to keep or whether to merge them.
public enum ConflictResolutionStrategy: Sendable, Equatable {
    /// Use the local version (discard remote changes)
    ///
    /// The local version will be uploaded to the server, overwriting
    /// the remote version. Use with caution as remote changes are lost.
    case useLocal

    /// Use the remote version (discard local changes)
    ///
    /// The remote version will overwrite the local version. Local
    /// changes since the last sync are lost.
    case useRemote

    /// Use the most recently modified version
    ///
    /// Compares the last-modified timestamps and keeps the newer version.
    /// If timestamps are unavailable, falls back to `useRemote`.
    case useNewest

    /// Create a duplicate (keep both versions)
    ///
    /// Both versions are kept. The local version is renamed (e.g., by
    /// appending " (conflict)" to the title) and uploaded as a new resource.
    case createDuplicate

    /// Merge the versions (custom merge logic required)
    ///
    /// A custom merge function is called to combine the two versions.
    /// This is useful for application-specific merge logic.
    case merge(@Sendable (SyncConflict) async throws -> Data)

    /// Fail the sync operation
    ///
    /// The sync operation fails and the conflict is reported to the caller.
    /// The application must manually resolve the conflict.
    case fail
}

extension ConflictResolutionStrategy {
    /// Check equality (merge functions are considered equal)
    public static func == (lhs: ConflictResolutionStrategy, rhs: ConflictResolutionStrategy) -> Bool {
        switch (lhs, rhs) {
        case (.useLocal, .useLocal),
             (.useRemote, .useRemote),
             (.useNewest, .useNewest),
             (.createDuplicate, .createDuplicate),
             (.merge, .merge),
             (.fail, .fail):
            return true
        default:
            return false
        }
    }
}

/// Options for synchronization operations
public struct SyncOptions: Sendable {
    /// How to resolve conflicts when they occur
    public let conflictResolution: ConflictResolutionStrategy

    /// Whether to validate ETags before uploading changes
    ///
    /// When true, uses If-Match headers to ensure the server version
    /// hasn't changed before uploading. When false, uploads directly
    /// (may cause conflicts).
    public let validateETags: Bool

    /// Whether to fetch full resource data or just metadata
    ///
    /// When true, fetches complete iCalendar/vCard data for each change.
    /// When false, only fetches ETags and URLs (faster but incomplete).
    public let fetchFullData: Bool

    /// Initialize sync options
    ///
    /// - Parameters:
    ///   - conflictResolution: How to resolve conflicts
    ///   - validateETags: Whether to validate ETags
    ///   - fetchFullData: Whether to fetch full resource data
    public init(
        conflictResolution: ConflictResolutionStrategy = .useRemote,
        validateETags: Bool = true,
        fetchFullData: Bool = true
    ) {
        self.conflictResolution = conflictResolution
        self.validateETags = validateETags
        self.fetchFullData = fetchFullData
    }
}

extension SyncOptions {
    /// Default sync options (use remote, validate ETags, fetch full data)
    public static let `default` = SyncOptions()

    /// Fast sync options (don't fetch full data, useful for checking if changes exist)
    public static let fast = SyncOptions(fetchFullData: false)

    /// Safe sync options (fail on conflicts, validate all ETags)
    public static let safe = SyncOptions(conflictResolution: .fail, validateETags: true)
}
