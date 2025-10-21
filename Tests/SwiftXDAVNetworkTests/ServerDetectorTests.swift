import XCTest
@testable import SwiftXDAVNetwork
@testable import SwiftXDAVCore

final class ServerDetectorTests: XCTestCase {
    // MARK: - Server Type Detection

    func testDetectICloudFromURL() async {
        let mockClient = MockHTTPClient()
        let detector = ServerDetector(httpClient: mockClient)

        let iCloudURL = URL(string: "https://caldav.icloud.com")!
        let serverType = await detector.detectServerType(from: "", baseURL: iCloudURL)

        XCTAssertEqual(serverType, .iCloud)
    }

    func testDetectGoogleFromURL() async {
        let mockClient = MockHTTPClient()
        let detector = ServerDetector(httpClient: mockClient)

        let googleURL = URL(string: "https://apidata.googleusercontent.com")!
        let serverType = await detector.detectServerType(from: "", baseURL: googleURL)

        XCTAssertEqual(serverType, .google)
    }

    func testDetectNextcloudFromServerHeader() async {
        let mockClient = MockHTTPClient()
        let detector = ServerDetector(httpClient: mockClient)

        let url = URL(string: "https://cloud.example.com")!
        let serverType = await detector.detectServerType(
            from: "Nextcloud/25.0.3",
            baseURL: url
        )

        XCTAssertEqual(serverType, .nextcloud)
    }

    func testDetectRadicaleFromServerHeader() async {
        let mockClient = MockHTTPClient()
        let detector = ServerDetector(httpClient: mockClient)

        let url = URL(string: "https://dav.example.com")!
        let serverType = await detector.detectServerType(
            from: "Radicale/3.1.8",
            baseURL: url
        )

        XCTAssertEqual(serverType, .radicale)
    }

    func testDetectGenericServer() async {
        let mockClient = MockHTTPClient()
        let detector = ServerDetector(httpClient: mockClient)

        let url = URL(string: "https://unknown.example.com")!
        let serverType = await detector.detectServerType(
            from: "Apache/2.4.52",
            baseURL: url
        )

        XCTAssertEqual(serverType, .generic)
    }

    // MARK: - Capability Detection

    func testDetectCalDAVCapability() async throws {
        let mockClient = MockHTTPClient()
        mockClient.mockResponse = HTTPResponse(
            statusCode: 200,
            headers: [
                "DAV": "1, 2, 3, calendar-access",
                "Allow": "OPTIONS, GET, HEAD, POST, PUT, DELETE, PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK, REPORT",
                "Server": "Radicale/3.1.8"
            ],
            data: Data()
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detectCapabilities(
            baseURL: URL(string: "https://dav.example.com")!
        )

        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertTrue(capabilities.supportsSyncCollection)
        XCTAssertTrue(capabilities.supportsCalendarQuery)
        XCTAssertEqual(capabilities.serverType, .radicale)
    }

    func testDetectCardDAVCapability() async throws {
        let mockClient = MockHTTPClient()
        mockClient.mockResponse = HTTPResponse(
            statusCode: 200,
            headers: [
                "DAV": "1, 2, addressbook",
                "Allow": "OPTIONS, GET, HEAD, POST, PUT, DELETE, PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK, REPORT",
                "Server": "Nextcloud/25.0.3"
            ],
            data: Data()
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detectCapabilities(
            baseURL: URL(string: "https://cloud.example.com")!
        )

        XCTAssertTrue(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsAddressbookQuery)
        XCTAssertEqual(capabilities.serverType, .nextcloud)
    }

    func testDetectSchedulingSupport() async throws {
        let mockClient = MockHTTPClient()
        mockClient.mockResponse = HTTPResponse(
            statusCode: 200,
            headers: [
                "DAV": "1, 2, 3, calendar-access, calendar-schedule",
                "Allow": "OPTIONS, GET, HEAD, POST, PUT, DELETE, PROPFIND, PROPPATCH, MKCOL, COPY, MOVE, LOCK, UNLOCK, REPORT",
                "Server": "SOGo/5.5.0"
            ],
            data: Data()
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detectCapabilities(
            baseURL: URL(string: "https://sogo.example.com")!
        )

        XCTAssertTrue(capabilities.supportsScheduling)
        XCTAssertEqual(capabilities.serverType, .sogo)
    }

    func testParseSupportedMethods() async throws {
        let mockClient = MockHTTPClient()
        mockClient.mockResponse = HTTPResponse(
            statusCode: 200,
            headers: [
                "DAV": "1, 2",
                "Allow": "OPTIONS, GET, PUT, DELETE, PROPFIND, REPORT",
                "Server": "Generic"
            ],
            data: Data()
        )

        let detector = ServerDetector(httpClient: mockClient)
        let capabilities = try await detector.detectCapabilities(
            baseURL: URL(string: "https://dav.example.com")!
        )

        XCTAssertTrue(capabilities.supportedMethods.contains("OPTIONS"))
        XCTAssertTrue(capabilities.supportedMethods.contains("GET"))
        XCTAssertTrue(capabilities.supportedMethods.contains("PUT"))
        XCTAssertTrue(capabilities.supportedMethods.contains("DELETE"))
        XCTAssertTrue(capabilities.supportedMethods.contains("PROPFIND"))
        XCTAssertTrue(capabilities.supportedMethods.contains("REPORT"))
    }
}

// MARK: - Mock HTTP Client

class MockHTTPClient: HTTPClient {
    var mockResponse: HTTPResponse?
    var lastRequest: (method: HTTPMethod, url: URL, headers: [String: String]?, body: Data?)?

    func request(
        _ method: HTTPMethod,
        url: URL,
        headers: [String: String]?,
        body: Data?
    ) async throws -> HTTPResponse {
        lastRequest = (method, url, headers, body)

        if let mockResponse = mockResponse {
            return mockResponse
        }

        // Default response
        return HTTPResponse(
            statusCode: 200,
            headers: [:],
            data: Data()
        )
    }
}
