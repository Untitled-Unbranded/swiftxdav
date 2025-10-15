import XCTest
@testable import SwiftXDAVNetwork
@testable import SwiftXDAVCore

final class OAuth2TokenManagerTests: XCTestCase {
    // MARK: - Token Response Tests

    func testTokenResponseDecoding() throws {
        let json = """
        {
            "access_token": "new-access-token",
            "refresh_token": "new-refresh-token",
            "expires_in": 3600,
            "token_type": "Bearer"
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OAuth2TokenManager.TokenResponse.self, from: data)

        XCTAssertEqual(response.accessToken, "new-access-token")
        XCTAssertEqual(response.refreshToken, "new-refresh-token")
        XCTAssertEqual(response.expiresIn, 3600)
        XCTAssertEqual(response.tokenType, "Bearer")
    }

    func testTokenResponseDecodingWithoutRefreshToken() throws {
        let json = """
        {
            "access_token": "new-access-token",
            "expires_in": 3600
        }
        """

        let data = json.data(using: .utf8)!
        let response = try JSONDecoder().decode(OAuth2TokenManager.TokenResponse.self, from: data)

        XCTAssertEqual(response.accessToken, "new-access-token")
        XCTAssertNil(response.refreshToken)
        XCTAssertEqual(response.expiresIn, 3600)
    }

    // MARK: - Token Manager Tests

    func testGetValidAccessTokenWhenNotExpired() async throws {
        let tokenManager = OAuth2TokenManager(
            accessToken: "current-token",
            refreshToken: "refresh-token",
            expiresIn: 3600, // 1 hour from now
            tokenURL: URL(string: "https://example.com/token")!,
            clientID: "client-id",
            clientSecret: "client-secret"
        )

        let token = try await tokenManager.getValidAccessToken()
        XCTAssertEqual(token, "current-token")
    }

    func testManualTokenUpdate() async throws {
        let tokenManager = OAuth2TokenManager(
            accessToken: "old-token",
            refreshToken: "old-refresh",
            tokenURL: URL(string: "https://example.com/token")!,
            clientID: "client-id"
        )

        await tokenManager.updateToken(
            accessToken: "new-token",
            refreshToken: "new-refresh",
            expiresIn: 3600
        )

        let token = try await tokenManager.getValidAccessToken()
        XCTAssertEqual(token, "new-token")
    }

    func testTokenManagerWithoutRefreshToken() async {
        let tokenManager = OAuth2TokenManager(
            accessToken: "access-token",
            refreshToken: nil, // No refresh token
            expiresIn: -100, // Already expired
            tokenURL: URL(string: "https://example.com/token")!,
            clientID: "client-id"
        )

        do {
            _ = try await tokenManager.getValidAccessToken()
            XCTFail("Should throw authenticationRequired error")
        } catch let error as SwiftXDAVError {
            if case .authenticationRequired = error {
                // Expected
            } else {
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }

    // MARK: - OAuth2HTTPClient Tests

    func testOAuth2HTTPClient() async throws {
        let mockClient = MockHTTPClient()
        let tokenManager = OAuth2TokenManager(
            accessToken: "test-token",
            refreshToken: nil,
            expiresIn: 3600,
            tokenURL: URL(string: "https://example.com/token")!,
            clientID: "client-id"
        )

        let oauthClient = OAuth2HTTPClient(baseClient: mockClient, tokenManager: tokenManager)

        let testURL = URL(string: "https://example.com/test")!
        await mockClient.addResponse(
            for: testURL,
            statusCode: 200,
            headers: [:],
            body: "Success"
        )

        let response = try await oauthClient.request(
            .get,
            url: testURL,
            headers: nil,
            body: nil
        )

        XCTAssertEqual(response.statusCode, 200)

        // Verify Authorization header was added
        let requestLog = await mockClient.requestLog
        XCTAssertEqual(requestLog.count, 1)
        let (_, _, headers, _) = requestLog[0]
        XCTAssertEqual(headers?["Authorization"], "Bearer test-token")
    }
}

// MARK: - Mock HTTP Client for Testing

actor MockHTTPClient: HTTPClient {
    var responses: [URL: HTTPResponse] = [:]
    var requestLog: [(HTTPMethod, URL, [String: String]?, Data?)] = []

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
        requestLog.append((method, url, headers, body))

        guard let response = responses[url] else {
            throw SwiftXDAVError.notFound
        }

        return response
    }
}
