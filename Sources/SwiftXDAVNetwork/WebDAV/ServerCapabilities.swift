import Foundation
import SwiftXDAVCore

/// Server type identification
///
/// Represents the type of CalDAV/CardDAV server detected.
public enum ServerType: String, Sendable, Equatable {
    /// Apple iCloud
    case iCloud = "iCloud"

    /// Google Calendar/Contacts
    case google = "Google"

    /// Nextcloud
    case nextcloud = "Nextcloud"

    /// ownCloud
    case ownCloud = "ownCloud"

    /// SOGo
    case sogo = "SOGo"

    /// Radicale
    case radicale = "Radicale"

    /// Baikal
    case baikal = "Baikal"

    /// Synology Calendar
    case synology = "Synology"

    /// Generic/Unknown DAV server
    case generic = "Generic"
}

/// Server capabilities discovered from OPTIONS and PROPFIND
///
/// Represents the features and capabilities supported by a CalDAV/CardDAV server.
///
/// ## Usage
///
/// ```swift
/// let detector = ServerDetector(httpClient: client)
/// let capabilities = try await detector.detectCapabilities(baseURL: url)
///
/// if capabilities.supportsCalDAV {
///     print("Server supports CalDAV")
/// }
///
/// if capabilities.supportsSyncCollection {
///     print("Server supports efficient sync with sync-tokens")
/// }
/// ```
public struct ServerCapabilities: Sendable, Equatable {
    /// The detected server type
    public let serverType: ServerType

    /// Server product name (from Server header or User-Agent)
    public let serverName: String?

    /// Server version
    public let serverVersion: String?

    /// Supported DAV compliance classes
    public let davCompliance: [String]

    /// Whether the server supports CalDAV
    public let supportsCalDAV: Bool

    /// Whether the server supports CardDAV
    public let supportsCardDAV: Bool

    /// Whether the server supports sync-collection (RFC 6578)
    public let supportsSyncCollection: Bool

    /// Whether the server supports calendar-query REPORT
    public let supportsCalendarQuery: Bool

    /// Whether the server supports addressbook-query REPORT
    public let supportsAddressbookQuery: Bool

    /// Whether the server supports scheduling extensions (RFC 6638)
    public let supportsScheduling: Bool

    /// Whether the server supports calendar-proxy
    public let supportsCalendarProxy: Bool

    /// Maximum resource size (if advertised)
    public let maxResourceSize: Int?

    /// Supported HTTP methods
    public let supportedMethods: Set<String>

    /// Additional server-specific properties
    public let customProperties: [String: String]

    public init(
        serverType: ServerType = .generic,
        serverName: String? = nil,
        serverVersion: String? = nil,
        davCompliance: [String] = [],
        supportsCalDAV: Bool = false,
        supportsCardDAV: Bool = false,
        supportsSyncCollection: Bool = false,
        supportsCalendarQuery: Bool = false,
        supportsAddressbookQuery: Bool = false,
        supportsScheduling: Bool = false,
        supportsCalendarProxy: Bool = false,
        maxResourceSize: Int? = nil,
        supportedMethods: Set<String> = [],
        customProperties: [String: String] = [:]
    ) {
        self.serverType = serverType
        self.serverName = serverName
        self.serverVersion = serverVersion
        self.davCompliance = davCompliance
        self.supportsCalDAV = supportsCalDAV
        self.supportsCardDAV = supportsCardDAV
        self.supportsSyncCollection = supportsSyncCollection
        self.supportsCalendarQuery = supportsCalendarQuery
        self.supportsAddressbookQuery = supportsAddressbookQuery
        self.supportsScheduling = supportsScheduling
        self.supportsCalendarProxy = supportsCalendarProxy
        self.maxResourceSize = maxResourceSize
        self.supportedMethods = supportedMethods
        self.customProperties = customProperties
    }
}

// MARK: - CustomStringConvertible

extension ServerCapabilities: CustomStringConvertible {
    public var description: String {
        var parts: [String] = []
        parts.append("ServerCapabilities(")
        parts.append("  type: \(serverType.rawValue)")

        if let name = serverName {
            parts.append("  name: \(name)")
        }

        if let version = serverVersion {
            parts.append("  version: \(version)")
        }

        parts.append("  CalDAV: \(supportsCalDAV)")
        parts.append("  CardDAV: \(supportsCardDAV)")
        parts.append("  sync-collection: \(supportsSyncCollection)")
        parts.append("  scheduling: \(supportsScheduling)")

        if !davCompliance.isEmpty {
            parts.append("  DAV compliance: \(davCompliance.joined(separator: ", "))")
        }

        parts.append(")")

        return parts.joined(separator: "\n")
    }
}
