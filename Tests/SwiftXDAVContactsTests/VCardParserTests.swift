import XCTest
@testable import SwiftXDAVContacts
@testable import SwiftXDAVCore

final class VCardParserTests: XCTestCase {
    var parser: VCardParser!

    override func setUp() async throws {
        parser = VCardParser()
    }

    // MARK: - Basic Parsing Tests

    func testParseBasicVCard40() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        N:Doe;John;;;
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.version, .v4_0)
        XCTAssertEqual(vcard.formattedName, "John Doe")
        XCTAssertEqual(vcard.name?.familyNames, ["Doe"])
        XCTAssertEqual(vcard.name?.givenNames, ["John"])
    }

    func testParseBasicVCard30() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:3.0
        FN:Jane Smith
        N:Smith;Jane;;;
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.version, .v3_0)
        XCTAssertEqual(vcard.formattedName, "Jane Smith")
        XCTAssertEqual(vcard.name?.familyNames, ["Smith"])
        XCTAssertEqual(vcard.name?.givenNames, ["Jane"])
    }

    func testParseFullStructuredName() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:Dr. John Q. Public Jr.
        N:Public;John;Quinlan;Dr.;Jr.
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.name?.familyNames, ["Public"])
        XCTAssertEqual(vcard.name?.givenNames, ["John"])
        XCTAssertEqual(vcard.name?.additionalNames, ["Quinlan"])
        XCTAssertEqual(vcard.name?.honorificPrefixes, ["Dr."])
        XCTAssertEqual(vcard.name?.honorificSuffixes, ["Jr."])
    }

    // MARK: - Communication Properties

    func testParseTelephone() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        TEL;TYPE=work,voice:+1-555-555-1234
        TEL;TYPE=home:+1-555-555-5678
        TEL;TYPE=cell;PREF=1:+1-555-555-9999
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.telephones.count, 3)

        let workPhone = vcard.telephones[0]
        XCTAssertEqual(workPhone.value, "+1-555-555-1234")
        XCTAssertTrue(workPhone.types.contains(.work))
        XCTAssertTrue(workPhone.types.contains(.voice))

        let homePhone = vcard.telephones[1]
        XCTAssertEqual(homePhone.value, "+1-555-555-5678")
        XCTAssertTrue(homePhone.types.contains(.home))

        let cellPhone = vcard.telephones[2]
        XCTAssertEqual(cellPhone.value, "+1-555-555-9999")
        XCTAssertTrue(cellPhone.types.contains(.cell))
        XCTAssertEqual(cellPhone.preference, 1)
    }

    func testParseEmail() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        EMAIL;TYPE=work:john@work.com
        EMAIL;TYPE=home;PREF=1:john@home.com
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.emails.count, 2)

        let workEmail = vcard.emails[0]
        XCTAssertEqual(workEmail.value, "john@work.com")
        XCTAssertTrue(workEmail.types.contains(.work))

        let homeEmail = vcard.emails[1]
        XCTAssertEqual(homeEmail.value, "john@home.com")
        XCTAssertTrue(homeEmail.types.contains(.home))
        XCTAssertEqual(homeEmail.preference, 1)
    }

    // MARK: - Address Properties

    func testParseAddress() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        ADR;TYPE=work:;;123 Main St;Springfield;IL;62701;USA
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.addresses.count, 1)

        let address = vcard.addresses[0]
        XCTAssertNil(address.poBox)
        XCTAssertNil(address.extendedAddress)
        XCTAssertEqual(address.streetAddress, "123 Main St")
        XCTAssertEqual(address.locality, "Springfield")
        XCTAssertEqual(address.region, "IL")
        XCTAssertEqual(address.postalCode, "62701")
        XCTAssertEqual(address.country, "USA")
        XCTAssertTrue(address.types.contains(.work))
    }

    func testParseComplexAddress() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        ADR;TYPE=home:PO Box 123;Suite 456;789 Oak Ave;Anytown;CA;90210;USA
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        let address = vcard.addresses[0]
        XCTAssertEqual(address.poBox, "PO Box 123")
        XCTAssertEqual(address.extendedAddress, "Suite 456")
        XCTAssertEqual(address.streetAddress, "789 Oak Ave")
        XCTAssertEqual(address.locality, "Anytown")
        XCTAssertEqual(address.region, "CA")
        XCTAssertEqual(address.postalCode, "90210")
        XCTAssertEqual(address.country, "USA")
    }

    // MARK: - Identification Properties

    func testParsePhoto() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        PHOTO:http://example.com/photo.jpg
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertNotNil(vcard.photo)
        if case .uri(let url) = vcard.photo?.mediaType {
            XCTAssertEqual(url.absoluteString, "http://example.com/photo.jpg")
        } else {
            XCTFail("Expected URI media type")
        }
    }

    func testParsePhotoWithData() async throws {
        let testData = "test data".data(using: .utf8)!
        let base64 = testData.base64EncodedString()
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        PHOTO:data:image/jpeg;base64,\(base64)
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertNotNil(vcard.photo)
        if case .data(let data, let mediaType) = vcard.photo?.mediaType {
            XCTAssertEqual(data, testData)
            XCTAssertEqual(mediaType, "image/jpeg")
        } else {
            XCTFail("Expected data media type")
        }
    }

    func testParseBirthday() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        BDAY:19850415
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertNotNil(vcard.birthday)
        if case .date(let date) = vcard.birthday {
            let calendar = Calendar(identifier: .gregorian)
            let components = calendar.dateComponents([.year, .month, .day], from: date)
            XCTAssertEqual(components.year, 1985)
            XCTAssertEqual(components.month, 4)
            XCTAssertEqual(components.day, 15)
        } else {
            XCTFail("Expected date value")
        }
    }

    func testParseGender() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        GENDER:M
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertNotNil(vcard.gender)
        XCTAssertEqual(vcard.gender?.sex, .male)
    }

    func testParseGenderWithIdentity() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        GENDER:M;Male
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.gender?.sex, .male)
        XCTAssertEqual(vcard.gender?.identity, "Male")
    }

    // MARK: - Organizational Properties

    func testParseOrganization() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        ORG:ABC Corporation;Marketing Department;Sales Team
        TITLE:Senior Manager
        ROLE:Team Lead
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.organization?.name, "ABC Corporation")
        XCTAssertEqual(vcard.organization?.units, ["Marketing Department", "Sales Team"])
        XCTAssertEqual(vcard.title, "Senior Manager")
        XCTAssertEqual(vcard.role, "Team Lead")
    }

    // MARK: - Geographical Properties

    func testParseGeographicPosition() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        GEO:geo:37.386013,-122.082932
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertNotNil(vcard.geo)
        XCTAssertEqual(vcard.geo!.latitude, 37.386013, accuracy: 0.000001)
        XCTAssertEqual(vcard.geo!.longitude, -122.082932, accuracy: 0.000001)
    }

    func testParseTimezone() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        TZ:America/New_York
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.timezone, "America/New_York")
    }

    // MARK: - Metadata Properties

    func testParseCategories() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        CATEGORIES:Family,Friends,Colleagues
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.categories, ["Family", "Friends", "Colleagues"])
    }

    func testParseNote() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        NOTE:Met at conference in 2023
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.note, "Met at conference in 2023")
    }

    func testParseUID() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.uid, "urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1")
    }

    // MARK: - Line Folding Tests

    func testParseLineFolding() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        NOTE:This is a very long note that has been folded across multiple line
         s to comply with the 75 character limit specified in RFC 6350.
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.note, "This is a very long note that has been folded across multiple lines to comply with the 75 character limit specified in RFC 6350.")
    }

    // MARK: - Escaping Tests

    func testParseEscapedText() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John\\, Jr.
        NOTE:Line 1\\nLine 2\\nLine 3
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.formattedName, "John, Jr.")
        XCTAssertEqual(vcard.note, "Line 1\nLine 2\nLine 3")
    }

    // MARK: - Extended Properties

    func testParseExtendedProperties() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        FN:John Doe
        X-CUSTOM-FIELD:Custom Value
        X-ANOTHER-FIELD:Another Value
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        XCTAssertEqual(vcard.extendedProperties["X-CUSTOM-FIELD"], "Custom Value")
        XCTAssertEqual(vcard.extendedProperties["X-ANOTHER-FIELD"], "Another Value")
    }

    // MARK: - Error Handling Tests

    func testParseMissingVersion() async throws {
        let vcardText = """
        BEGIN:VCARD
        FN:John Doe
        END:VCARD
        """

        do {
            _ = try await parser.parse(vcardText.data(using: .utf8)!)
            XCTFail("Should throw error for missing VERSION")
        } catch {
            // Expected
        }
    }

    func testParseMissingFormattedName() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        N:Doe;John;;;
        END:VCARD
        """

        do {
            _ = try await parser.parse(vcardText.data(using: .utf8)!)
            XCTFail("Should throw error for missing FN")
        } catch {
            // Expected
        }
    }

    func testParseUnsupportedVersion() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:2.1
        FN:John Doe
        END:VCARD
        """

        do {
            _ = try await parser.parse(vcardText.data(using: .utf8)!)
            XCTFail("Should throw error for unsupported version")
        } catch {
            // Expected
        }
    }

    // MARK: - Real-World Example

    func testParseCompleteVCard() async throws {
        let vcardText = """
        BEGIN:VCARD
        VERSION:4.0
        UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1
        FN:Dr. John Q. Public Jr.
        N:Public;John;Quinlan;Dr.;Jr.
        NICKNAME:Johnny
        BDAY:19850415
        GENDER:M
        EMAIL;TYPE=work;PREF=1:john.public@example.com
        EMAIL;TYPE=home:john@home.com
        TEL;TYPE=work,voice:+1-555-555-1234
        TEL;TYPE=home:+1-555-555-5678
        TEL;TYPE=cell:+1-555-555-9999
        ADR;TYPE=work:;;123 Main St;Springfield;IL;62701;USA
        ADR;TYPE=home:;;456 Oak Ave;Anytown;CA;90210;USA
        ORG:ABC Corporation;Engineering Department
        TITLE:Senior Software Engineer
        ROLE:Team Lead
        URL:https://example.com
        CATEGORIES:Work,Development
        NOTE:Important contact
        REV:20231215T120000Z
        END:VCARD
        """

        let vcard = try await parser.parse(vcardText.data(using: .utf8)!)

        // Verify all properties
        XCTAssertEqual(vcard.version, .v4_0)
        XCTAssertEqual(vcard.uid, "urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1")
        XCTAssertEqual(vcard.formattedName, "Dr. John Q. Public Jr.")
        XCTAssertEqual(vcard.name?.familyNames, ["Public"])
        XCTAssertEqual(vcard.name?.givenNames, ["John"])
        XCTAssertEqual(vcard.nicknames, ["Johnny"])
        XCTAssertEqual(vcard.gender?.sex, .male)
        XCTAssertEqual(vcard.emails.count, 2)
        XCTAssertEqual(vcard.telephones.count, 3)
        XCTAssertEqual(vcard.addresses.count, 2)
        XCTAssertEqual(vcard.organization?.name, "ABC Corporation")
        XCTAssertEqual(vcard.title, "Senior Software Engineer")
        XCTAssertEqual(vcard.categories, ["Work", "Development"])
        XCTAssertEqual(vcard.note, "Important contact")
        XCTAssertNotNil(vcard.revision)
    }
}
