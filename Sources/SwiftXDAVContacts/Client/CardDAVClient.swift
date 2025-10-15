import Foundation
import SwiftXDAVCore
import SwiftXDAVNetwork

/// A client for interacting with CardDAV servers (RFC 6352)
///
/// `CardDAVClient` provides a high-level interface for discovering address books,
/// fetching contacts, and syncing contact data with CardDAV servers.
///
/// ## Usage
///
/// Create a client with your server URL and credentials:
///
/// ```swift
/// let client = CardDAVClient.iCloud(
///     username: "user@icloud.com",
///     appSpecificPassword: "abcd-efgh-ijkl-mnop"
/// )
/// ```
///
/// List address books:
///
/// ```swift
/// let addressBooks = try await client.listAddressBooks()
/// for addressBook in addressBooks {
///     print("\(addressBook.displayName): \(addressBook.url)")
/// }
/// ```
///
/// Fetch contacts:
///
/// ```swift
/// let contacts = try await client.fetchContacts(from: addressBook)
/// ```
///
/// ## Topics
///
/// ### Creating a Client
/// - ``init(httpClient:baseURL:)``
/// - ``iCloud(username:appSpecificPassword:)``
///
/// ### Discovery
/// - ``discoverPrincipal()``
/// - ``discoverAddressBookHome()``
///
/// ### Working with Address Books
/// - ``listAddressBooks()``
/// - ``listAddressBooks(at:)``
///
/// ### Working with Contacts
/// - ``fetchContacts(from:)``
/// - ``createContact(_:in:)``
/// - ``updateContact(_:in:etag:)``
/// - ``deleteContact(uid:from:)``
public actor CardDAVClient {
    internal let httpClient: HTTPClient
    internal let baseURL: URL

    // Cached discovery results
    private var cachedPrincipalURL: URL?
    private var cachedAddressBookHomeURL: URL?

    /// Initialize a CardDAV client
    ///
    /// - Parameters:
    ///   - httpClient: The HTTP client to use for requests
    ///   - baseURL: The base URL of the CardDAV server
    public init(httpClient: HTTPClient, baseURL: URL) {
        self.httpClient = httpClient
        self.baseURL = baseURL
    }

    // MARK: - Discovery

    /// Discover the current user's principal URL
    ///
    /// This performs a PROPFIND on the base URL to find the `current-user-principal` property.
    ///
    /// - Returns: The principal URL
    /// - Throws: `SwiftXDAVError` if discovery fails
    public func discoverPrincipal() async throws -> URL {
        if let cached = cachedPrincipalURL {
            return cached
        }

        let request = PropfindRequest(
            url: baseURL,
            depth: 0,
            properties: [DAVPropertyName.currentUserPrincipal]
        )

        let responses = try await request.execute(using: httpClient)

        guard let response = responses.first else {
            throw SwiftXDAVError.notFound
        }

        // Parse the current-user-principal href
        guard let principalHref = response.property(named: "current-user-principal") else {
            throw SwiftXDAVError.parsingError("current-user-principal property not found")
        }

        // Clean up the href (remove XML fragments if present)
        let cleanHref = cleanHref(principalHref)

        guard let principalURL = URL(string: cleanHref, relativeTo: baseURL)?.absoluteURL else {
            throw SwiftXDAVError.invalidData("Invalid principal URL: \(cleanHref)")
        }

        cachedPrincipalURL = principalURL
        return principalURL
    }

    /// Discover the address book home set URL
    ///
    /// This performs a PROPFIND on the principal URL to find the `addressbook-home-set` property.
    ///
    /// - Returns: The address book home URL
    /// - Throws: `SwiftXDAVError` if discovery fails
    public func discoverAddressBookHome() async throws -> URL {
        if let cached = cachedAddressBookHomeURL {
            return cached
        }

        let principalURL = try await discoverPrincipal()

        let request = PropfindRequest(
            url: principalURL,
            depth: 0,
            properties: [CardDAVPropertyName.addressbookHomeSet]
        )

        let responses = try await request.execute(using: httpClient)

        guard let response = responses.first else {
            throw SwiftXDAVError.notFound
        }

        guard let addressBookHomeHref = response.property(named: "addressbook-home-set") else {
            throw SwiftXDAVError.parsingError("addressbook-home-set property not found")
        }

        // Clean up the href
        let cleanHomeHref = cleanHref(addressBookHomeHref)

        guard let addressBookHomeURL = URL(string: cleanHomeHref, relativeTo: baseURL)?.absoluteURL else {
            throw SwiftXDAVError.invalidData("Invalid address book home URL: \(cleanHomeHref)")
        }

        cachedAddressBookHomeURL = addressBookHomeURL
        return addressBookHomeURL
    }

    // MARK: - Address Book Operations

    /// List all address books for the current user
    ///
    /// - Returns: An array of address books
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func listAddressBooks() async throws -> [AddressBook] {
        let addressBookHome = try await discoverAddressBookHome()
        return try await listAddressBooks(at: addressBookHome)
    }

    /// List address books at a specific URL
    ///
    /// - Parameter url: The URL to query for address books
    /// - Returns: An array of address books
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func listAddressBooks(at url: URL) async throws -> [AddressBook] {
        let request = PropfindRequest(
            url: url,
            depth: 1,
            properties: [
                DAVPropertyName.resourceType,
                DAVPropertyName.displayName,
                DAVPropertyName.getETag,
                CardDAVPropertyName.addressbookDescription,
                CardDAVPropertyName.supportedAddressData,
                CardDAVPropertyName.getctag,
                CardDAVPropertyName.addressBookColor
            ]
        )

        let responses = try await request.execute(using: httpClient)

        var addressBooks: [AddressBook] = []

        for response in responses {
            // Skip the collection itself (it will be in the response)
            if response.href == url.path || response.href == url.path + "/" {
                continue
            }

            // Check if this is an address book resource
            guard let resourceType = response.property(named: "resourcetype") else {
                continue
            }

            // Must be a collection
            guard resourceType.contains("collection") else {
                continue
            }

            // Some servers include "addressbook" in resourcetype, others don't
            // We'll accept any collection under addressbook-home as a potential address book

            guard let displayName = response.property(named: "displayname") else {
                continue
            }

            // Build the address book URL
            guard let addressBookURL = URL(string: response.href, relativeTo: url)?.absoluteURL else {
                continue
            }

            // Parse supported vCard versions
            let supportedVersions = parseSupportedVersions(
                response.property(named: "supported-address-data")
            )

            // Parse color (hex format like #FF5733FF)
            let color = response.property(named: "addressbook-color")

            let addressBook = AddressBook(
                url: addressBookURL,
                displayName: displayName,
                description: response.property(named: "addressbook-description"),
                ctag: response.property(named: "getctag"),
                etag: response.property(named: "getetag"),
                color: color,
                supportedVersions: supportedVersions
            )

            addressBooks.append(addressBook)
        }

        return addressBooks
    }

    // MARK: - Contact Operations

    /// Fetch all contacts from an address book
    ///
    /// This uses the CardDAV `addressbook-query` REPORT to retrieve contacts.
    ///
    /// - Parameter addressBook: The address book to query
    /// - Returns: An array of vCards
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func fetchContacts(from addressBook: AddressBook) async throws -> [VCard] {
        let queryXML = buildAddressBookQuery()

        let response = try await httpClient.request(
            .report,
            url: addressBook.url,
            headers: [
                "Content-Type": "application/xml; charset=utf-8",
                "Depth": "1"
            ],
            body: queryXML
        )

        guard response.statusCode == 207 else {
            throw SwiftXDAVError.invalidResponse(
                statusCode: response.statusCode,
                body: String(data: response.data, encoding: .utf8)
            )
        }

        // Parse multi-status response
        let parser = WebDAVXMLParser()
        let responses = try parser.parse(response.data)

        var contacts: [VCard] = []
        let vcardParser = VCardParser()

        for resp in responses {
            if let addressData = resp.property(named: "address-data"),
               let data = addressData.data(using: .utf8) {
                do {
                    let vcard = try await vcardParser.parse(data)
                    contacts.append(vcard)
                } catch {
                    // Skip malformed vCards but continue processing others
                    continue
                }
            }
        }

        return contacts
    }

    /// Create a new contact in an address book
    ///
    /// - Parameters:
    ///   - vcard: The vCard to create
    ///   - addressBook: The address book to create the contact in
    /// - Returns: The created vCard with updated metadata
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func createContact(_ vcard: VCard, in addressBook: AddressBook) async throws -> VCard {
        guard let uid = vcard.uid else {
            throw SwiftXDAVError.invalidData("vCard must have a UID")
        }

        let serializer = VCardSerializer()
        let data = try await serializer.serialize(vcard)

        let contactURL = addressBook.url.appendingPathComponent("\(uid).vcf")

        let webdav = WebDAVOperations(client: httpClient)
        _ = try await webdav.put(
            data,
            at: contactURL,
            contentType: "text/vcard; charset=utf-8"
        )

        return vcard
    }

    /// Update an existing contact
    ///
    /// - Parameters:
    ///   - vcard: The vCard with updated data
    ///   - addressBook: The address book containing the contact
    ///   - etag: The current ETag of the contact (for conflict detection)
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func updateContact(_ vcard: VCard, in addressBook: AddressBook, etag: String) async throws {
        guard let uid = vcard.uid else {
            throw SwiftXDAVError.invalidData("vCard must have a UID")
        }

        let serializer = VCardSerializer()
        let data = try await serializer.serialize(vcard)

        let contactURL = addressBook.url.appendingPathComponent("\(uid).vcf")

        let webdav = WebDAVOperations(client: httpClient)
        _ = try await webdav.put(
            data,
            at: contactURL,
            contentType: "text/vcard; charset=utf-8",
            ifMatch: etag
        )
    }

    /// Delete a contact from an address book
    ///
    /// - Parameters:
    ///   - uid: The UID of the contact to delete
    ///   - addressBook: The address book containing the contact
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func deleteContact(uid: String, from addressBook: AddressBook) async throws {
        let contactURL = addressBook.url.appendingPathComponent("\(uid).vcf")

        let webdav = WebDAVOperations(client: httpClient)
        try await webdav.delete(at: contactURL)
    }

    // MARK: - Helper Methods

    /// Clean up href values that may contain XML fragments
    private func cleanHref(_ href: String) -> String {
        // Remove <href> tags if present
        var cleaned = href
        if cleaned.contains("<href>") {
            cleaned = cleaned.replacingOccurrences(of: "<href>", with: "")
                .replacingOccurrences(of: "</href>", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return cleaned
    }

    /// Parse supported vCard versions from property value
    private func parseSupportedVersions(_ value: String?) -> [VCardVersion] {
        guard let value = value else {
            // Default to both versions if not specified
            return [.v3_0, .v4_0]
        }

        var versions: [VCardVersion] = []

        if value.contains("3.0") {
            versions.append(.v3_0)
        }
        if value.contains("4.0") {
            versions.append(.v4_0)
        }

        return versions.isEmpty ? [.v3_0, .v4_0] : versions
    }

    /// Build an addressbook-query REPORT request body
    private func buildAddressBookQuery() -> Data {
        let xml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <C:addressbook-query xmlns:D="DAV:" xmlns:C="urn:ietf:params:xml:ns:carddav">
          <D:prop>
            <D:getetag/>
            <C:address-data/>
          </D:prop>
        </C:addressbook-query>
        """

        return xml.data(using: .utf8) ?? Data()
    }
}

// MARK: - Convenience Initializers

extension CardDAVClient {
    /// Create a CardDAV client for iCloud
    ///
    /// iCloud requires app-specific passwords for CardDAV access.
    /// Generate one at: https://appleid.apple.com
    ///
    /// - Parameters:
    ///   - username: Your Apple ID (e.g., "user@icloud.com")
    ///   - appSpecificPassword: An app-specific password (format: "xxxx-xxxx-xxxx-xxxx")
    /// - Returns: A configured CardDAV client for iCloud
    public static func iCloud(username: String, appSpecificPassword: String) -> CardDAVClient {
        let baseClient = AlamofireHTTPClient()
        let auth = Authentication.basic(username: username, password: appSpecificPassword)
        let authedClient = AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)

        return CardDAVClient(
            httpClient: authedClient,
            baseURL: URL(string: "https://contacts.icloud.com")!
        )
    }

    /// Create a CardDAV client for Google Contacts
    ///
    /// Google Contacts requires OAuth 2.0 authentication.
    ///
    /// - Parameters:
    ///   - accessToken: OAuth 2.0 access token
    /// - Returns: A configured CardDAV client for Google Contacts
    public static func google(accessToken: String) -> CardDAVClient {
        let baseClient = AlamofireHTTPClient()
        let auth = Authentication.bearer(token: accessToken)
        let authedClient = AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)

        return CardDAVClient(
            httpClient: authedClient,
            baseURL: URL(string: "https://www.googleapis.com/.well-known/carddav")!
        )
    }

    /// Create a CardDAV client for a custom server
    ///
    /// - Parameters:
    ///   - serverURL: The base URL of the CardDAV server
    ///   - username: Username for basic authentication
    ///   - password: Password for basic authentication
    /// - Returns: A configured CardDAV client
    public static func custom(serverURL: URL, username: String, password: String) -> CardDAVClient {
        let baseClient = AlamofireHTTPClient()
        let auth = Authentication.basic(username: username, password: password)
        let authedClient = AuthenticatedHTTPClient(baseClient: baseClient, authentication: auth)

        return CardDAVClient(
            httpClient: authedClient,
            baseURL: serverURL
        )
    }
}
