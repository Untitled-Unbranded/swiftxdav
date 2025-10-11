import XCTest
@testable import SwiftXDAVCore

/// Tests for DAVProperty and property name constants
final class DAVPropertyTests: XCTestCase {

    // MARK: - DAVProperty Tests

    func testDAVPropertyInitialization() {
        let property = DAVProperty(
            namespace: "DAV:",
            name: "displayname",
            value: "My Calendar"
        )

        XCTAssertEqual(property.namespace, "DAV:")
        XCTAssertEqual(property.name, "displayname")
        XCTAssertEqual(property.value, "My Calendar")
    }

    func testDAVPropertyInitializationWithoutValue() {
        let property = DAVProperty(
            namespace: "DAV:",
            name: "displayname"
        )

        XCTAssertEqual(property.namespace, "DAV:")
        XCTAssertEqual(property.name, "displayname")
        XCTAssertNil(property.value)
    }

    func testDAVPropertyEquality() {
        let property1 = DAVProperty(namespace: "DAV:", name: "displayname", value: "Test")
        let property2 = DAVProperty(namespace: "DAV:", name: "displayname", value: "Test")
        let property3 = DAVProperty(namespace: "DAV:", name: "displayname", value: "Different")
        let property4 = DAVProperty(namespace: "DAV:", name: "getetag", value: "Test")

        XCTAssertEqual(property1, property2)
        XCTAssertNotEqual(property1, property3)
        XCTAssertNotEqual(property1, property4)
    }

    func testDAVPropertyHashable() {
        let property1 = DAVProperty(namespace: "DAV:", name: "displayname", value: "Test")
        let property2 = DAVProperty(namespace: "DAV:", name: "displayname", value: "Test")

        var set = Set<DAVProperty>()
        set.insert(property1)
        set.insert(property2)

        // Both properties are equal, so set should only have one element
        XCTAssertEqual(set.count, 1)
    }

    func testDAVPropertySendable() async {
        // Test that properties can be passed across actor boundaries
        actor PropertyHolder {
            var property: DAVProperty?

            func setProperty(_ property: DAVProperty) {
                self.property = property
            }

            func getProperty() -> DAVProperty? {
                property
            }
        }

        let holder = PropertyHolder()
        let property = DAVProperty(namespace: "DAV:", name: "displayname", value: "Test")

        await holder.setProperty(property)
        let retrieved = await holder.getProperty()

        XCTAssertEqual(retrieved, property)
    }

    // MARK: - Standard Property Names Tests

    func testDAVPropertyNameResourceType() {
        let property = DAVPropertyName.resourceType

        XCTAssertEqual(property.namespace, "DAV:")
        XCTAssertEqual(property.name, "resourcetype")
        XCTAssertNil(property.value)
    }

    func testDAVPropertyNameDisplayName() {
        let property = DAVPropertyName.displayName

        XCTAssertEqual(property.namespace, "DAV:")
        XCTAssertEqual(property.name, "displayname")
    }

    func testDAVPropertyNameGetETag() {
        let property = DAVPropertyName.getETag

        XCTAssertEqual(property.namespace, "DAV:")
        XCTAssertEqual(property.name, "getetag")
    }

    func testDAVPropertyNameGetContentType() {
        let property = DAVPropertyName.getContentType

        XCTAssertEqual(property.namespace, "DAV:")
        XCTAssertEqual(property.name, "getcontenttype")
    }

    func testDAVPropertyNameCurrentUserPrincipal() {
        let property = DAVPropertyName.currentUserPrincipal

        XCTAssertEqual(property.namespace, "DAV:")
        XCTAssertEqual(property.name, "current-user-principal")
    }

    // MARK: - CalDAV Property Names Tests

    func testCalDAVPropertyNameCalendarHomeSet() {
        let property = CalDAVPropertyName.calendarHomeSet

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:caldav")
        XCTAssertEqual(property.name, "calendar-home-set")
    }

    func testCalDAVPropertyNameSupportedCalendarComponentSet() {
        let property = CalDAVPropertyName.supportedCalendarComponentSet

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:caldav")
        XCTAssertEqual(property.name, "supported-calendar-component-set")
    }

    func testCalDAVPropertyNameCalendarData() {
        let property = CalDAVPropertyName.calendarData

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:caldav")
        XCTAssertEqual(property.name, "calendar-data")
    }

    func testCalDAVPropertyNameCalendarDescription() {
        let property = CalDAVPropertyName.calendarDescription

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:caldav")
        XCTAssertEqual(property.name, "calendar-description")
    }

    func testCalDAVPropertyNameCalendarTimezone() {
        let property = CalDAVPropertyName.calendarTimezone

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:caldav")
        XCTAssertEqual(property.name, "calendar-timezone")
    }

    // MARK: - CardDAV Property Names Tests

    func testCardDAVPropertyNameAddressbookHomeSet() {
        let property = CardDAVPropertyName.addressbookHomeSet

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:carddav")
        XCTAssertEqual(property.name, "addressbook-home-set")
    }

    func testCardDAVPropertyNameAddressData() {
        let property = CardDAVPropertyName.addressData

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:carddav")
        XCTAssertEqual(property.name, "address-data")
    }

    func testCardDAVPropertyNameAddressbookDescription() {
        let property = CardDAVPropertyName.addressbookDescription

        XCTAssertEqual(property.namespace, "urn:ietf:params:xml:ns:carddav")
        XCTAssertEqual(property.name, "addressbook-description")
    }

    // MARK: - Apple Property Names Tests

    func testApplePropertyNameGetCTag() {
        let property = ApplePropertyName.getctag

        XCTAssertEqual(property.namespace, "http://calendarserver.org/ns/")
        XCTAssertEqual(property.name, "getctag")
    }

    func testApplePropertyNameCalendarColor() {
        let property = ApplePropertyName.calendarColor

        XCTAssertEqual(property.namespace, "http://apple.com/ns/ical/")
        XCTAssertEqual(property.name, "calendar-color")
    }

    func testApplePropertyNameCalendarOrder() {
        let property = ApplePropertyName.calendarOrder

        XCTAssertEqual(property.namespace, "http://apple.com/ns/ical/")
        XCTAssertEqual(property.name, "calendar-order")
    }

    // MARK: - Property Collections Tests

    func testPropertyArrayContainsCheck() {
        let properties = [
            DAVPropertyName.displayName,
            DAVPropertyName.getETag,
            DAVPropertyName.resourceType
        ]

        XCTAssertTrue(properties.contains(DAVPropertyName.displayName))
        XCTAssertTrue(properties.contains(DAVPropertyName.getETag))
        XCTAssertFalse(properties.contains(DAVPropertyName.getContentType))
    }

    func testPropertyDictionaryUsage() {
        var propertyValues: [DAVProperty: String] = [:]

        propertyValues[DAVPropertyName.displayName] = "My Calendar"
        propertyValues[DAVPropertyName.getETag] = "\"abc123\""

        XCTAssertEqual(propertyValues[DAVPropertyName.displayName], "My Calendar")
        XCTAssertEqual(propertyValues[DAVPropertyName.getETag], "\"abc123\"")
        XCTAssertNil(propertyValues[DAVPropertyName.resourceType])
    }
}
