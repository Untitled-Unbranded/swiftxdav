import XCTest
@testable import SwiftXDAVNetwork
@testable import SwiftXDAVCore

final class SyncCollectionTests: XCTestCase {
    // MARK: - Request Building Tests

    func testSyncCollectionRequestInitialSync() {
        let url = URL(string: "https://example.com/calendar/")!

        let request = SyncCollectionRequest(
            url: url,
            syncToken: nil,
            properties: [DAVPropertyName.getETag]
        )

        XCTAssertEqual(request.url, url)
        XCTAssertNil(request.syncToken)
        XCTAssertEqual(request.properties.count, 1)
    }

    func testSyncCollectionRequestWithToken() {
        let url = URL(string: "https://example.com/calendar/")!
        let token = SyncToken("test-token-123")

        let request = SyncCollectionRequest(
            url: url,
            syncToken: token,
            properties: [DAVPropertyName.getETag]
        )

        XCTAssertEqual(request.url, url)
        XCTAssertEqual(request.syncToken, token)
    }

    func testSyncCollectionRequestXMLGeneration() {
        let url = URL(string: "https://example.com/calendar/")!

        let request = SyncCollectionRequest(
            url: url,
            syncToken: nil,
            properties: [DAVPropertyName.getETag]
        )

        let xml = request.buildXML()
        let xmlString = String(data: xml, encoding: .utf8)!

        XCTAssertTrue(xmlString.contains("<d:sync-collection"))
        XCTAssertTrue(xmlString.contains("<d:sync-token>"))
        XCTAssertTrue(xmlString.contains("</d:sync-token>"))
        XCTAssertTrue(xmlString.contains("<d:sync-level>1</d:sync-level>"))
        XCTAssertTrue(xmlString.contains("<d:prop>"))
        XCTAssertTrue(xmlString.contains("<d:getetag"))
    }

    func testSyncCollectionRequestXMLWithToken() {
        let url = URL(string: "https://example.com/calendar/")!
        let token = SyncToken("http://example.com/sync/123")

        let request = SyncCollectionRequest(
            url: url,
            syncToken: token,
            properties: [DAVPropertyName.getETag]
        )

        let xml = request.buildXML()
        let xmlString = String(data: xml, encoding: .utf8)!

        XCTAssertTrue(xmlString.contains("http://example.com/sync/123"))
    }

    // MARK: - Response Parsing Tests

    func testSyncCollectionResponseParsing() async throws {
        let responseXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:sync-token>http://example.com/sync/124</d:sync-token>
          <d:response>
            <d:href>/calendar/event1.ics</d:href>
            <d:propstat>
              <d:prop>
                <d:getetag>"abc123"</d:getetag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/calendar/event2.ics</d:href>
            <d:status>HTTP/1.1 404 Not Found</d:status>
          </d:response>
        </d:multistatus>
        """

        let data = responseXML.data(using: .utf8)!
        let parser = SyncCollectionParser()
        let response = try parser.parse(data)

        XCTAssertEqual(response.newSyncToken.value, "http://example.com/sync/124")
        XCTAssertEqual(response.changedResources.count, 1)
        XCTAssertEqual(response.deletedResources.count, 1)

        let changed = response.changedResources[0]
        XCTAssertEqual(changed.url.path, "/calendar/event1.ics")
        XCTAssertEqual(changed.etag, "\"abc123\"")

        let deleted = response.deletedResources[0]
        XCTAssertEqual(deleted.path, "/calendar/event2.ics")
    }

    func testSyncCollectionResponseParsingInitialSync() async throws {
        let responseXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:sync-token>http://example.com/sync/initial</d:sync-token>
          <d:response>
            <d:href>/calendar/event1.ics</d:href>
            <d:propstat>
              <d:prop>
                <d:getetag>"etag1"</d:getetag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
          <d:response>
            <d:href>/calendar/event2.ics</d:href>
            <d:propstat>
              <d:prop>
                <d:getetag>"etag2"</d:getetag>
              </d:prop>
              <d:status>HTTP/1.1 200 OK</d:status>
            </d:propstat>
          </d:response>
        </d:multistatus>
        """

        let data = responseXML.data(using: .utf8)!
        let parser = SyncCollectionParser()
        let response = try parser.parse(data)

        XCTAssertEqual(response.newSyncToken.value, "http://example.com/sync/initial")
        XCTAssertEqual(response.changedResources.count, 2)
        XCTAssertEqual(response.deletedResources.count, 0)
    }

    func testSyncCollectionResponseMissingToken() async {
        let responseXML = """
        <?xml version="1.0" encoding="UTF-8"?>
        <d:multistatus xmlns:d="DAV:">
          <d:response>
            <d:href>/calendar/event1.ics</d:href>
          </d:response>
        </d:multistatus>
        """

        let data = responseXML.data(using: .utf8)!
        let parser = SyncCollectionParser()

        do {
            _ = try parser.parse(data)
            XCTFail("Should have thrown an error")
        } catch SwiftXDAVError.parsingError(let message) {
            XCTAssertTrue(message.contains("sync-token"))
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    // MARK: - SyncResourceInfo Tests

    func testSyncResourceInfo() {
        let url = URL(string: "https://example.com/event.ics")!
        let etag = "abc123"
        let properties = ["displayname": "Test Event"]

        let info = SyncResourceInfo(url: url, etag: etag, properties: properties)

        XCTAssertEqual(info.url, url)
        XCTAssertEqual(info.etag, etag)
        XCTAssertEqual(info.properties["displayname"], "Test Event")
    }

    func testSyncResourceInfoEquality() {
        let url = URL(string: "https://example.com/event.ics")!

        let info1 = SyncResourceInfo(url: url, etag: "123", properties: [:])
        let info2 = SyncResourceInfo(url: url, etag: "123", properties: [:])
        let info3 = SyncResourceInfo(url: url, etag: "124", properties: [:])

        XCTAssertEqual(info1, info2)
        XCTAssertNotEqual(info1, info3)
    }
}
