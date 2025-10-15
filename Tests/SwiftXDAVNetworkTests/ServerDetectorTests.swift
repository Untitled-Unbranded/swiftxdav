import XCTest
@testable import SwiftXDAVNetwork
@testable import SwiftXDAVCore

final class ServerDetectorTests: XCTestCase {
    // MARK: - Server Detection Tests

    func testDetectICloudServer() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://caldav.icloud.com")!

        // Mock OPTIONS response with iCloud-like headers
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "DAV": "1, 2, 3, calendar-access, calendar-schedule, addressbook, sync-collection, extended-mkcol",
                "Server": "CalendarServer/10.0"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        XCTAssertEqual(capabilities.serverType, .iCloud)
        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertTrue(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsSyncToken)
        XCTAssertTrue(capabilities.supportsScheduling)
        XCTAssertTrue(capabilities.supportsExtendedMKCOL)
        XCTAssertTrue(capabilities.supportsAppleExtensions)
        XCTAssertTrue(capabilities.supportsCalendarServerExtensions)
    }

    func testDetectGoogleServer() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://apidata.googleusercontent.com/caldav/v2/")!

        // Mock OPTIONS response with Google-like headers
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "DAV": "1, calendar-access, sync-collection",
                "Server": "Google Calendar"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        XCTAssertEqual(capabilities.serverType, .google)
        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertFalse(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsSyncToken)
        XCTAssertFalse(capabilities.supportsScheduling)
        XCTAssertFalse(capabilities.supportsAppleExtensions)
    }

    func testDetectNextcloudServer() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://cloud.example.com")!

        // Mock OPTIONS response with Nextcloud-like headers
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "DAV": "1, 2, 3, calendar-access, calendar-schedule, addressbook, sync-collection",
                "Server": "Nextcloud/25.0.0"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        XCTAssertEqual(capabilities.serverType, .nextcloud)
        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertTrue(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsSyncToken)
        XCTAssertTrue(capabilities.supportsScheduling)
    }

    func testDetectRadicaleServer() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://dav.example.com")!

        // Mock OPTIONS response with Radicale-like headers
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "DAV": "1, calendar-access, addressbook",
                "Server": "Radicale/3.1.8"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        XCTAssertEqual(capabilities.serverType, .radicale)
        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertTrue(capabilities.supportsCardDAV)
        XCTAssertFalse(capabilities.supportsSyncToken)
        XCTAssertFalse(capabilities.supportsScheduling)
    }

    func testDetectGenericServer() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://dav.example.com")!

        // Mock OPTIONS response with minimal DAV support
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "DAV": "1, 2",
                "Server": "Custom WebDAV Server"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        XCTAssertEqual(capabilities.serverType, .generic)
        XCTAssertFalse(capabilities.supportsCalDAV)
        XCTAssertFalse(capabilities.supportsCardDAV)
        XCTAssertFalse(capabilities.supportsSyncToken)
    }

    func testDetectionWithoutServerHeader() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://dav.example.com")!

        // Mock OPTIONS response without Server header
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "DAV": "1, 2, calendar-access"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        XCTAssertEqual(capabilities.serverType, .generic)
        XCTAssertNil(capabilities.serverProduct)
        XCTAssertTrue(capabilities.supportsCalDAV)
    }

    func testDetectionFailureWithBadStatus() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://dav.example.com")!

        // Mock failed OPTIONS response
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 404,
            headers: [:],
            body: "Not Found"
        )

        let detector = ServerDetector(httpClient: mockClient)

        do {
            _ = try await detector.detect(baseURL: baseURL)
            XCTFail("Should throw error for 404 response")
        } catch let error as SwiftXDAVError {
            if case .invalidResponse(let statusCode, _) = error {
                XCTAssertEqual(statusCode, 404)
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        }
    }

    func testCaseInsensitiveHeaderParsing() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://dav.example.com")!

        // Mock OPTIONS response with different case headers
        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "dav": "1, 2, calendar-access",  // lowercase
                "Server": "Test Server"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        // Should still parse DAV header correctly
        XCTAssertTrue(capabilities.supportsCalDAV)
    }

    func testDAVClassParsing() async throws {
        let mockClient = MockHTTPClient()
        let baseURL = URL(string: "https://dav.example.com")!

        await mockClient.addResponse(
            for: baseURL,
            statusCode: 200,
            headers: [
                "DAV": "1, 2, 3, calendar-access, calendar-schedule, addressbook, sync-collection, extended-mkcol"
            ],
            body: ""
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detect(baseURL: baseURL)

        XCTAssertTrue(capabilities.supportsDavClass("1"))
        XCTAssertTrue(capabilities.supportsDavClass("2"))
        XCTAssertTrue(capabilities.supportsDavClass("3"))
        XCTAssertTrue(capabilities.supportsDavClass("calendar-access"))
        XCTAssertTrue(capabilities.supportsDavClass("calendar-schedule"))
        XCTAssertTrue(capabilities.supportsDavClass("addressbook"))
        XCTAssertTrue(capabilities.supportsDavClass("sync-collection"))
        XCTAssertTrue(capabilities.supportsDavClass("extended-mkcol"))
    }
}

// Use the same MockHTTPClient from OAuth2TokenManagerTests
// (In a real test suite, this would be in a shared test utilities file)
