import Foundation
import SwiftXDAVCore

/// Server-specific URL and behavior adapter
///
/// Handles server-specific quirks and URL transformations based on server type.
///
/// ## Usage
///
/// ```swift
/// let adapter = ServerAdapter(serverType: .iCloud)
/// let correctedURL = adapter.normalizeURL(url)
/// ```
public struct ServerAdapter: Sendable {
    /// The server type this adapter is configured for
    public let serverType: ServerType

    /// The server quirks
    public let quirks: ServerQuirks

    /// Create a server adapter
    ///
    /// - Parameter serverType: The type of server to adapt for
    public init(serverType: ServerType) {
        self.serverType = serverType
        self.quirks = ServerQuirks.quirks(for: serverType)
    }

    /// Create a server adapter with custom quirks
    ///
    /// - Parameters:
    ///   - serverType: The type of server
    ///   - quirks: Custom quirks to use
    public init(serverType: ServerType, quirks: ServerQuirks) {
        self.serverType = serverType
        self.quirks = quirks
    }

    // MARK: - URL Normalization

    /// Normalize a URL according to server quirks
    ///
    /// - Parameter url: The URL to normalize
    /// - Returns: The normalized URL
    public func normalizeURL(_ url: URL) -> URL {
        var urlString = url.absoluteString

        // Handle trailing slash requirements
        if quirks.requiresTrailingSlash {
            if !urlString.hasSuffix("/") && !url.pathExtension.isEmpty == false {
                // Add trailing slash to collection URLs (no file extension)
                if url.pathExtension.isEmpty {
                    urlString += "/"
                }
            }
        }

        return URL(string: urlString) ?? url
    }

    /// Normalize a collection URL
    ///
    /// Collection URLs often need special handling (trailing slashes, etc.)
    ///
    /// - Parameter url: The collection URL
    /// - Returns: The normalized collection URL
    public func normalizeCollectionURL(_ url: URL) -> URL {
        var urlString = url.absoluteString

        // Ensure trailing slash for collections if required
        if quirks.requiresTrailingSlash && !urlString.hasSuffix("/") {
            urlString += "/"
        }

        return URL(string: urlString) ?? url
    }

    /// Normalize a resource URL (for files like .ics, .vcf)
    ///
    /// - Parameter url: The resource URL
    /// - Returns: The normalized resource URL
    public func normalizeResourceURL(_ url: URL) -> URL {
        var urlString = url.absoluteString

        // Remove trailing slash from resource URLs if present
        if urlString.hasSuffix("/") && !url.pathExtension.isEmpty {
            urlString = String(urlString.dropLast())
        }

        return URL(string: urlString) ?? url
    }

    /// Decode href from PROPFIND response
    ///
    /// Some servers URL-encode hrefs, others don't.
    ///
    /// - Parameter href: The href string from PROPFIND
    /// - Returns: The decoded href
    public func decodeHref(_ href: String) -> String {
        if quirks.urlEncodesHrefs {
            return href.removingPercentEncoding ?? href
        }
        return href
    }

    // MARK: - Request Headers

    /// Get recommended User-Agent header for this server
    ///
    /// - Returns: The User-Agent header value
    public func userAgent() -> String {
        quirks.customUserAgent ?? "SwiftXDAV/1.0"
    }

    /// Apply server-specific headers to request headers
    ///
    /// - Parameter headers: The headers dictionary to modify
    public func applyServerSpecificHeaders(to headers: inout [String: String]) {
        // Set User-Agent
        if headers["User-Agent"] == nil {
            headers["User-Agent"] = userAgent()
        }

        // Server-specific header requirements
        switch serverType {
        case .iCloud:
            // iCloud doesn't need special headers
            break

        case .google:
            // Google prefers certain accept headers
            if headers["Accept"] == nil {
                headers["Accept"] = "text/xml, application/xml, text/calendar, text/vcard"
            }

        case .nextcloud, .ownCloud:
            // Nextcloud/ownCloud work well with standard headers
            break

        case .sogo:
            // SOGo has good standards compliance
            break

        case .radicale:
            // Radicale is very standards-compliant
            break

        case .baikal:
            // Baikal is standards-compliant
            break

        case .synology:
            // Synology sometimes needs explicit content-type
            break

        case .generic:
            // Generic server - use standard headers
            break
        }
    }

    // MARK: - Batching

    /// Get maximum batch size for multi-get requests
    ///
    /// - Returns: Maximum number of resources to request in a single multi-get
    public func maxBatchSize() -> Int {
        quirks.maxMultiGetSize
    }

    /// Split resources into batches for multi-get
    ///
    /// - Parameter hrefs: Array of resource hrefs
    /// - Returns: Array of batches, each containing up to maxBatchSize hrefs
    public func batchHrefs(_ hrefs: [String]) -> [[String]] {
        let batchSize = maxBatchSize()
        var batches: [[String]] = []
        var currentBatch: [String] = []

        for href in hrefs {
            currentBatch.append(href)
            if currentBatch.count >= batchSize {
                batches.append(currentBatch)
                currentBatch = []
            }
        }

        if !currentBatch.isEmpty {
            batches.append(currentBatch)
        }

        return batches
    }
}

// MARK: - Well-Known URL Construction

extension ServerAdapter {
    /// Get well-known CalDAV URL for server discovery
    ///
    /// - Parameter baseURL: The server base URL
    /// - Returns: The well-known CalDAV URL
    public static func wellKnownCalDAVURL(for baseURL: URL) -> URL {
        // RFC 6764: CalDAV Service Discovery
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/.well-known/caldav"
        return components.url ?? baseURL
    }

    /// Get well-known CardDAV URL for server discovery
    ///
    /// - Parameter baseURL: The server base URL
    /// - Returns: The well-known CardDAV URL
    public static func wellKnownCardDAVURL(for baseURL: URL) -> URL {
        // RFC 6764: CardDAV Service Discovery
        var components = URLComponents(url: baseURL, resolvingAgainstBaseURL: false)!
        components.path = "/.well-known/carddav"
        return components.url ?? baseURL
    }
}
