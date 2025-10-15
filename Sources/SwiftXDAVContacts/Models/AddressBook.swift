import Foundation

/// A CardDAV address book collection
///
/// Represents an address book collection on a CardDAV server. Each address book
/// can contain contacts (vCards).
///
/// ## Usage
///
/// ```swift
/// let client = CardDAVClient.iCloud(username: "user@icloud.com", appSpecificPassword: "xxxx-xxxx-xxxx-xxxx")
/// let addressBooks = try await client.listAddressBooks()
/// for addressBook in addressBooks {
///     print("\(addressBook.displayName): \(addressBook.url)")
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
/// - ``color``
public struct AddressBook: Sendable, Equatable, Identifiable {
    /// Unique identifier (derived from URL)
    public var id: String {
        url.absoluteString
    }

    /// The URL of this address book collection
    public let url: URL

    /// Human-readable name of the address book
    public let displayName: String

    /// Optional description of the address book
    public let description: String?

    /// Collection tag (ctag) for efficient sync
    ///
    /// The ctag changes whenever any resource in the collection changes.
    /// Useful for determining if a sync is needed.
    public let ctag: String?

    /// ETag for the address book resource itself
    public let etag: String?

    /// Address book color (Apple extension)
    public let color: String?

    /// Supported vCard versions
    public let supportedVersions: [VCardVersion]

    /// Initialize an address book
    ///
    /// - Parameters:
    ///   - url: The URL of the address book collection
    ///   - displayName: Human-readable name
    ///   - description: Optional description
    ///   - ctag: Collection tag for sync
    ///   - etag: Entity tag
    ///   - color: Address book color (hex format)
    ///   - supportedVersions: Supported vCard versions
    public init(
        url: URL,
        displayName: String,
        description: String? = nil,
        ctag: String? = nil,
        etag: String? = nil,
        color: String? = nil,
        supportedVersions: [VCardVersion] = [.v3_0, .v4_0]
    ) {
        self.url = url
        self.displayName = displayName
        self.description = description
        self.ctag = ctag
        self.etag = etag
        self.color = color
        self.supportedVersions = supportedVersions
    }
}
