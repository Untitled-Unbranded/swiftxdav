import XCTest
@testable import SwiftXDAVNetwork

final class ServerAdapterTests: XCTestCase {
    // MARK: - URL Normalization

    func testNormalizeCollectionURLWithTrailingSlash() {
        let adapter = ServerAdapter(serverType: .iCloud)

        let url = URL(string: "https://caldav.icloud.com/calendars/test")!
        let normalized = adapter.normalizeCollectionURL(url)

        XCTAssertEqual(normalized.absoluteString, "https://caldav.icloud.com/calendars/test/")
    }

    func testNormalizeCollectionURLAlreadyHasTrailingSlash() {
        let adapter = ServerAdapter(serverType: .iCloud)

        let url = URL(string: "https://caldav.icloud.com/calendars/test/")!
        let normalized = adapter.normalizeCollectionURL(url)

        XCTAssertEqual(normalized.absoluteString, "https://caldav.icloud.com/calendars/test/")
    }

    func testNormalizeResourceURLRemovesTrailingSlash() {
        let adapter = ServerAdapter(serverType: .iCloud)

        let url = URL(string: "https://caldav.icloud.com/calendars/test/event.ics/")!
        let normalized = adapter.normalizeResourceURL(url)

        XCTAssertEqual(normalized.absoluteString, "https://caldav.icloud.com/calendars/test/event.ics")
    }

    func testNormalizeResourceURLNoTrailingSlash() {
        let adapter = ServerAdapter(serverType: .iCloud)

        let url = URL(string: "https://caldav.icloud.com/calendars/test/event.ics")!
        let normalized = adapter.normalizeResourceURL(url)

        XCTAssertEqual(normalized.absoluteString, "https://caldav.icloud.com/calendars/test/event.ics")
    }

    func testGoogleDoesNotRequireTrailingSlash() {
        let adapter = ServerAdapter(serverType: .google)

        let url = URL(string: "https://apidata.googleusercontent.com/caldav/v2/user@gmail.com/events")!
        let normalized = adapter.normalizeCollectionURL(url)

        // Google doesn't require trailing slash, so URL should be unchanged
        XCTAssertEqual(normalized.absoluteString, url.absoluteString)
    }

    // MARK: - Href Decoding

    func testDecodeHrefNoEncoding() {
        let adapter = ServerAdapter(serverType: .iCloud)
        let href = "/calendars/user/calendar/"
        let decoded = adapter.decodeHref(href)

        XCTAssertEqual(decoded, href)
    }

    func testDecodeHrefWithEncoding() {
        let adapter = ServerAdapter(serverType: .synology)
        let href = "/calendars/user/My%20Calendar/"
        let decoded = adapter.decodeHref(href)

        XCTAssertEqual(decoded, "/calendars/user/My Calendar/")
    }

    // MARK: - User-Agent

    func testDefaultUserAgent() {
        let adapter = ServerAdapter(serverType: .generic)
        let userAgent = adapter.userAgent()

        XCTAssertEqual(userAgent, "SwiftXDAV/1.0")
    }

    func testCustomUserAgent() {
        var quirks = ServerQuirks()
        quirks = ServerQuirks(customUserAgent: "CustomClient/2.0")

        let adapter = ServerAdapter(serverType: .generic, quirks: quirks)
        let userAgent = adapter.userAgent()

        XCTAssertEqual(userAgent, "CustomClient/2.0")
    }

    // MARK: - Headers

    func testApplyServerSpecificHeaders() {
        let adapter = ServerAdapter(serverType: .google)
        var headers: [String: String] = [:]

        adapter.applyServerSpecificHeaders(to: &headers)

        XCTAssertNotNil(headers["User-Agent"])
        XCTAssertNotNil(headers["Accept"])
    }

    func testDoesNotOverrideExistingUserAgent() {
        let adapter = ServerAdapter(serverType: .google)
        var headers: [String: String] = ["User-Agent": "MyCustomAgent/1.0"]

        adapter.applyServerSpecificHeaders(to: &headers)

        XCTAssertEqual(headers["User-Agent"], "MyCustomAgent/1.0")
    }

