import Foundation
import SwiftXDAVCore

/// Server detection and capability discovery
///
/// Detects server type and capabilities using OPTIONS and PROPFIND requests.
///
/// ## Usage
///
/// ```swift
/// let detector = ServerDetector(httpClient: client)
/// let capabilities = try await detector.detectCapabilities(baseURL: serverURL)
///
/// switch capabilities.serverType {
/// case .iCloud:
///     print("Using iCloud - requires app-specific password")
/// case .google:
///     print("Using Google - requires OAuth 2.0")
/// case .nextcloud:
///     print("Using Nextcloud - self-hosted")
/// default:
///     print("Generic CalDAV/CardDAV server")
/// }
/// ```
///
/// ## Topics
///
/// ### Initialization
/// - ``init(httpClient:)``
///
/// ### Detection
/// - ``detectCapabilities(baseURL:)``
/// - ``detectServerType(from:)``
public actor ServerDetector {
    // MARK: - Properties

    private let httpClient: HTTPClient

    // MARK: - Initialization

    /// Create a server detector
    ///
    /// - Parameter httpClient: The HTTP client to use for detection requests
    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    // MARK: - Public Methods

    /// Detect server capabilities
    ///
    /// Performs OPTIONS and PROPFIND requests to discover what features the server supports.
    ///
    /// - Parameter baseURL: The base URL of the server
    /// - Returns: Server capabilities
    /// - Throws: ``SwiftXDAVError`` if detection fails
    public func detectCapabilities(baseURL: URL) async throws -> ServerCapabilities {
        // Execute OPTIONS request
        let optionsResponse = try await httpClient.request(
            .options,
            url: baseURL,
            headers: nil,
            body: nil
        )

        // Parse headers
        let davHeader = optionsResponse.headers["DAV"] ?? optionsResponse.headers["dav"] ?? ""
        let allowHeader = optionsResponse.headers["Allow"] ?? optionsResponse.headers["allow"] ?? ""
        let serverHeader = optionsResponse.headers["Server"] ?? optionsResponse.headers["server"] ?? ""

        // Parse DAV compliance classes
        let davCompliance = davHeader
            .components(separatedBy: ",")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Parse allowed methods
        let supportedMethods = Set(
            allowHeader
                .components(separatedBy: ",")
                .map { $0.trimmingCharacters(in: .whitespaces).uppercased() }
                .filter { !$0.isEmpty }
        )

        // Detect server type
        let serverType = detectServerType(from: serverHeader, baseURL: baseURL)

        // Parse server name and version
        let (serverName, serverVersion) = parseServerHeader(serverHeader)

        // Determine capabilities from DAV header
        let supportsCalDAV = davCompliance.contains { $0.contains("calendar-access") }
        let supportsCardDAV = davCompliance.contains { $0.contains("addressbook") }
        let supportsSyncCollection = davCompliance.contains { $0.contains("sync-collection") } ||
                                      davCompliance.contains("3") // DAV:3 includes sync-collection

        // Check for specific REPORT types by looking at methods
        let supportsCalendarQuery = supportsCalDAV
        let supportsAddressbookQuery = supportsCardDAV

        // Detect scheduling support (CalDAV Scheduling - RFC 6638)
        let supportsScheduling = davCompliance.contains { $0.contains("calendar-schedule") } ||
                                 davCompliance.contains { $0.contains("calendar-auto-schedule") }

        // Detect calendar-proxy support
        let supportsCalendarProxy = davCompliance.contains { $0.contains("calendar-proxy") }

        return ServerCapabilities(
            serverType: serverType,
            serverName: serverName,
            serverVersion: serverVersion,
            davCompliance: davCompliance,
            supportsCalDAV: supportsCalDAV,
            supportsCardDAV: supportsCardDAV,
            supportsSyncCollection: supportsSyncCollection,
            supportsCalendarQuery: supportsCalendarQuery,
            supportsAddressbookQuery: supportsAddressbookQuery,
            supportsScheduling: supportsScheduling,
            supportsCalendarProxy: supportsCalendarProxy,
            maxResourceSize: nil,
            supportedMethods: supportedMethods,
            customProperties: [:]
        )
    }

    /// Detect server type from headers and URL
    ///
    /// - Parameters:
    ///   - serverHeader: The Server header value
    ///   - baseURL: The server base URL
    /// - Returns: The detected server type
    public func detectServerType(from serverHeader: String, baseURL: URL) -> ServerType {
        let lowerServerHeader = serverHeader.lowercased()
        let host = baseURL.host?.lowercased() ?? ""

        // Check URL patterns first (most reliable)
        if host.contains("icloud.com") {
            return .iCloud
        }

        if host.contains("google.com") || host.contains("googleapis.com") {
            return .google
        }

        // Check Server header
        if lowerServerHeader.contains("nextcloud") {
            return .nextcloud
        }

        if lowerServerHeader.contains("owncloud") {
            return .ownCloud
        }

        if lowerServerHeader.contains("sogo") {
            return .sogo
        }

        if lowerServerHeader.contains("radicale") {
            return .radicale
        }

        if lowerServerHeader.contains("baikal") {
            return .baikal
        }

        if lowerServerHeader.contains("synology") {
            return .synology
        }

        // Default to generic
        return .generic
    }

    // MARK: - Private Methods

    /// Parse Server header into name and version
    private func parseServerHeader(_ serverHeader: String) -> (name: String?, version: String?) {
        guard !serverHeader.isEmpty else {
            return (nil, nil)
        }

        // Common formats:
        // "Nextcloud/25.0.3"
        // "Apache/2.4.52 (Ubuntu)"
        // "nginx/1.20.1"
        // "SOGo/5.5.0"

        let components = serverHeader.components(separatedBy: "/")
        guard components.count >= 2 else {
            return (serverHeader, nil)
        }

        let name = components[0]
        let versionPart = components[1].components(separatedBy: .whitespaces)[0]

        return (name, versionPart)
    }
}

