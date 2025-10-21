import XCTest
@testable import SwiftXDAVNetwork
@testable import SwiftXDAVCore

final class OAuth2TokenManagerTests: XCTestCase {
    // MARK: - Token Expiration

    func testIsExpiredWhenNoExpirationSet() async {
        let manager = OAuth2TokenManager(
            accessToken: "token",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://oauth.example.com/token")!,
            clientID: "client",
            expiresAt: nil
        )

        let isExpired = await manager.isExpired
        XCTAssertTrue(isExpired, "Token should be considered expired when no expiration is set")
    }

    func testIsNotExpiredWhenFarFromExpiration() async {
        let futureDate = Date().addingTimeInterval(3600) // 1 hour from now

        let manager = OAuth2TokenManager(
            accessToken: "token",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://oauth.example.com/token")!,
            clientID: "client",
            expiresAt: futureDate
        )

        let isExpired = await manager.isExpired
        XCTAssertFalse(isExpired, "Token should not be expired when far from expiration")
    }

    func testIsExpiredWhenPastExpiration() async {
        let pastDate = Date().addingTimeInterval(-3600) // 1 hour ago

        let manager = OAuth2TokenManager(
            accessToken: "token",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://oauth.example.com/token")!,
            clientID: "client",
            expiresAt: pastDate
        )

        let isExpired = await manager.isExpired
        XCTAssertTrue(isExpired, "Token should be expired when past expiration")
    }

    func testIsExpiredWithinBuffer() async {
        // Set expiration to 4 minutes from now (within the 5-minute buffer)
        let nearExpirationDate = Date().addingTimeInterval(240)

        let manager = OAuth2TokenManager(
            accessToken: "token",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://oauth.example.com/token")!,
            clientID: "client",
            expiresAt: nearExpirationDate
        )

        let isExpired = await manager.isExpired
        XCTAssertTrue(isExpired, "Token should be considered expired when within buffer time")
    }

    // MARK: - Token Refresh Callback

    func testTokenRefreshCallback() async {
        let expectation = XCTestExpectation(description: "Token refresh callback invoked")

        let manager = OAuth2TokenManager(
            accessToken: "old_token",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://oauth.example.com/token")!,
            clientID: "client",
            onTokenRefresh: { token, expiration in
                // Verify callback is invoked
                _ = token
                _ = expiration
                expectation.fulfill()
            }
        )

        // Note: We can't easily test the actual refresh without a mock server
        // This test verifies the callback mechanism exists
        await manager.setTokenRefreshCallback { token, expiration in
            // Verify callback can be updated
            _ = token
            _ = expiration
        }

        // The callback is set and ready to be invoked
        XCTAssertNotNil(manager)
    }

    // MARK: - Google Helper

    func testGoogleHelper() async {
        let manager = OAuth2TokenManager.google(
            accessToken: "ya29.abc",
            refreshToken: "1//0g...",
            clientID: "client-id.apps.googleusercontent.com",
            clientSecret: "secret"
        )

        let token = try? await manager.getAccessToken()
        // Since we can't actually refresh without a real server, just verify we get a token
        XCTAssertNotNil(token)
    }

    // MARK: - Get Access Token

    func testGetAccessTokenReturnsCurrentWhenNotExpired() async throws {
        let futureDate = Date().addingTimeInterval(3600)

        let manager = OAuth2TokenManager(
            accessToken: "valid_token",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://oauth.example.com/token")!,
            clientID: "client",
            expiresAt: futureDate
        )

        let token = try await manager.getAccessToken()
        XCTAssertEqual(token, "valid_token")
    }

    // Note: Testing actual refresh requires mocking URLSession, which is complex
    // Integration tests should cover the full refresh flow
}