    // MARK: - Batching

    func testMaxBatchSize() {
        let iCloudAdapter = ServerAdapter(serverType: .iCloud)
        XCTAssertEqual(iCloudAdapter.maxBatchSize(), 50)

        let googleAdapter = ServerAdapter(serverType: .google)
        XCTAssertEqual(googleAdapter.maxBatchSize(), 100)

        let nextcloudAdapter = ServerAdapter(serverType: .nextcloud)
        XCTAssertEqual(nextcloudAdapter.maxBatchSize(), 100)
    }

    func testBatchHrefs() {
        let adapter = ServerAdapter(serverType: .iCloud)

        // Create 120 hrefs
        let hrefs = (0..<120).map { "/calendar/event\($0).ics" }

        let batches = adapter.batchHrefs(hrefs)

        // iCloud max batch size is 50, so we should have 3 batches
        XCTAssertEqual(batches.count, 3)
        XCTAssertEqual(batches[0].count, 50)
        XCTAssertEqual(batches[1].count, 50)
        XCTAssertEqual(batches[2].count, 20)
    }

    func testBatchHrefsSmallerThanMax() {
        let adapter = ServerAdapter(serverType: .google)

        let hrefs = (0..<25).map { "/calendar/event\($0).ics" }
        let batches = adapter.batchHrefs(hrefs)

        XCTAssertEqual(batches.count, 1)
        XCTAssertEqual(batches[0].count, 25)
    }

    func testBatchHrefsEmpty() {
        let adapter = ServerAdapter(serverType: .generic)

        let hrefs: [String] = []
        let batches = adapter.batchHrefs(hrefs)

        XCTAssertEqual(batches.count, 0)
    }

    // MARK: - Server Quirks

    func testICloudQuirks() {
        let quirks = ServerQuirks.quirks(for: .iCloud)

        XCTAssertTrue(quirks.requiresTrailingSlash)
        XCTAssertTrue(quirks.supportsETags)
        XCTAssertTrue(quirks.supportsConditionalRequests)
        XCTAssertEqual(quirks.maxMultiGetSize, 50)
    }

    func testGoogleQuirks() {
        let quirks = ServerQuirks.quirks(for: .google)

        XCTAssertFalse(quirks.requiresTrailingSlash)
        XCTAssertTrue(quirks.supportsETags)
        XCTAssertEqual(quirks.maxMultiGetSize, 100)
    }

    func testNextcloudQuirks() {
        let quirks = ServerQuirks.quirks(for: .nextcloud)

        XCTAssertTrue(quirks.requiresTrailingSlash)
        XCTAssertTrue(quirks.supportsETags)
        XCTAssertEqual(quirks.maxMultiGetSize, 100)
    }

    func testSynologyQuirks() {
        let quirks = ServerQuirks.quirks(for: .synology)

        XCTAssertTrue(quirks.urlEncodesHrefs)
        XCTAssertEqual(quirks.maxMultiGetSize, 50)
    }

    // MARK: - Well-Known URLs

    func testWellKnownCalDAVURL() {
        let baseURL = URL(string: "https://example.com")!
        let wellKnownURL = ServerAdapter.wellKnownCalDAVURL(for: baseURL)

        XCTAssertEqual(wellKnownURL.absoluteString, "https://example.com/.well-known/caldav")
    }

    func testWellKnownCardDAVURL() {
        let baseURL = URL(string: "https://example.com")!
        let wellKnownURL = ServerAdapter.wellKnownCardDAVURL(for: baseURL)

        XCTAssertEqual(wellKnownURL.absoluteString, "https://example.com/.well-known/carddav")
    }

    func testWellKnownURLWithPath() {
        let baseURL = URL(string: "https://example.com/dav")!
        let wellKnownURL = ServerAdapter.wellKnownCalDAVURL(for: baseURL)

        // Well-known should replace the path
        XCTAssertEqual(wellKnownURL.absoluteString, "https://example.com/.well-known/caldav")
    }
}
