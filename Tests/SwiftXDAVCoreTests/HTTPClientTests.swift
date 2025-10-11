import XCTest
@testable import SwiftXDAVCore

/// Tests for HTTPMethod and HTTPResponse types
final class HTTPClientTests: XCTestCase {

    // MARK: - HTTPMethod Tests

    func testHTTPMethodRawValues() {
        XCTAssertEqual(HTTPMethod.get.rawValue, "GET")
        XCTAssertEqual(HTTPMethod.post.rawValue, "POST")
        XCTAssertEqual(HTTPMethod.put.rawValue, "PUT")
        XCTAssertEqual(HTTPMethod.delete.rawValue, "DELETE")
        XCTAssertEqual(HTTPMethod.options.rawValue, "OPTIONS")
        XCTAssertEqual(HTTPMethod.propfind.rawValue, "PROPFIND")
        XCTAssertEqual(HTTPMethod.proppatch.rawValue, "PROPPATCH")
        XCTAssertEqual(HTTPMethod.mkcol.rawValue, "MKCOL")
        XCTAssertEqual(HTTPMethod.copy.rawValue, "COPY")
        XCTAssertEqual(HTTPMethod.move.rawValue, "MOVE")
        XCTAssertEqual(HTTPMethod.lock.rawValue, "LOCK")
        XCTAssertEqual(HTTPMethod.unlock.rawValue, "UNLOCK")
        XCTAssertEqual(HTTPMethod.report.rawValue, "REPORT")
    }

    func testHTTPMethodEquality() {
        XCTAssertEqual(HTTPMethod.get, HTTPMethod.get)
        XCTAssertNotEqual(HTTPMethod.get, HTTPMethod.post)
        XCTAssertEqual(HTTPMethod.propfind, HTTPMethod.propfind)
    }

    func testHTTPMethodFromRawValue() {
        XCTAssertEqual(HTTPMethod(rawValue: "GET"), .get)
        XCTAssertEqual(HTTPMethod(rawValue: "PROPFIND"), .propfind)
        XCTAssertEqual(HTTPMethod(rawValue: "REPORT"), .report)
        XCTAssertNil(HTTPMethod(rawValue: "INVALID"))
    }

    func testHTTPMethodSendable() async {
        // Test that methods can be passed across actor boundaries
        actor MethodHolder {
            var method: HTTPMethod?

            func setMethod(_ method: HTTPMethod) {
                self.method = method
            }

            func getMethod() -> HTTPMethod? {
                method
            }
        }

        let holder = MethodHolder()
        let method = HTTPMethod.propfind

        await holder.setMethod(method)
        let retrieved = await holder.getMethod()

        XCTAssertEqual(retrieved, method)
    }

    // MARK: - HTTPResponse Tests

    func testHTTPResponseInitialization() {
        let data = "Test response".data(using: .utf8)!
        let headers = ["Content-Type": "text/plain", "ETag": "\"abc123\""]
        let response = HTTPResponse(
            statusCode: 200,
            headers: headers,
            data: data
        )

        XCTAssertEqual(response.statusCode, 200)
        XCTAssertEqual(response.headers["Content-Type"], "text/plain")
        XCTAssertEqual(response.headers["ETag"], "\"abc123\"")
        XCTAssertEqual(response.data, data)
    }

    func testHTTPResponseBodyString() {
        let bodyText = "Test response body"
        let data = bodyText.data(using: .utf8)!
        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            data: data
        )

