import Foundation

/// Represents the result of a synchronization operation
///
/// Contains all changes detected during a sync, along with the
/// new sync token to use for the next sync operation.
///
/// ## Usage
///
/// ```swift
/// let result = try await client.sync(calendar, syncToken: lastToken)
///
/// // Process changes
/// for change in result.changes {
///     switch change.type {
///     case .added, .modified:
///         // Update local database
///         break
///     case .deleted:
///         // Remove from local database
///         break
///     }
/// }
///
/// // Save new token for next sync
/// saveToken(result.newSyncToken)
/// ```
public struct SyncResult: Sendable, Equatable {
    /// The new sync token to use for the next sync
    ///
    /// This token represents the state of the collection after
    /// all changes in this result have been applied.
    public let newSyncToken: SyncToken

    /// All changes detected since the last sync
    public let changes: [SyncChange]

    /// Whether this was an initial sync (no previous token)
    public let isInitialSync: Bool

    /// Initialize a sync result
    ///
    /// - Parameters:
    ///   - newSyncToken: The new sync token for the next sync
    ///   - changes: All changes detected
    ///   - isInitialSync: Whether this was an initial sync
    public init(
        newSyncToken: SyncToken,
        changes: [SyncChange],
        isInitialSync: Bool = false
    ) {
        self.newSyncToken = newSyncToken
        self.changes = changes
        self.isInitialSync = isInitialSync
    }
}

extension SyncResult {
    /// The number of additions in this sync
    public var addedCount: Int {
        changes.filter { $0.type == .added }.count
    }

    /// The number of modifications in this sync
    public var modifiedCount: Int {
        changes.filter { $0.type == .modified }.count
    }

    /// The number of deletions in this sync
    public var deletedCount: Int {
        changes.filter { $0.type == .deleted }.count
    }

    /// Whether there are any changes
    public var hasChanges: Bool {
        !changes.isEmpty
    }
}

extension SyncResult: CustomStringConvertible {
    public var description: String {
        """
        SyncResult(
            token: \(newSyncToken.value),
            changes: \(changes.count) (\(addedCount) added, \(modifiedCount) modified, \(deletedCount) deleted),
            initial: \(isInitialSync)
        )
        """
    }
}
