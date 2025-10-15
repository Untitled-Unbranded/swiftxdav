import XCTest
@testable import SwiftXDAVContacts
@testable import SwiftXDAVCore
@testable import SwiftXDAVNetwork

final class CardDAVClientTests: XCTestCase {
    // MARK: - Mock HTTP Client

    actor MockHTTPClient: HTTPClient {
        var responses: [URL: HTTPResponse] = [:]
        var requestLog: [(HTTPMethod, URL)] = []

        func addResponse(for url: URL, statusCode: Int, headers: [String: String] = [:], body: String) {
            responses[url] = HTTPResponse(
                statusCode: statusCode,
                headers: headers,
                data: body.data(using: .utf8) ?? Data()
            )
        }

        func request(
            _ method: HTTPMethod,
            url: URL,
            headers: [String: String]?,
            body: Data?
        ) async throws -> HTTPResponse {
            requestLog.append((method, url))

            guard let response = responses[url] else {
                throw SwiftXDAVError.notFound
            }

            return response
        }
    }

    // MARK: - Address Book Model Tests

    func testAddressBookEquality() {
        let ab1 = AddressBook(
            url: URL(string: "https://example.com/ab1")!,
            displayName: "Address Book 1"
        )

        let ab2 = AddressBook(
            url: URL(string: "https://example.com/ab1")!,
            displayName: "Address Book 1"
        )

        let ab3 = AddressBook(
            url: URL(string: "https://example.com/ab2")!,
            displayName: "Address Book 2"
        )

        XCTAssertEqual(ab1, ab2)
        XCTAssertNotEqual(ab1, ab3)
    }

    // MARK: - Convenience Initializer Tests

    func testICloudInitializer() {
        let client = CardDAVClient.iCloud(
            username: "test@icloud.com",
            appSpecificPassword: "xxxx-xxxx-xxxx-xxxx"
        )

        // We can't directly test the internal state, but we can verify it was created
        XCTAssertNotNil(client)
    }

    func testGoogleInitializer() {
        let client = CardDAVClient.google(accessToken: "test-token")
        XCTAssertNotNil(client)
    }

    func testCustomServerInitializer() {
        let serverURL = URL(string: "https://carddav.example.com")!
        let client = CardDAVClient.custom(
            serverURL: serverURL,
            username: "user",
            password: "pass"
        )
        XCTAssertNotNil(client)
    }

    // MARK: - Address Book Listing Tests

    func testListAddressBooks() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://example.com/")!
        let principalURL = URL(string: "https://example.com/principals/user1/")!
        let addressBookHomeURL = URL(string: "https://example.com/addressbooks/user1/")!

        // Mock discovery responses
        let principalResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/</d:href>
            <d:propstat>
              <d:prop>
                <d:current-user-principal>
                  <d:href>/principals/user1/</d:href>
                </d:current-user-principal>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        let addressBookHomeResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
          <d:response>
            <d:href>/principals/user1/</d:href>
            <d:propstat>
              <d:prop>
                <c:addressbook-home-set>
                  <d:href>/addressbooks/user1/</d:href>
                </c:addressbook-home-set>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        // Mock address book list response
        let addressBookListResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav" xmlns:cs="http://calendarserver.org/ns/">
          <d:response>
            <d:href>/addressbooks/user1/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype>
                  <d:collection/>
                </d:resourcetype>
                <d:displayname>Address Book Home</d:displayname>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/addressbooks/user1/contacts/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype>
                  <d:collection/>
                  <c:addressbook/>
                </d:resourcetype>
                <d:displayname>Contacts</d:displayname>
                <c:addressbook-description>My contacts</c:addressbook-description>
                <c:supported-address-data>
                  <c:address-data-type content-type="text/vcard" version="3.0"/>
                  <c:address-data-type content-type="text/vcard" version="4.0"/>
                </c:supported-address-data>
                <cs:getctag>12345</cs:getctag>
                <d:getetag>"abc123"</d:getetag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/addressbooks/user1/work/</d:href>
            <d:propstat>
              <d:prop>
                <d:resourcetype>
                  <d:collection/>
                  <c:addressbook/>
                </d:resourcetype>
                <d:displayname>Work Contacts</d:displayname>
                <cs:getctag>67890</cs:getctag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        await mockClient.addResponse(for: baseURL, statusCode: 207, body: principalResponse)
        await mockClient.addResponse(for: principalURL, statusCode: 207, body: addressBookHomeResponse)
        await mockClient.addResponse(for: addressBookHomeURL, statusCode: 207, body: addressBookListResponse)

