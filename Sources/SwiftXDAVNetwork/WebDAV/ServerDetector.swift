import Foundation
import SwiftXDAVCore

/// Detects server capabilities via OPTIONS and PROPFIND requests
///
/// This actor performs server capability detection to determine which features
/// are supported by a CalDAV/CardDAV server.
///
/// ## Usage
///
/// ```swift
/// let detector = ServerDetector(httpClient: client)
/// let capabilities = try await detector.detect(baseURL: serverURL)
///
/// print("Server: \(capabilities.serverType)")
/// print("CalDAV: \(capabilities.supportsCalDAV)")
/// print("CardDAV: \(capabilities.supportsCardDAV)")
/// ```
public actor ServerDetector {
    private let httpClient: HTTPClient

    /// Initialize server detector
    ///
    /// - Parameter httpClient: HTTP client for making requests
    public init(httpClient: HTTPClient) {
        self.httpClient = httpClient
    }

    /// Detect server capabilities
    ///
    /// This performs an OPTIONS request to discover supported features.
    ///
    /// - Parameter baseURL: Base URL of the server
    /// - Returns: Detected server capabilities
    /// - Throws: `SwiftXDAVError` if detection fails
    public func detect(baseURL: URL) async throws -> ServerCapabilities {
        let response = try await httpClient.request(
            .options,
            url: baseURL,
            headers: nil,
            body: nil
        )

        guard response.statusCode == 200 else {
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }

        return parseCapabilities(from: response.headers, baseURL: baseURL)
    }

    /// Parse capabilities from OPTIONS response headers
    ///
    /// - Parameters:
    ///   - headers: HTTP headers from OPTIONS response
    ///   - baseURL: Base URL of the server
    /// - Returns: Parsed server capabilities
    private func parseCapabilities(from headers: [String: String], baseURL: URL) -> ServerCapabilities {
        // Normalize header keys to lowercase for case-insensitive lookup
        let normalizedHeaders = Dictionary(uniqueKeysWithValues: headers.map { (key: $0.key.lowercased(), value: $0.value) })

        // Parse DAV header
        let davHeader = normalizedHeaders["dav"] ?? ""
        let davClasses = ServerCapabilities.parseDavClasses(from: davHeader)

        // Check for specific capabilities
        let supportsCalDAV = davClasses.contains("calendar-access") ||
                             davClasses.contains("calendar-schedule")
        let supportsCardDAV = davClasses.contains("addressbook")
        let supportsSyncToken = davClasses.contains("sync-collection")
        let supportsScheduling = davClasses.contains("calendar-schedule")
        let supportsExtendedMKCOL = davClasses.contains("extended-mkcol")

        // Get server product
        let serverProduct = normalizedHeaders["server"]

        // Detect server type
        let serverType = ServerCapabilities.detectServerType(from: baseURL, serverProduct: serverProduct)

        // Apple and CalendarServer.org extensions
        let supportsAppleExtensions = (serverType == .iCloud) ||
                                       davHeader.contains("access-control") ||
                                       (serverProduct?.lowercased().contains("calendar server") ?? false)
        let supportsCalendarServerExtensions = supportsAppleExtensions ||
                                                (serverProduct?.lowercased().contains("calendarserver") ?? false)

        return ServerCapabilities(
            serverType: serverType,
            serverProduct: serverProduct,
            supportsCalDAV: supportsCalDAV,
            supportsCardDAV: supportsCardDAV,
            supportsSyncToken: supportsSyncToken,
            supportsScheduling: supportsScheduling,
            supportsExtendedMKCOL: supportsExtendedMKCOL,
            davClasses: davClasses,
            supportsAppleExtensions: supportsAppleExtensions,
            supportsCalendarServerExtensions: supportsCalendarServerExtensions
        )
    }

    /// Detect server capabilities with additional principal lookup
    ///
    /// This performs both OPTIONS and a PROPFIND to verify server capabilities.
    ///
    /// - Parameter baseURL: Base URL of the server
    /// - Returns: Detected server capabilities with validation
    /// - Throws: `SwiftXDAVError` if detection fails
    public func detectWithValidation(baseURL: URL) async throws -> ServerCapabilities {
        // First get basic capabilities via OPTIONS
        let capabilities = try await detect(baseURL: baseURL)

        // Validate by attempting principal discovery
        do {
            _ = try await discoverPrincipal(baseURL: baseURL)
            // If we successfully discovered principal, capabilities are valid
            return capabilities
        } catch {
            // If principal discovery fails, server might not support WebDAV properly
            // Return capabilities with warnings
            return ServerCapabilities(
                serverType: capabilities.serverType,
                serverProduct: capabilities.serverProduct,
                supportsCalDAV: false, // Can't verify without principal
                supportsCardDAV: false,
                supportsSyncToken: capabilities.supportsSyncToken,
                supportsScheduling: false,
                supportsExtendedMKCOL: capabilities.supportsExtendedMKCOL,
                davClasses: capabilities.davClasses,
                supportsAppleExtensions: capabilities.supportsAppleExtensions,
                supportsCalendarServerExtensions: capabilities.supportsCalendarServerExtensions
            )
        }
    }

    /// Discover principal URL (used for validation)
    ///
    /// - Parameter baseURL: Base URL of the server
    /// - Returns: Principal URL
    /// - Throws: `SwiftXDAVError` if discovery fails
    private func discoverPrincipal(baseURL: URL) async throws -> URL {
        let request = PropfindRequest(
            url: baseURL,
            depth: 0,
            properties: [DAVPropertyName.currentUserPrincipal]
        )

        let responses = try await request.execute(using: httpClient)

        guard let response = responses.first,
              let principalHref = response.property(named: "current-user-principal") else {
            throw SwiftXDAVError.notFound
        }

        // Clean up the href (remove XML fragments if present)
        var cleaned = principalHref
        if cleaned.contains("<href>") {
            cleaned = cleaned.replacingOccurrences(of: "<href>", with: "")
                .replacingOccurrences(of: "</href>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }

        guard let principalURL = URL(string: cleaned, relativeTo: baseURL)?.absoluteURL else {
            throw SwiftXDAVError.invalidData("Invalid principal URL: \(cleaned)")
        }

        return principalURL
    }
}
