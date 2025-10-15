import Foundation
import SwiftXDAVCore

/// CardDAV-specific property definitions (RFC 6352)
///
/// These properties extend the WebDAV property set with address book-specific properties.
///
/// ## Common CardDAV Properties
///
/// - `addressbookHomeSet`: Location of the user's address book collections
/// - `addressbookDescription`: Human-readable description of an address book
/// - `supportedAddressData`: Which media types/versions are supported
/// - `maxResourceSize`: Maximum size of a vCard resource
/// - `addressData`: Actual vCard data in REPORT responses
///
public enum CardDAVPropertyName {
    // CardDAV namespace
    public static let carddavNamespace = "urn:ietf:params:xml:ns:carddav"
    public static let calendarServerNamespace = "http://calendarserver.org/ns/"
    public static let appleNamespace = "http://apple.com/ns/ical/"

    // Address book discovery properties
    public static let addressbookHomeSet = DAVProperty(
        namespace: carddavNamespace,
        name: "addressbook-home-set"
    )

    public static let principalAddress = DAVProperty(
        namespace: carddavNamespace,
        name: "principal-address"
    )

    // Address book properties
    public static let addressbookDescription = DAVProperty(
        namespace: carddavNamespace,
        name: "addressbook-description"
    )

    public static let supportedAddressData = DAVProperty(
        namespace: carddavNamespace,
        name: "supported-address-data"
    )

    public static let maxResourceSize = DAVProperty(
        namespace: carddavNamespace,
        name: "max-resource-size"
    )

    // Address data property (used in REPORT responses)
    public static let addressData = DAVProperty(
        namespace: carddavNamespace,
        name: "address-data"
    )

    // CalendarServer.org extensions (used by many servers)
    public static let getctag = DAVProperty(
        namespace: calendarServerNamespace,
        name: "getctag"
    )

    // Apple extensions
    public static let addressBookColor = DAVProperty(
        namespace: appleNamespace,
        name: "addressbook-color"
    )
}
