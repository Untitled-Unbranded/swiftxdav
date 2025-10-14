import XCTest
@testable import SwiftXDAVNetwork

final class AuthenticationTests: XCTestCase {

    // MARK: - None Authentication Tests

    func testNoneAuthentication() {
        let auth = Authentication.none
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertTrue(headers.isEmpty, "None authentication should not add headers")
    }

    func testNoneAuthenticationDescription() {
        let auth = Authentication.none
        XCTAssertEqual(auth.description, "Authentication.none")
    }

    // MARK: - Basic Authentication Tests

    func testBasicAuthentication() {
        let auth = Authentication.basic(username: "user", password: "pass")
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertNotNil(headers["Authorization"])
        XCTAssertTrue(headers["Authorization"]!.hasPrefix("Basic "))

        // Verify the encoding
        let base64Part = headers["Authorization"]!.replacingOccurrences(of: "Basic ", with: "")
        guard let decodedData = Data(base64Encoded: base64Part) else {
            XCTFail("Failed to decode base64")
            return
        }

        let decodedString = String(data: decodedData, encoding: .utf8)
        XCTAssertEqual(decodedString, "user:pass")
    }

    func testBasicAuthenticationWithSpecialCharacters() {
        let auth = Authentication.basic(username: "user@example.com", password: "p@ss:word")
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertNotNil(headers["Authorization"])
        XCTAssertTrue(headers["Authorization"]!.hasPrefix("Basic "))
    }

    func testBasicAuthenticationWithUnicodePassword() {
        let auth = Authentication.basic(username: "user", password: "пароль🔐")
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertNotNil(headers["Authorization"])
        XCTAssertTrue(headers["Authorization"]!.hasPrefix("Basic "))
    }

    func testBasicAuthenticationDescription() {
        let auth = Authentication.basic(username: "testuser", password: "secret123")
        let description = auth.description

        XCTAssertTrue(description.contains("testuser"))
        XCTAssertFalse(description.contains("secret123"))
        XCTAssertTrue(description.contains("***"))
    }

    // MARK: - Bearer Token Tests

    func testBearerAuthentication() {
        let auth = Authentication.bearer(token: "abc123")
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertEqual(headers["Authorization"], "Bearer abc123")
    }

    func testBearerAuthenticationWithLongToken() {
        let token = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJzdWIiOiIxMjM0NTY3ODkwIiwibmFtZSI6IkpvaG4gRG9lIiwiaWF0IjoxNTE2MjM5MDIyfQ.SflKxwRJSMeKKF2QT4fwpMeJf36POk6yJV_adQssw5c"
        let auth = Authentication.bearer(token: token)
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertEqual(headers["Authorization"], "Bearer \(token)")
    }

    func testBearerAuthenticationDescription() {
        let auth = Authentication.bearer(token: "secret-token")
        let description = auth.description

        XCTAssertFalse(description.contains("secret-token"))
        XCTAssertTrue(description.contains("***"))
    }

    // MARK: - OAuth 2.0 Tests

    func testOAuth2Authentication() {
        let auth = Authentication.oauth2(
            accessToken: "access123",
            refreshToken: "refresh456",
            tokenURL: URL(string: "https://oauth.example.com/token")
        )
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertEqual(headers["Authorization"], "Bearer access123")
    }

    func testOAuth2AuthenticationWithoutRefreshToken() {
        let auth = Authentication.oauth2(
            accessToken: "access123",
            refreshToken: nil,
            tokenURL: nil
        )
        var headers: [String: String] = [:]

        auth.apply(to: &headers)

        XCTAssertEqual(headers["Authorization"], "Bearer access123")
    }

    func testOAuth2AuthenticationDescription() {
        let auth = Authentication.oauth2(
            accessToken: "access123",
            refreshToken: "refresh456",
            tokenURL: URL(string: "https://oauth.example.com/token")
        )
        let description = auth.description

        XCTAssertFalse(description.contains("access123"))
        XCTAssertFalse(description.contains("refresh456"))
        XCTAssertTrue(description.contains("***"))
    }

    // MARK: - Convenience Constructor Tests

