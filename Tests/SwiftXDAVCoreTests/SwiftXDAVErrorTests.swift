import XCTest
@testable import SwiftXDAVCore

/// Tests for SwiftXDAVError
final class SwiftXDAVErrorTests: XCTestCase {

    // MARK: - Error Description Tests

    func testNetworkErrorDescription() {
        let underlyingError = NSError(domain: "TestDomain", code: 123, userInfo: [NSLocalizedDescriptionKey: "Connection failed"])
        let error = SwiftXDAVError.networkError(underlying: underlyingError)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Network error"))
        XCTAssertTrue(error.errorDescription!.contains("Connection failed"))
    }

    func testInvalidResponseDescription() {
        let error = SwiftXDAVError.invalidResponse(statusCode: 404, body: "Not Found")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("404"))
    }

    func testParsingErrorDescription() {
        let error = SwiftXDAVError.parsingError("Invalid XML structure")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Parsing error"))
        XCTAssertTrue(error.errorDescription!.contains("Invalid XML structure"))
    }

    func testAuthenticationRequiredDescription() {
        let error = SwiftXDAVError.authenticationRequired

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Authentication"))
    }

    func testUnauthorizedDescription() {
        let error = SwiftXDAVError.unauthorized

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Unauthorized"))
    }

    func testForbiddenDescription() {
        let error = SwiftXDAVError.forbidden

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("forbidden"))
    }

    func testNotFoundDescription() {
        let error = SwiftXDAVError.notFound

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("not found"))
    }

    func testConflictDescription() {
        let error = SwiftXDAVError.conflict("Resource already exists")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Conflict"))
        XCTAssertTrue(error.errorDescription!.contains("Resource already exists"))
    }

    func testPreconditionFailedDescription() {
        let error = SwiftXDAVError.preconditionFailed(etag: "\"abc123\"")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Precondition failed"))
        XCTAssertTrue(error.errorDescription!.contains("abc123"))
    }

    func testPreconditionFailedWithoutETag() {
        let error = SwiftXDAVError.preconditionFailed(etag: nil)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Precondition failed"))
    }

    func testServerErrorDescription() {
        let error = SwiftXDAVError.serverError(statusCode: 500, message: "Internal server error")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Server error"))
        XCTAssertTrue(error.errorDescription!.contains("500"))
        XCTAssertTrue(error.errorDescription!.contains("Internal server error"))
    }

    func testServerErrorWithoutMessage() {
        let error = SwiftXDAVError.serverError(statusCode: 503, message: nil)

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("503"))
    }

    func testUnsupportedOperationDescription() {
        let error = SwiftXDAVError.unsupportedOperation("MKCALENDAR not supported")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Unsupported operation"))
        XCTAssertTrue(error.errorDescription!.contains("MKCALENDAR"))
    }

    func testInvalidDataDescription() {
        let error = SwiftXDAVError.invalidData("Invalid iCalendar format")

        XCTAssertNotNil(error.errorDescription)
        XCTAssertTrue(error.errorDescription!.contains("Invalid data"))
        XCTAssertTrue(error.errorDescription!.contains("iCalendar"))
    }

    // MARK: - Failure Reason Tests

    func testNetworkErrorFailureReason() {
        let underlyingError = NSError(domain: "TestDomain", code: 123)
        let error = SwiftXDAVError.networkError(underlying: underlyingError)

        XCTAssertNotNil(error.failureReason)
    }

    func testInvalidResponseFailureReason() {
        let error = SwiftXDAVError.invalidResponse(statusCode: 404, body: "Not Found")

        XCTAssertNotNil(error.failureReason)
        XCTAssertEqual(error.failureReason, "Not Found")
    }

    func testParsingErrorFailureReason() {
        let error = SwiftXDAVError.parsingError("Invalid XML")

        XCTAssertNotNil(error.failureReason)
    }

    // MARK: - Equatable Tests

    func testNetworkErrorEquality() {
        let error1 = SwiftXDAVError.networkError(underlying: NSError(domain: "Test", code: 1))
        let error2 = SwiftXDAVError.networkError(underlying: NSError(domain: "Test", code: 2))

        // All network errors are considered equal (can't compare underlying errors)
        XCTAssertEqual(error1, error2)
    }

    func testInvalidResponseEquality() {
        let error1 = SwiftXDAVError.invalidResponse(statusCode: 404, body: "Not Found")
        let error2 = SwiftXDAVError.invalidResponse(statusCode: 404, body: "Not Found")
        let error3 = SwiftXDAVError.invalidResponse(statusCode: 500, body: "Server Error")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testParsingErrorEquality() {
        let error1 = SwiftXDAVError.parsingError("Invalid XML")
        let error2 = SwiftXDAVError.parsingError("Invalid XML")
        let error3 = SwiftXDAVError.parsingError("Different message")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testAuthenticationErrorsEquality() {
        let error1 = SwiftXDAVError.authenticationRequired
        let error2 = SwiftXDAVError.authenticationRequired
        let error3 = SwiftXDAVError.unauthorized

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testConflictErrorEquality() {
        let error1 = SwiftXDAVError.conflict("Resource exists")
        let error2 = SwiftXDAVError.conflict("Resource exists")
        let error3 = SwiftXDAVError.conflict("Different conflict")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testPreconditionFailedEquality() {
        let error1 = SwiftXDAVError.preconditionFailed(etag: "\"abc123\"")
        let error2 = SwiftXDAVError.preconditionFailed(etag: "\"abc123\"")
        let error3 = SwiftXDAVError.preconditionFailed(etag: "\"xyz789\"")
        let error4 = SwiftXDAVError.preconditionFailed(etag: nil)

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error1, error4)
    }

    func testServerErrorEquality() {
        let error1 = SwiftXDAVError.serverError(statusCode: 500, message: "Internal error")
        let error2 = SwiftXDAVError.serverError(statusCode: 500, message: "Internal error")
        let error3 = SwiftXDAVError.serverError(statusCode: 503, message: "Service unavailable")

        XCTAssertEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
    }

    func testDifferentErrorTypesNotEqual() {
        let error1 = SwiftXDAVError.notFound
        let error2 = SwiftXDAVError.unauthorized
        let error3 = SwiftXDAVError.parsingError("Test")

        XCTAssertNotEqual(error1, error2)
        XCTAssertNotEqual(error1, error3)
        XCTAssertNotEqual(error2, error3)
    }

    // MARK: - Sendable Conformance Test

    func testErrorIsSendable() async {
        // Test that errors can be passed across actor boundaries
        actor ErrorHolder {
            var error: SwiftXDAVError?

            func setError(_ error: SwiftXDAVError) {
                self.error = error
            }

            func getError() -> SwiftXDAVError? {
                error
            }
        }

        let holder = ErrorHolder()
        let error = SwiftXDAVError.notFound

        await holder.setError(error)
        let retrieved = await holder.getError()

        XCTAssertEqual(retrieved, error)
    }
}
