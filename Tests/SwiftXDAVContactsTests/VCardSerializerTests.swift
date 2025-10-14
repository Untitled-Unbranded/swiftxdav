import XCTest
@testable import SwiftXDAVContacts
@testable import SwiftXDAVCore

final class VCardSerializerTests: XCTestCase {
    var serializer: VCardSerializer!

    override func setUp() async throws {
        serializer = VCardSerializer()
    }

    // MARK: - Basic Serialization Tests

    func testSerializeBasicVCard40() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            name: StructuredName(familyNames: ["Doe"], givenNames: ["John"])
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("BEGIN:VCARD"))
        XCTAssertTrue(text.contains("VERSION:4.0"))
        XCTAssertTrue(text.contains("FN:John Doe"))
        XCTAssertTrue(text.contains("N:Doe;John;;;"))
        XCTAssertTrue(text.contains("END:VCARD"))
    }

    func testSerializeBasicVCard30() async throws {
        let vcard = VCard(
            version: .v3_0,
            formattedName: "Jane Smith",
            name: StructuredName(familyNames: ["Smith"], givenNames: ["Jane"])
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("VERSION:3.0"))
        XCTAssertTrue(text.contains("FN:Jane Smith"))
        XCTAssertTrue(text.contains("N:Smith;Jane;;;"))
    }

    func testSerializeFullStructuredName() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "Dr. John Q. Public Jr.",
            name: StructuredName(
                familyNames: ["Public"],
                givenNames: ["John"],
                additionalNames: ["Quinlan"],
                honorificPrefixes: ["Dr."],
                honorificSuffixes: ["Jr."]
            )
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("N:Public;John;Quinlan;Dr.;Jr."))
    }

    // MARK: - Communication Properties

    func testSerializeTelephone() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            telephones: [
                Telephone(value: "+1-555-555-1234", types: [.work, .voice]),
                Telephone(value: "+1-555-555-5678", types: [.home]),
                Telephone(value: "+1-555-555-9999", types: [.cell], preference: 1)
            ]
        )

        let text = try await serializer.serializeToString(vcard)

        // Check that all telephone numbers are present with their types
        XCTAssertTrue(text.contains("TEL") && text.contains("work") && text.contains("voice") && text.contains("+1-555-555-1234"))
        XCTAssertTrue(text.contains("TEL") && text.contains("home") && text.contains("+1-555-555-5678"))
        XCTAssertTrue(text.contains("TEL") && text.contains("cell") && text.contains("+1-555-555-9999") && text.contains("PREF=1"))
    }

    func testSerializeEmail() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            emails: [
                Email(value: "john@work.com", types: [.work]),
                Email(value: "john@home.com", types: [.home], preference: 1)
            ]
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("EMAIL;TYPE=work:john@work.com"))
        XCTAssertTrue(text.contains("EMAIL;PREF=1;TYPE=home:john@home.com"))
    }

    // MARK: - Address Properties

    func testSerializeAddress() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            addresses: [
                Address(
                    streetAddress: "123 Main St",
                    locality: "Springfield",
                    region: "IL",
                    postalCode: "62701",
                    country: "USA",
                    types: [.work]
                )
            ]
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("ADR;TYPE=work:;;123 Main St;Springfield;IL;62701;USA"))
    }

    func testSerializeComplexAddress() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            addresses: [
                Address(
                    poBox: "PO Box 123",
                    extendedAddress: "Suite 456",
                    streetAddress: "789 Oak Ave",
                    locality: "Anytown",
                    region: "CA",
                    postalCode: "90210",
                    country: "USA",
                    types: [.home]
                )
            ]
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("ADR;TYPE=home:PO Box 123;Suite 456;789 Oak Ave;Anytown;CA;90210;USA"))
    }

    // MARK: - Identification Properties

    func testSerializePhotoURI() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            photo: MediaProperty(mediaType: .uri(URL(string: "http://example.com/photo.jpg")!))
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("PHOTO:http://example.com/photo.jpg"))
    }

    func testSerializePhotoData() async throws {
        let testData = "test data".data(using: .utf8)!
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            photo: MediaProperty(mediaType: .data(testData, mediaType: "image/jpeg"))
        )

        let text = try await serializer.serializeToString(vcard)
        let base64 = testData.base64EncodedString()

        XCTAssertTrue(text.contains("PHOTO;MEDIATYPE=image/jpeg:data:image/jpeg;base64,\(base64)"))
    }

    func testSerializeBirthday() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let date = formatter.date(from: "19850415")!

        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            birthday: .date(date)
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("BDAY:19850415"))
    }

    func testSerializeGender() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            gender: Gender(sex: .male)
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("GENDER:M"))
    }

    func testSerializeGenderWithIdentity() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            gender: Gender(sex: .male, identity: "Male")
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("GENDER:M;Male"))
    }

    // MARK: - Organizational Properties

    func testSerializeOrganization() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            title: "Senior Manager",
            role: "Team Lead",
            organization: Organization(
                name: "ABC Corporation",
                units: ["Marketing Department", "Sales Team"]
            )
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("ORG:ABC Corporation;Marketing Department;Sales Team"))
        XCTAssertTrue(text.contains("TITLE:Senior Manager"))
        XCTAssertTrue(text.contains("ROLE:Team Lead"))
    }

    // MARK: - Geographical Properties

    func testSerializeGeographicPosition40() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            geo: GeographicPosition(latitude: 37.386013, longitude: -122.082932)
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("GEO:geo:37.386013,-122.082932"))
    }

    func testSerializeGeographicPosition30() async throws {
        let vcard = VCard(
            version: .v3_0,
            formattedName: "John Doe",
            geo: GeographicPosition(latitude: 37.386013, longitude: -122.082932)
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("GEO:37.386013;-122.082932"))
    }

    func testSerializeTimezone() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            timezone: "America/New_York"
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("TZ:America/New_York"))
    }

    // MARK: - Metadata Properties

    func testSerializeCategories() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            categories: ["Family", "Friends", "Colleagues"]
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("CATEGORIES:Family,Friends,Colleagues"))
    }

    func testSerializeNote() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            note: "Met at conference in 2023"
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("NOTE:Met at conference in 2023"))
    }

    func testSerializeUID() async throws {
        let vcard = VCard(
            version: .v4_0,
            uid: "urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1",
            formattedName: "John Doe"
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("UID:urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1"))
    }

    // MARK: - Escaping Tests

    func testSerializeEscapedText() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "John, Jr.",
            note: "Line 1\nLine 2\nLine 3"
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("FN:John\\, Jr."))
        XCTAssertTrue(text.contains("NOTE:Line 1\\nLine 2\\nLine 3"))
    }

    func testSerializeSpecialCharacters() async throws {
        let vcard = VCard(
            version: .v4_0,
            formattedName: "Test; Name, with: special\\ chars"
        )

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("FN:Test\\; Name\\, with: special\\\\ chars"))
    }

    // MARK: - Extended Properties

    func testSerializeExtendedProperties() async throws {
        var vcard = VCard(
            version: .v4_0,
            formattedName: "John Doe"
        )
        vcard.extendedProperties["X-CUSTOM-FIELD"] = "Custom Value"
        vcard.extendedProperties["X-ANOTHER-FIELD"] = "Another Value"

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.contains("X-ANOTHER-FIELD:Another Value"))
        XCTAssertTrue(text.contains("X-CUSTOM-FIELD:Custom Value"))
    }

    // MARK: - Round-trip Tests

    func testRoundTripBasicVCard() async throws {
        let original = VCard(
            version: .v4_0,
            formattedName: "John Doe",
            name: StructuredName(familyNames: ["Doe"], givenNames: ["John"]),
            telephones: [Telephone(value: "+1-555-555-1234", types: [.work])],
            emails: [Email(value: "john@example.com", types: [.work])]
        )

        let data = try await serializer.serialize(original)
        let parser = VCardParser()
        let parsed = try await parser.parse(data)

        XCTAssertEqual(parsed.version, original.version)
        XCTAssertEqual(parsed.formattedName, original.formattedName)
        XCTAssertEqual(parsed.name?.familyNames, original.name?.familyNames)
        XCTAssertEqual(parsed.name?.givenNames, original.name?.givenNames)
        XCTAssertEqual(parsed.emails.count, original.emails.count)
        XCTAssertEqual(parsed.telephones.count, original.telephones.count)
    }

    func testRoundTripComplexVCard() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let birthday = formatter.date(from: "19850415")!

        let original = VCard(
            version: .v4_0,
            uid: "urn:uuid:test-123",
            formattedName: "Dr. John Q. Public Jr.",
            name: StructuredName(
                familyNames: ["Public"],
                givenNames: ["John"],
                additionalNames: ["Quinlan"],
                honorificPrefixes: ["Dr."],
                honorificSuffixes: ["Jr."]
            ),
            nicknames: ["Johnny"],
            birthday: .date(birthday),
            gender: Gender(sex: .male),
            telephones: [
                Telephone(value: "+1-555-555-1234", types: [.work, .voice]),
                Telephone(value: "+1-555-555-5678", types: [.home])
            ],
            emails: [
                Email(value: "john@work.com", types: [.work], preference: 1),
                Email(value: "john@home.com", types: [.home])
            ],
            addresses: [
                Address(
                    streetAddress: "123 Main St",
                    locality: "Springfield",
                    region: "IL",
                    postalCode: "62701",
                    country: "USA",
                    types: [.work]
                )
            ],
            title: "Senior Software Engineer",
            role: "Team Lead",
            organization: Organization(name: "ABC Corporation", units: ["Engineering"]),
            categories: ["Work", "Development"],
            note: "Important contact"
        )

        let data = try await serializer.serialize(original)
        let parser = VCardParser()
        let parsed = try await parser.parse(data)

        // Verify all properties round-tripped correctly
        XCTAssertEqual(parsed.version, original.version)
        XCTAssertEqual(parsed.uid, original.uid)
        XCTAssertEqual(parsed.formattedName, original.formattedName)
        XCTAssertEqual(parsed.name?.familyNames, original.name?.familyNames)
        XCTAssertEqual(parsed.name?.givenNames, original.name?.givenNames)
        XCTAssertEqual(parsed.name?.additionalNames, original.name?.additionalNames)
        XCTAssertEqual(parsed.nicknames, original.nicknames)
        XCTAssertEqual(parsed.gender?.sex, original.gender?.sex)
        XCTAssertEqual(parsed.telephones.count, original.telephones.count)
        XCTAssertEqual(parsed.emails.count, original.emails.count)
        XCTAssertEqual(parsed.addresses.count, original.addresses.count)
        XCTAssertEqual(parsed.title, original.title)
        XCTAssertEqual(parsed.role, original.role)
        XCTAssertEqual(parsed.organization?.name, original.organization?.name)
        XCTAssertEqual(parsed.categories, original.categories)
        XCTAssertEqual(parsed.note, original.note)
    }

    // MARK: - Format Tests

    func testSerializeEndsWithCRLF() async throws {
        let vcard = VCard(version: .v4_0, formattedName: "John Doe")

        let text = try await serializer.serializeToString(vcard)

        XCTAssertTrue(text.hasSuffix("\r\n"))
    }

    func testSerializeUsesCorrectLineEndings() async throws {
        let vcard = VCard(version: .v4_0, formattedName: "John Doe")

        let text = try await serializer.serializeToString(vcard)
        let lines = text.components(separatedBy: "\r\n")

        // Should have at least BEGIN, VERSION, FN, END, and empty line at end
        XCTAssertGreaterThanOrEqual(lines.count, 5)
    }

    // MARK: - Real-World Example

    func testSerializeCompleteVCard() async throws {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        let birthday = formatter.date(from: "19850415")!

        let timestampFormatter = DateFormatter()
        timestampFormatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        timestampFormatter.timeZone = TimeZone(secondsFromGMT: 0)
        let revision = timestampFormatter.date(from: "20231215T120000Z")!

        let vcard = VCard(
            version: .v4_0,
            uid: "urn:uuid:4fbe8971-0bc3-424c-9c26-36c3e1eff6b1",
            formattedName: "Dr. John Q. Public Jr.",
            name: StructuredName(
                familyNames: ["Public"],
                givenNames: ["John"],
                additionalNames: ["Quinlan"],
                honorificPrefixes: ["Dr."],
                honorificSuffixes: ["Jr."]
            ),
            revision: revision,
            nicknames: ["Johnny"],
            birthday: .date(birthday),
            gender: Gender(sex: .male),
            telephones: [
                Telephone(value: "+1-555-555-1234", types: [.work, .voice]),
                Telephone(value: "+1-555-555-5678", types: [.home]),
                Telephone(value: "+1-555-555-9999", types: [.cell])
            ],
            emails: [
                Email(value: "john.public@example.com", types: [.work], preference: 1),
                Email(value: "john@home.com", types: [.home])
            ],
            addresses: [
                Address(
                    streetAddress: "123 Main St",
                    locality: "Springfield",
                    region: "IL",
                    postalCode: "62701",
                    country: "USA",
                    types: [.work]
                ),
                Address(
                    streetAddress: "456 Oak Ave",
                    locality: "Anytown",
                    region: "CA",
                    postalCode: "90210",
                    country: "USA",
                    types: [.home]
                )
            ],
            title: "Senior Software Engineer",
            role: "Team Lead",
            organization: Organization(name: "ABC Corporation", units: ["Engineering Department"]),
            urls: [URL(string: "https://example.com")!],
            categories: ["Work", "Development"],
            note: "Important contact"
        )

        let text = try await serializer.serializeToString(vcard)

        // Verify structure
        XCTAssertTrue(text.hasPrefix("BEGIN:VCARD\r\n"))
        XCTAssertTrue(text.hasSuffix("END:VCARD\r\n"))
        XCTAssertTrue(text.contains("VERSION:4.0"))
        XCTAssertTrue(text.contains("FN:Dr. John Q. Public Jr."))
        XCTAssertTrue(text.contains("N:Public;John;Quinlan;Dr.;Jr."))

        // Can be parsed back
        let parser = VCardParser()
        let parsed = try await parser.parse(text.data(using: .utf8)!)
        XCTAssertEqual(parsed.formattedName, vcard.formattedName)
    }
}