        let client = CardDAVClient(httpClient: mockClient, baseURL: baseURL)
        let addressBooks = try await client.listAddressBooks()

        XCTAssertEqual(addressBooks.count, 2)

        // Check first address book
        let contacts = addressBooks.first { $0.displayName == "Contacts" }
        XCTAssertNotNil(contacts)
        XCTAssertEqual(contacts?.description, "My contacts")
        XCTAssertEqual(contacts?.ctag, "12345")
        XCTAssertEqual(contacts?.etag, "\"abc123\"")

        // Check second address book
        let work = addressBooks.first { $0.displayName == "Work Contacts" }
        XCTAssertNotNil(work)
        XCTAssertEqual(work?.ctag, "67890")
    }

    // MARK: - Contact Operations Tests

    func testFetchContacts() async throws {
        let mockClient = MockHTTPClient()
        let addressBookURL = URL(string: "https://example.com/addressbooks/user1/contacts/")!

        // Mock addressbook-query REPORT response
        let queryResponse = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:" xmlns:c="urn:ietf:params:xml:ns:carddav">
          <d:response>
            <d:href>/addressbooks/user1/contacts/contact1.vcf</d:href>
            <d:propstat>
              <d:prop>
                <d:getetag>"etag1"</d:getetag>
                <c:address-data>BEGIN:VCARD
        VERSION:3.0
        UID:contact1@example.com
        FN:John Doe
        N:Doe;John;;;
        EMAIL;TYPE=work:john.doe@example.com
        TEL;TYPE=cell:+1-555-1234
        END:VCARD</c:address-data>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        await mockClient.addResponse(for: addressBookURL, statusCode: 207, body: queryResponse)

        let client = CardDAVClient(httpClient: mockClient, baseURL: URL(string: "https://example.com/")!)
        let addressBook = AddressBook(
            url: addressBookURL,
            displayName: "Test Address Book"
        )

        let contacts = try await client.fetchContacts(from: addressBook)

        XCTAssertEqual(contacts.count, 1)
        XCTAssertEqual(contacts[0].uid, "contact1@example.com")
        XCTAssertEqual(contacts[0].formattedName, "John Doe")
        XCTAssertEqual(contacts[0].name?.familyNames.first, "Doe")
        XCTAssertEqual(contacts[0].name?.givenNames.first, "John")
    }

    func testCreateContact() async throws {
        let mockClient = MockHTTPClient()
        let addressBookURL = URL(string: "https://example.com/addressbooks/user1/contacts/")!
        let contactURL = addressBookURL.appendingPathComponent("test-contact.vcf")

        // Mock PUT response
        await mockClient.addResponse(
            for: contactURL,
            statusCode: 201,
            headers: ["ETag": "\"new-etag\""],
            body: ""
        )

        let client = CardDAVClient(httpClient: mockClient, baseURL: URL(string: "https://example.com/")!)
        let addressBook = AddressBook(url: addressBookURL, displayName: "Test Address Book")

        let vcard = VCard(
            uid: "test-contact",
            formattedName: "Jane Smith",
            name: StructuredName(
                familyNames: ["Smith"],
                givenNames: ["Jane"]
            )
        )

        let createdContact = try await client.createContact(vcard, in: addressBook)
        XCTAssertEqual(createdContact.uid, "test-contact")
        XCTAssertEqual(createdContact.formattedName, "Jane Smith")

        // Verify PUT request was made
        let requestLog = await mockClient.requestLog
        XCTAssertTrue(requestLog.contains { $0.0 == .put && $0.1 == contactURL })
    }

    func testDeleteContact() async throws {
        let mockClient = MockHTTPClient()
        let addressBookURL = URL(string: "https://example.com/addressbooks/user1/contacts/")!
        let contactURL = addressBookURL.appendingPathComponent("contact-to-delete.vcf")

        // Mock DELETE response
        await mockClient.addResponse(for: contactURL, statusCode: 204, body: "")

        let client = CardDAVClient(httpClient: mockClient, baseURL: URL(string: "https://example.com/")!)
        let addressBook = AddressBook(url: addressBookURL, displayName: "Test Address Book")

        try await client.deleteContact(uid: "contact-to-delete", from: addressBook)

        // Verify DELETE request was made
        let requestLog = await mockClient.requestLog
        XCTAssertTrue(requestLog.contains { $0.0 == .delete && $0.1 == contactURL })
    }
}
