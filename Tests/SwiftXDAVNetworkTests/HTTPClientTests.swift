import XCTest
@testable import SwiftXDAVNetwork
@testable import SwiftXDAVCore

final class HTTPClientTests: XCTestCase {

    // MARK: - Mock HTTP Client

    actor MockHTTPClient: HTTPClient {
        var lastMethod: SwiftXDAVCore.HTTPMethod?
        var lastURL: URL?
        var lastHeaders: [String: String]?
        var lastBody: Data?
        var responseToReturn: HTTPResponse?
        var errorToThrow: Error?

        func request(
            _ method: SwiftXDAVCore.HTTPMethod,
            url: URL,
            headers: [String: String]?,
            body: Data?
        ) async throws -> HTTPResponse {
            // Store the request details
            self.lastMethod = method
            self.lastURL = url
            self.lastHeaders = headers
            self.lastBody = body

            // Throw error if configured
            if let error = errorToThrow {
                throw error
            }

            // Return configured response
            if let response = responseToReturn {
                return response
            }

            // Default response
            return HTTPResponse(
                statusCode: 200,
                headers: [:],
                data: Data()
            )
        }

        func reset() {
            lastMethod = nil
            lastURL = nil
            lastHeaders = nil
            lastBody = nil
            responseToReturn = nil
            errorToThrow = nil
        }

        func setResponse(_ response: HTTPResponse) {
            responseToReturn = response
        }

        func setError(_ error: Error) {
            errorToThrow = error
        }
    }

    // MARK: - AuthenticatedHTTPClient Tests

    func testAuthenticatedClientAppliesBasicAuth() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.basic(username: "user", password: "pass")
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        _ = try await authenticatedClient.request(.get, url: url, headers: nil, body: nil)

