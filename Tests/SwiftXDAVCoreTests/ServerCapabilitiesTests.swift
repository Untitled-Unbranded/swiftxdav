import XCTest
@testable import SwiftXDAVCore

final class ServerCapabilitiesTests: XCTestCase {
    // MARK: - Server Type Detection Tests

    func testDetectICloudFromURL() {
        let url = URL(string: "https://caldav.icloud.com")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: nil)
        XCTAssertEqual(serverType, .iCloud)
    }

    func testDetectGoogleFromURL() {
        let url = URL(string: "https://apidata.googleusercontent.com/caldav/v2/")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: nil)
        XCTAssertEqual(serverType, .google)
    }

    func testDetectNextcloudFromURL() {
        let url = URL(string: "https://myserver.nextcloud.com")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: nil)
        XCTAssertEqual(serverType, .nextcloud)
    }

    func testDetectNextcloudFromProduct() {
        let url = URL(string: "https://example.com")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: "Nextcloud/25.0.0")
        XCTAssertEqual(serverType, .nextcloud)
    }

    func testDetectRadicaleFromProduct() {
        let url = URL(string: "https://example.com")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: "Radicale/3.1.8")
        XCTAssertEqual(serverType, .radicale)
    }

    func testDetectSOGoFromProduct() {
        let url = URL(string: "https://example.com")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: "SOGo/5.5.0")
        XCTAssertEqual(serverType, .sogo)
    }

    func testDetectBaikalFromProduct() {
        let url = URL(string: "https://example.com")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: "Baikal/0.9.3 sabre/dav/4.3.1")
        XCTAssertEqual(serverType, .baikal)
    }

    func testDetectGenericServer() {
        let url = URL(string: "https://example.com")!
        let serverType = ServerCapabilities.detectServerType(from: url, serverProduct: "Unknown Server")
        XCTAssertEqual(serverType, .generic)
    }

    // MARK: - DAV Class Parsing Tests

    func testParseDavClasses() {
        let davHeader = "1, 2, 3, calendar-access, calendar-schedule, addressbook"
        let classes = ServerCapabilities.parseDavClasses(from: davHeader)

        XCTAssertEqual(classes.count, 6)
        XCTAssertTrue(classes.contains("1"))
        XCTAssertTrue(classes.contains("2"))
        XCTAssertTrue(classes.contains("3"))
        XCTAssertTrue(classes.contains("calendar-access"))
        XCTAssertTrue(classes.contains("calendar-schedule"))
        XCTAssertTrue(classes.contains("addressbook"))
    }

    func testParseDavClassesWithSpaces() {
        let davHeader = " 1 ,  2  ,   calendar-access   "
        let classes = ServerCapabilities.parseDavClasses(from: davHeader)

        XCTAssertEqual(classes.count, 3)
        XCTAssertTrue(classes.contains("1"))
        XCTAssertTrue(classes.contains("2"))
        XCTAssertTrue(classes.contains("calendar-access"))
    }

    func testParseEmptyDavClasses() {
        let davHeader = ""
        let classes = ServerCapabilities.parseDavClasses(from: davHeader)

        XCTAssertTrue(classes.isEmpty)
    }

    // MARK: - Capabilities Tests

    func testServerCapabilitiesInitialization() {
        let capabilities = ServerCapabilities(
            serverType: .iCloud,
            serverProduct: "iCloud CalDAV Server",
            supportsCalDAV: true,
            supportsCardDAV: true,
            supportsSyncToken: true,
            supportsScheduling: true,
            supportsExtendedMKCOL: false,
            davClasses: ["1", "2", "3", "calendar-access"],
            supportsAppleExtensions: true,
            supportsCalendarServerExtensions: true
        )

        XCTAssertEqual(capabilities.serverType, .iCloud)
        XCTAssertEqual(capabilities.serverProduct, "iCloud CalDAV Server")
        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertTrue(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsSyncToken)
        XCTAssertTrue(capabilities.supportsScheduling)
        XCTAssertFalse(capabilities.supportsExtendedMKCOL)
        XCTAssertTrue(capabilities.supportsAppleExtensions)
        XCTAssertTrue(capabilities.supportsCalendarServerExtensions)
    }

    func testSupportsDavClass() {
        let capabilities = ServerCapabilities(
            davClasses: ["1", "2", "calendar-access", "addressbook"]
        )

        XCTAssertTrue(capabilities.supportsDavClass("1"))
        XCTAssertTrue(capabilities.supportsDavClass("calendar-access"))
        XCTAssertTrue(capabilities.supportsDavClass("addressbook"))
        XCTAssertFalse(capabilities.supportsDavClass("sync-collection"))
    }

    func testServerCapabilitiesEquality() {
        let caps1 = ServerCapabilities(
            serverType: .iCloud,
            supportsCalDAV: true,
            davClasses: ["1", "2"]
        )

        let caps2 = ServerCapabilities(
            serverType: .iCloud,
            supportsCalDAV: true,
            davClasses: ["1", "2"]
        )

        let caps3 = ServerCapabilities(
            serverType: .google,
            supportsCalDAV: true,
            davClasses: ["1", "2"]
        )

        XCTAssertEqual(caps1, caps2)
        XCTAssertNotEqual(caps1, caps3)
    }

    // MARK: - Realistic Server Configuration Tests

    func testiCloudCapabilities() {
        let capabilities = ServerCapabilities(
            serverType: .iCloud,
            serverProduct: "CalendarServer/10.0",
            supportsCalDAV: true,
            supportsCardDAV: true,
            supportsSyncToken: true,
            supportsScheduling: true,
            supportsExtendedMKCOL: true,
            davClasses: ["1", "2", "3", "calendar-access", "calendar-schedule", "addressbook", "sync-collection"],
            supportsAppleExtensions: true,
            supportsCalendarServerExtensions: true
        )

        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertTrue(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsSyncToken)
        XCTAssertTrue(capabilities.supportsScheduling)
        XCTAssertTrue(capabilities.supportsAppleExtensions)
    }

    func testGoogleCapabilities() {
        let capabilities = ServerCapabilities(
            serverType: .google,
            serverProduct: "Google Calendar",
            supportsCalDAV: true,
            supportsCardDAV: false, // Google CardDAV is limited
            supportsSyncToken: true,
            supportsScheduling: false, // Limited scheduling support
            davClasses: ["1", "calendar-access", "sync-collection"],
            supportsAppleExtensions: false,
            supportsCalendarServerExtensions: false
        )

        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertFalse(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsSyncToken)
        XCTAssertFalse(capabilities.supportsScheduling)
        XCTAssertFalse(capabilities.supportsAppleExtensions)
    }

    func testNextcloudCapabilities() {
        let capabilities = ServerCapabilities(
            serverType: .nextcloud,
            serverProduct: "Nextcloud/25.0.0",
            supportsCalDAV: true,
            supportsCardDAV: true,
            supportsSyncToken: true,
            supportsScheduling: true,
            davClasses: ["1", "2", "3", "calendar-access", "calendar-schedule", "addressbook", "sync-collection"],
            supportsAppleExtensions: false,
            supportsCalendarServerExtensions: true
        )

        XCTAssertTrue(capabilities.supportsCalDAV)
        XCTAssertTrue(capabilities.supportsCardDAV)
        XCTAssertTrue(capabilities.supportsSyncToken)
        XCTAssertTrue(capabilities.supportsScheduling)
    }
}
