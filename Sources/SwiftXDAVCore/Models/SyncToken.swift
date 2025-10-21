import Foundation

/// Represents a WebDAV sync token (RFC 6578)
///
/// Sync tokens are opaque strings returned by the server that represent
/// the state of a collection at a particular point in time. They enable
/// efficient delta synchronization by allowing clients to request only
/// changes since the last sync.
///
/// ## Usage
///
/// ```swift
/// // Initial sync with no token
/// let result = try await client.sync(calendar, syncToken: nil)
///
/// // Store the new token
/// let newToken = result.syncToken
///
/// // Subsequent sync with stored token
/// let deltaResult = try await client.sync(calendar, syncToken: newToken)
/// ```
public struct SyncToken: Sendable, Equatable, Hashable {
    /// The opaque token string
    public let value: String

    /// Initialize a sync token
    ///
    /// - Parameter value: The opaque token string from the server
    public init(_ value: String) {
        self.value = value
    }
}

extension SyncToken: CustomStringConvertible {
    public var description: String {
        "SyncToken(\(value))"
    }
}

extension SyncToken: Codable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        value = try container.decode(String.self)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(value)
    }
}