        XCTAssertEqual(response.bodyString, bodyText)
    }

    func testHTTPResponseBodyStringWithInvalidUTF8() {
        // Create invalid UTF-8 data
        let invalidData = Data([0xFF, 0xFE, 0xFD])
        let response = HTTPResponse(
            statusCode: 200,
            headers: [:],
            data: invalidData
        )

        XCTAssertNil(response.bodyString)
    }

    func testHTTPResponseBodyStringEmpty() {
        let response = HTTPResponse(
            statusCode: 204,
            headers: [:],
            data: Data()
        )

        XCTAssertEqual(response.bodyString, "")
    }

    func testHTTPResponseIsSuccess() {
        // Success codes (2xx)
        XCTAssertTrue(HTTPResponse(statusCode: 200, headers: [:], data: Data()).isSuccess)
        XCTAssertTrue(HTTPResponse(statusCode: 201, headers: [:], data: Data()).isSuccess)
        XCTAssertTrue(HTTPResponse(statusCode: 204, headers: [:], data: Data()).isSuccess)
        XCTAssertTrue(HTTPResponse(statusCode: 207, headers: [:], data: Data()).isSuccess)

        // Non-success codes
        XCTAssertFalse(HTTPResponse(statusCode: 199, headers: [:], data: Data()).isSuccess)
        XCTAssertFalse(HTTPResponse(statusCode: 300, headers: [:], data: Data()).isSuccess)
        XCTAssertFalse(HTTPResponse(statusCode: 400, headers: [:], data: Data()).isSuccess)
        XCTAssertFalse(HTTPResponse(statusCode: 404, headers: [:], data: Data()).isSuccess)
        XCTAssertFalse(HTTPResponse(statusCode: 500, headers: [:], data: Data()).isSuccess)
    }

    func testHTTPResponseIsMultiStatus() {
        XCTAssertTrue(HTTPResponse(statusCode: 207, headers: [:], data: Data()).isMultiStatus)

        // Other codes should not be multi-status
        XCTAssertFalse(HTTPResponse(statusCode: 200, headers: [:], data: Data()).isMultiStatus)
        XCTAssertFalse(HTTPResponse(statusCode: 404, headers: [:], data: Data()).isMultiStatus)
    }

    func testHTTPResponseEquality() {
        let data1 = "Test".data(using: .utf8)!
        let data2 = "Test".data(using: .utf8)!
        let data3 = "Different".data(using: .utf8)!

        let response1 = HTTPResponse(statusCode: 200, headers: ["ETag": "\"123\""], data: data1)
        let response2 = HTTPResponse(statusCode: 200, headers: ["ETag": "\"123\""], data: data2)
        let response3 = HTTPResponse(statusCode: 200, headers: ["ETag": "\"456\""], data: data1)
        let response4 = HTTPResponse(statusCode: 404, headers: ["ETag": "\"123\""], data: data1)
        let response5 = HTTPResponse(statusCode: 200, headers: ["ETag": "\"123\""], data: data3)

        XCTAssertEqual(response1, response2)
        XCTAssertNotEqual(response1, response3)
        XCTAssertNotEqual(response1, response4)
        XCTAssertNotEqual(response1, response5)
    }

    func testHTTPResponseSendable() async {
        // Test that responses can be passed across actor boundaries
        actor ResponseHolder {
            var response: HTTPResponse?

            func setResponse(_ response: HTTPResponse) {
                self.response = response
            }

            func getResponse() -> HTTPResponse? {
                response
            }
        }

        let holder = ResponseHolder()
        let response = HTTPResponse(statusCode: 200, headers: [:], data: Data())

        await holder.setResponse(response)
        let retrieved = await holder.getResponse()

        XCTAssertEqual(retrieved, response)
    }

    // MARK: - Real-World Scenarios

    func testHTTPResponseWithWebDAVMultiStatus() {
        let xmlBody = """
        <?xml version="1.0" encoding="utf-8"?>
        <multistatus xmlns="DAV:">
            <response>
                <href>/calendar/event1.ics</href>
                <propstat>
                    <status>HTTP/1.1 200 OK</status>
                </propstat>
            </response>
        </multistatus>
        """
        let data = xmlBody.data(using: .utf8)!
        let response = HTTPResponse(
            statusCode: 207,
            headers: ["Content-Type": "application/xml; charset=utf-8"],
            data: data
        )

        XCTAssertTrue(response.isMultiStatus)
        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.headers["Content-Type"], "application/xml; charset=utf-8")
        XCTAssertNotNil(response.bodyString)
        XCTAssertTrue(response.bodyString!.contains("multistatus"))
    }

    func testHTTPResponseWithCalendarData() {
        let icalBody = """
        BEGIN:VCALENDAR
        VERSION:2.0
        PRODID:-//Test//Test//EN
        BEGIN:VEVENT
        UID:test-event-123
        SUMMARY:Test Event
        END:VEVENT
        END:VCALENDAR
        """
        let data = icalBody.data(using: .utf8)!
        let response = HTTPResponse(
            statusCode: 200,
            headers: [
                "Content-Type": "text/calendar; charset=utf-8",
                "ETag": "\"abc123\""
            ],
            data: data
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.headers["Content-Type"], "text/calendar; charset=utf-8")
        XCTAssertEqual(response.headers["ETag"], "\"abc123\"")
        XCTAssertNotNil(response.bodyString)
        XCTAssertTrue(response.bodyString!.contains("BEGIN:VCALENDAR"))
    }

    func testHTTPResponseWithError() {
        let errorBody = "Resource not found"
        let data = errorBody.data(using: .utf8)!
        let response = HTTPResponse(
            statusCode: 404,
            headers: ["Content-Type": "text/plain"],
            data: data
        )

        XCTAssertFalse(response.isSuccess)
        XCTAssertFalse(response.isMultiStatus)
        XCTAssertEqual(response.bodyString, errorBody)
    }

    func testHTTPResponseWithNoContent() {
        let response = HTTPResponse(
            statusCode: 204,
            headers: [:],
            data: Data()
        )

        XCTAssertTrue(response.isSuccess)
        XCTAssertEqual(response.bodyString, "")
        XCTAssertEqual(response.data.count, 0)
    }
}