// MARK: - Server-Specific Quirks

/// Server-specific behavior adaptations
///
/// Different CalDAV/CardDAV servers have quirks and non-standard behaviors.
/// This provides a way to adapt to server-specific requirements.
public struct ServerQuirks: Sendable {
    /// Whether the server requires trailing slashes on collection URLs
    public let requiresTrailingSlash: Bool

    /// Whether the server supports ETags properly
    public let supportsETags: Bool

    /// Whether the server supports If-Match/If-None-Match headers
    public let supportsConditionalRequests: Bool

    /// Whether PROPFIND Depth: 1 actually returns children (some servers don't)
    public let propfindDepthWorks: Bool

    /// Whether the server URL-encodes hrefs in PROPFIND responses
    public let urlEncodesHrefs: Bool

    /// Custom User-Agent to use for this server (if needed)
    public let customUserAgent: String?

    /// Maximum batch size for multi-get requests
    public let maxMultiGetSize: Int

    public init(
        requiresTrailingSlash: Bool = false,
        supportsETags: Bool = true,
        supportsConditionalRequests: Bool = true,
        propfindDepthWorks: Bool = true,
        urlEncodesHrefs: Bool = false,
        customUserAgent: String? = nil,
        maxMultiGetSize: Int = 100
    ) {
        self.requiresTrailingSlash = requiresTrailingSlash
        self.supportsETags = supportsETags
        self.supportsConditionalRequests = supportsConditionalRequests
        self.propfindDepthWorks = propfindDepthWorks
        self.urlEncodesHrefs = urlEncodesHrefs
        self.customUserAgent = customUserAgent
        self.maxMultiGetSize = maxMultiGetSize
    }

    /// Get server-specific quirks for a given server type
    ///
    /// - Parameter serverType: The server type
    /// - Returns: Quirks specific to that server type
    public static func quirks(for serverType: ServerType) -> ServerQuirks {
        switch serverType {
        case .iCloud:
            return ServerQuirks(
                requiresTrailingSlash: true,
                supportsETags: true,
                supportsConditionalRequests: true,
                propfindDepthWorks: true,
                urlEncodesHrefs: false,
                customUserAgent: nil,
                maxMultiGetSize: 50
            )

        case .google:
            return ServerQuirks(
                requiresTrailingSlash: false,
                supportsETags: true,
                supportsConditionalRequests: true,
                propfindDepthWorks: true,
                urlEncodesHrefs: false,
                customUserAgent: nil,
                maxMultiGetSize: 100
            )

        case .nextcloud, .ownCloud:
            return ServerQuirks(
                requiresTrailingSlash: true,
                supportsETags: true,
                supportsConditionalRequests: true,
                propfindDepthWorks: true,
                urlEncodesHrefs: false,
                customUserAgent: nil,
                maxMultiGetSize: 100
            )

        case .sogo:
            return ServerQuirks(
                requiresTrailingSlash: false,
                supportsETags: true,
                supportsConditionalRequests: true,
                propfindDepthWorks: true,
                urlEncodesHrefs: false,
                customUserAgent: nil,
                maxMultiGetSize: 100
            )

        case .radicale:
            return ServerQuirks(
                requiresTrailingSlash: true,
                supportsETags: true,
                supportsConditionalRequests: true,
                propfindDepthWorks: true,
                urlEncodesHrefs: false,
                customUserAgent: nil,
                maxMultiGetSize: 100
            )

        case .baikal:
            return ServerQuirks(
                requiresTrailingSlash: true,
                supportsETags: true,
                supportsConditionalRequests: true,
                propfindDepthWorks: true,
                urlEncodesHrefs: false,
                customUserAgent: nil,
                maxMultiGetSize: 100
            )

        case .synology:
            return ServerQuirks(
                requiresTrailingSlash: true,
                supportsETags: true,
                supportsConditionalRequests: true,
                propfindDepthWorks: true,
                urlEncodesHrefs: true,
                customUserAgent: nil,
                maxMultiGetSize: 50
            )

        case .generic:
            return ServerQuirks()
        }
    }
}