        let headers = await mockClient.lastHeaders
        XCTAssertNotNil(headers)
        XCTAssertNotNil(headers?["Authorization"])
        XCTAssertTrue(headers?["Authorization"]?.hasPrefix("Basic ") ?? false)
    }

    func testAuthenticatedClientAppliesBearerToken() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.bearer(token: "test-token")
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        _ = try await authenticatedClient.request(.get, url: url, headers: nil, body: nil)

        let headers = await mockClient.lastHeaders
        XCTAssertEqual(headers?["Authorization"], "Bearer test-token")
    }

    func testAuthenticatedClientMergesHeaders() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.basic(username: "user", password: "pass")
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        let customHeaders = [
            "Content-Type": "application/json",
            "Accept": "application/json"
        ]

        _ = try await authenticatedClient.request(.post, url: url, headers: customHeaders, body: nil)

        let headers = await mockClient.lastHeaders
        XCTAssertNotNil(headers?["Authorization"])
        XCTAssertEqual(headers?["Content-Type"], "application/json")
        XCTAssertEqual(headers?["Accept"], "application/json")
    }

    func testAuthenticatedClientOverwritesAuthorizationHeader() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.bearer(token: "correct-token")
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        let customHeaders = ["Authorization": "Bearer wrong-token"]

        _ = try await authenticatedClient.request(.get, url: url, headers: customHeaders, body: nil)

        let headers = await mockClient.lastHeaders
        XCTAssertEqual(headers?["Authorization"], "Bearer correct-token")
    }

    func testAuthenticatedClientForwardsRequestDetails() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.none
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        let body = "test data".data(using: .utf8)

        _ = try await authenticatedClient.request(.put, url: url, headers: nil, body: body)

        let method = await mockClient.lastMethod
        let requestURL = await mockClient.lastURL
        let requestBody = await mockClient.lastBody

        XCTAssertEqual(method, .put)
        XCTAssertEqual(requestURL, url)
        XCTAssertEqual(requestBody, body)
    }

    func testAuthenticatedClientPropagatesErrors() async throws {
        let mockClient = MockHTTPClient()
        let expectedError = SwiftXDAVError.unauthorized
        await mockClient.reset()
        await mockClient.setError(expectedError)

        let auth = Authentication.basic(username: "user", password: "pass")
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!

        do {
            _ = try await authenticatedClient.request(.get, url: url, headers: nil, body: nil)
            XCTFail("Should have thrown an error")
        } catch let error as SwiftXDAVError {
            XCTAssertEqual(error, expectedError)
        } catch {
            XCTFail("Unexpected error type: \(error)")
        }
    }

    func testAuthenticatedClientReturnsResponse() async throws {
        let mockClient = MockHTTPClient()
        let expectedResponse = HTTPResponse(
            statusCode: 201,
            headers: ["Content-Type": "application/json"],
            data: "response data".data(using: .utf8)!
        )
        await mockClient.setResponse(expectedResponse)

        let auth = Authentication.basic(username: "user", password: "pass")
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        let response = try await authenticatedClient.request(.post, url: url, headers: nil, body: nil)

        XCTAssertEqual(response.statusCode, 201)
        XCTAssertEqual(response.headers["Content-Type"], "application/json")
        XCTAssertEqual(response.data, "response data".data(using: .utf8))
    }

    // MARK: - Convenience Constructor Tests

    func testICloudConvenienceConstructor() {
        let client = AuthenticatedHTTPClient.iCloud(
            username: "user@icloud.com",
            appSpecificPassword: "abcd-efgh-ijkl-mnop"
        )

        // Just verify it constructs without errors
        XCTAssertNotNil(client)
    }

    func testGoogleConvenienceConstructor() {
        let client = AuthenticatedHTTPClient.google(
            accessToken: "ya29.access",
            refreshToken: "1//refresh"
        )

        XCTAssertNotNil(client)
    }

    func testBasicAuthConvenienceConstructor() {
        let client = AuthenticatedHTTPClient.basicAuth(
            username: "user",
            password: "pass"
        )

        XCTAssertNotNil(client)
    }

    func testBearerTokenConvenienceConstructor() {
        let client = AuthenticatedHTTPClient.bearerToken("test-token")

        XCTAssertNotNil(client)
    }

    // MARK: - Integration with Different Auth Types

    func testAuthenticatedClientWithNoAuth() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.none
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        _ = try await authenticatedClient.request(.get, url: url, headers: nil, body: nil)

        let headers = await mockClient.lastHeaders
        XCTAssertNil(headers?["Authorization"])
    }

    func testAuthenticatedClientWithOAuth2() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.oauth2(
            accessToken: "access-token",
            refreshToken: "refresh-token",
            tokenURL: URL(string: "https://oauth.example.com/token")
        )
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        let url = URL(string: "https://example.com/test")!
        _ = try await authenticatedClient.request(.get, url: url, headers: nil, body: nil)

        let headers = await mockClient.lastHeaders
        XCTAssertEqual(headers?["Authorization"], "Bearer access-token")
    }

    // MARK: - All HTTP Methods Test

    func testAuthenticatedClientSupportsAllHTTPMethods() async throws {
        let methods: [SwiftXDAVCore.HTTPMethod] = [
            .get, .post, .put, .delete, .options,
            .propfind, .proppatch, .mkcol, .copy, .move,
            .lock, .unlock, .report
        ]

        for method in methods {
            let mockClient = MockHTTPClient()
            await mockClient.reset()

            let auth = Authentication.basic(username: "user", password: "pass")
            let authenticatedClient = AuthenticatedHTTPClient(
                baseClient: mockClient,
                authentication: auth
            )

            let url = URL(string: "https://example.com/test")!
            _ = try await authenticatedClient.request(method, url: url, headers: nil, body: nil)

            let requestedMethod = await mockClient.lastMethod
            XCTAssertEqual(requestedMethod, method, "Failed for method: \(method)")
        }
    }

    // MARK: - Concurrency Tests

    func testAuthenticatedClientIsConcurrencySafe() async throws {
        let mockClient = MockHTTPClient()
        let auth = Authentication.bearer(token: "test-token")
        let authenticatedClient = AuthenticatedHTTPClient(
            baseClient: mockClient,
            authentication: auth
        )

        // Make multiple concurrent requests
        let url = URL(string: "https://example.com/test")!

        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask {
                    do {
                        _ = try await authenticatedClient.request(.get, url: url, headers: nil, body: nil)
                    } catch {
                        XCTFail("Request failed: \(error)")
                    }
                }
            }
        }

        // All requests should complete without errors
    }
}