    func testICloudConvenienceConstructor() {
        let auth = Authentication.iCloud(
            username: "user@icloud.com",
            appSpecificPassword: "abcd-efgh-ijkl-mnop"
        )

        guard case .basic(let username, let password) = auth else {
            XCTFail("iCloud authentication should use basic auth")
            return
        }

        XCTAssertEqual(username, "user@icloud.com")
        XCTAssertEqual(password, "abcd-efgh-ijkl-mnop")
    }

    func testGoogleConvenienceConstructor() {
        let auth = Authentication.google(
            accessToken: "ya29.access",
            refreshToken: "1//refresh"
        )

        guard case .oauth2(let accessToken, let refreshToken, let tokenURL) = auth else {
            XCTFail("Google authentication should use OAuth 2.0")
            return
        }

        XCTAssertEqual(accessToken, "ya29.access")
        XCTAssertEqual(refreshToken, "1//refresh")
        XCTAssertEqual(tokenURL?.absoluteString, "https://oauth2.googleapis.com/token")
    }

    func testGoogleConvenienceConstructorWithoutRefreshToken() {
        let auth = Authentication.google(accessToken: "ya29.access")

        guard case .oauth2(let accessToken, let refreshToken, _) = auth else {
            XCTFail("Google authentication should use OAuth 2.0")
            return
        }

        XCTAssertEqual(accessToken, "ya29.access")
        XCTAssertNil(refreshToken)
    }

    // MARK: - Equatable Tests

    func testAuthenticationEquality() {
        let auth1 = Authentication.basic(username: "user", password: "pass")
        let auth2 = Authentication.basic(username: "user", password: "pass")
        let auth3 = Authentication.basic(username: "user", password: "different")

        XCTAssertEqual(auth1, auth2)
        XCTAssertNotEqual(auth1, auth3)
    }

    func testAuthenticationEqualityDifferentTypes() {
        let basicAuth = Authentication.basic(username: "user", password: "pass")
        let bearerAuth = Authentication.bearer(token: "token")
        let noneAuth = Authentication.none

        XCTAssertNotEqual(basicAuth, bearerAuth)
        XCTAssertNotEqual(basicAuth, noneAuth)
        XCTAssertNotEqual(bearerAuth, noneAuth)
    }

    func testOAuth2Equality() {
        let auth1 = Authentication.oauth2(
            accessToken: "access",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://example.com")
        )
        let auth2 = Authentication.oauth2(
            accessToken: "access",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://example.com")
        )
        let auth3 = Authentication.oauth2(
            accessToken: "different",
            refreshToken: "refresh",
            tokenURL: URL(string: "https://example.com")
        )

        XCTAssertEqual(auth1, auth2)
        XCTAssertNotEqual(auth1, auth3)
    }

    // MARK: - Header Merging Tests

    func testAuthenticationOverwritesExistingAuthHeader() {
        let auth = Authentication.bearer(token: "newtoken")
        var headers = ["Authorization": "Bearer oldtoken", "Content-Type": "application/json"]

        auth.apply(to: &headers)

        XCTAssertEqual(headers["Authorization"], "Bearer newtoken")
        XCTAssertEqual(headers["Content-Type"], "application/json")
    }

    func testAuthenticationPreservesOtherHeaders() {
        let auth = Authentication.basic(username: "user", password: "pass")
        var headers = [
            "Content-Type": "application/xml",
            "Accept": "text/xml",
            "User-Agent": "SwiftXDAV/1.0"
        ]

        auth.apply(to: &headers)

        XCTAssertNotNil(headers["Authorization"])
        XCTAssertEqual(headers["Content-Type"], "application/xml")
        XCTAssertEqual(headers["Accept"], "text/xml")
        XCTAssertEqual(headers["User-Agent"], "SwiftXDAV/1.0")
        XCTAssertEqual(headers.count, 4)
    }

    // MARK: - Sendable Tests

    func testAuthenticationIsSendable() {
        // This test verifies that Authentication conforms to Sendable
        // by using it in an async context
        Task {
            let auth = Authentication.basic(username: "user", password: "pass")
            var headers: [String: String] = [:]
            auth.apply(to: &headers)
            XCTAssertNotNil(headers["Authorization"])
        }
    }
}
