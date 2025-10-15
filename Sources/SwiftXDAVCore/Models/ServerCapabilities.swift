import Foundation

/// Detected server type
public enum ServerType: String, Sendable, Equatable {
    case iCloud = "iCloud"
    case google = "Google"
    case nextcloud = "Nextcloud"
    case radicale = "Radicale"
    case sogo = "SOGo"
    case baikal = "Baikal"
    case generic = "Generic"
}

/// Server capabilities discovered via OPTIONS and PROPFIND
///
/// This structure tracks which features a CalDAV/CardDAV server supports,
/// allowing the client to adapt its behavior accordingly.
///
/// ## Usage
///
/// ```swift
/// let capabilities = try await ServerCapabilities.detect(
///     url: serverURL,
///     httpClient: client
/// )
///
/// if capabilities.supportsCalDAV {
///     // Use CalDAV features
/// }
///
/// if capabilities.supportsSyncToken {
///     // Use efficient sync-token based synchronization
/// }
/// ```
public struct ServerCapabilities: Sendable, Equatable {
    /// Type of server detected
    public let serverType: ServerType

    /// Server product name from DAV header
    public let serverProduct: String?

    /// Supports CalDAV (RFC 4791)
    public let supportsCalDAV: Bool

    /// Supports CardDAV (RFC 6352)
    public let supportsCardDAV: Bool

    /// Supports WebDAV Sync (RFC 6578)
    public let supportsSyncToken: Bool

    /// Supports CalDAV scheduling extensions (RFC 6638)
    public let supportsScheduling: Bool

    /// Supports extended MKCOL (RFC 5689)
    public let supportsExtendedMKCOL: Bool

    /// Supported DAV compliance classes
    public let davClasses: [String]

    /// Apple calendar extensions (calendar-color, calendar-order)
    public let supportsAppleExtensions: Bool

    /// CalendarServer.org extensions (getctag)
    public let supportsCalendarServerExtensions: Bool

    /// Initialize server capabilities
    ///
    /// - Parameters:
    ///   - serverType: Detected server type
    ///   - serverProduct: Server product name
    ///   - supportsCalDAV: Whether server supports CalDAV
    ///   - supportsCardDAV: Whether server supports CardDAV
    ///   - supportsSyncToken: Whether server supports sync tokens
    ///   - supportsScheduling: Whether server supports scheduling
    ///   - supportsExtendedMKCOL: Whether server supports extended MKCOL
    ///   - davClasses: DAV compliance classes
    ///   - supportsAppleExtensions: Whether Apple extensions are supported
    ///   - supportsCalendarServerExtensions: Whether CalendarServer extensions are supported
    public init(
        serverType: ServerType = .generic,
        serverProduct: String? = nil,
        supportsCalDAV: Bool = false,
        supportsCardDAV: Bool = false,
        supportsSyncToken: Bool = false,
        supportsScheduling: Bool = false,
        supportsExtendedMKCOL: Bool = false,
        davClasses: [String] = [],
        supportsAppleExtensions: Bool = false,
        supportsCalendarServerExtensions: Bool = false
    ) {
        self.serverType = serverType
        self.serverProduct = serverProduct
        self.supportsCalDAV = supportsCalDAV
        self.supportsCardDAV = supportsCardDAV
        self.supportsSyncToken = supportsSyncToken
        self.supportsScheduling = supportsScheduling
        self.supportsExtendedMKCOL = supportsExtendedMKCOL
        self.davClasses = davClasses
        self.supportsAppleExtensions = supportsAppleExtensions
        self.supportsCalendarServerExtensions = supportsCalendarServerExtensions
    }

    /// Detect server type based on URL and server headers
    ///
    /// - Parameters:
    ///   - url: Base URL of the server
    ///   - serverProduct: Server product string from headers
    /// - Returns: Detected server type
    public static func detectServerType(from url: URL, serverProduct: String?) -> ServerType {
        let host = url.host?.lowercased() ?? ""

        // Check URL patterns
        if host.contains("icloud.com") {
            return .iCloud
        } else if host.contains("google.com") || host.contains("googleapis.com") || host.contains("googleusercontent.com") {
            return .google
        } else if host.contains("nextcloud") {
            return .nextcloud
        }

        // Check server product string
        if let product = serverProduct?.lowercased() {
            if product.contains("nextcloud") {
                return .nextcloud
            } else if product.contains("radicale") {
                return .radicale
            } else if product.contains("sogo") {
                return .sogo
            } else if product.contains("baikal") || product.contains("sabre") {
                return .baikal
            }
        }

        return .generic
    }

    /// Parse DAV capabilities from OPTIONS response
    ///
    /// - Parameter davHeader: Value of DAV header from OPTIONS response
    /// - Returns: Array of DAV compliance classes
    public static func parseDavClasses(from davHeader: String) -> [String] {
        davHeader
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Check if a specific DAV class is supported
    ///
    /// - Parameter davClass: DAV class to check (e.g., "1", "2", "calendar-access")
    /// - Returns: True if the class is supported
    public func supportsDavClass(_ davClass: String) -> Bool {
        davClasses.contains(davClass)
    }
}
