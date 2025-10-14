import Foundation
import SwiftXDAVCore

/// Parser for vCard data (RFC 6350)
///
/// Parses vCard 3.0 and 4.0 formats into structured `VCard` objects.
///
/// ## Example
///
/// ```swift
/// let parser = VCardParser()
/// let data = """
///     BEGIN:VCARD
///     VERSION:4.0
///     FN:John Doe
///     N:Doe;John;;;
///     EMAIL:john@example.com
///     END:VCARD
///     """.data(using: .utf8)!
///
/// let vcard = try await parser.parse(data)
/// print(vcard.formattedName) // "John Doe"
/// ```
public actor VCardParser {
    public init() {}

    /// Parse vCard data
    ///
    /// - Parameter data: UTF-8 encoded vCard data
    /// - Returns: Parsed vCard object
    /// - Throws: `SwiftXDAVError.parsingError` if data is invalid
    public func parse(_ data: Data) async throws -> VCard {
        guard let text = String(data: data, encoding: .utf8) else {
            throw SwiftXDAVError.parsingError("Invalid UTF-8 encoding")
        }

        return try parse(text)
    }

    /// Parse vCard text
    ///
    /// - Parameter text: vCard text content
    /// - Returns: Parsed vCard object
    /// - Throws: `SwiftXDAVError.parsingError` if text is invalid
    public func parse(_ text: String) throws -> VCard {
        let lines = unfoldLines(text)
        var properties: [VCardProperty] = []
        var insideVCard = false

        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            if trimmed == "BEGIN:VCARD" {
                insideVCard = true
                continue
            }

            if trimmed == "END:VCARD" {
                insideVCard = false
                break
            }

            if insideVCard {
                let property = try parseProperty(line)
                properties.append(property)
            }
        }

        return try buildVCard(from: properties)
    }

    // MARK: - Line Unfolding

    /// Unfold lines according to RFC 6350 (handle line wrapping)
    private func unfoldLines(_ text: String) -> [String] {
        var result: [String] = []
        var currentLine = ""

        for line in text.components(separatedBy: .newlines) {
            // Lines starting with space or tab are continuations
            if line.hasPrefix(" ") || line.hasPrefix("\t") {
                currentLine += line.dropFirst()
            } else {
                if !currentLine.isEmpty {
                    result.append(currentLine)
                }
                currentLine = line
            }
        }

        if !currentLine.isEmpty {
            result.append(currentLine)
        }

        return result
    }

    // MARK: - Property Parsing

    /// Parse a single vCard property line
    private func parseProperty(_ line: String) throws -> VCardProperty {
        // Find the colon that separates name from value
        guard let colonIndex = line.firstIndex(of: ":") else {
            throw SwiftXDAVError.parsingError("Invalid property format (no colon): \(line)")
        }

        let nameAndParams = String(line[..<colonIndex])
        let value = String(line[line.index(after: colonIndex)...])

        // Parse name and parameters
        let parts = nameAndParams.components(separatedBy: ";")
        guard let name = parts.first?.uppercased() else {
            throw SwiftXDAVError.parsingError("Missing property name: \(line)")
        }

        var parameters: [String: String] = [:]
        for param in parts.dropFirst() {
            let paramParts = param.components(separatedBy: "=")
            if paramParts.count == 2 {
                let key = paramParts[0].uppercased()
                let val = paramParts[1].trimmingCharacters(in: CharacterSet(charactersIn: "\""))
                parameters[key] = val
            }
        }

        return VCardProperty(name: name, parameters: parameters, value: value)
    }

    // MARK: - vCard Building

    /// Build a VCard from parsed properties
    private func buildVCard(from properties: [VCardProperty]) throws -> VCard {
        // Extract version first
        guard let versionProp = properties.first(where: { $0.name == "VERSION" }) else {
            throw SwiftXDAVError.parsingError("Missing VERSION property")
        }

        let version: VCardVersion
        switch versionProp.value {
        case "3.0":
            version = .v3_0
        case "4.0":
            version = .v4_0
        default:
            throw SwiftXDAVError.parsingError("Unsupported vCard version: \(versionProp.value)")
        }

        // Extract formatted name (required)
        guard let fnProp = properties.first(where: { $0.name == "FN" }) else {
            throw SwiftXDAVError.parsingError("Missing FN (formatted name) property")
        }

        var vcard = VCard(
            version: version,
            formattedName: unescapeText(fnProp.value)
        )

        // Parse all properties
        for property in properties {
            try parsePropertyIntoVCard(property, vcard: &vcard)
        }

        return vcard
    }

    /// Parse a property and update the vCard
    private func parsePropertyIntoVCard(_ property: VCardProperty, vcard: inout VCard) throws {
        switch property.name {
        case "VERSION", "BEGIN", "END":
            // Already handled
            break

        case "UID":
            vcard.uid = property.value

        case "FN":
            vcard.formattedName = unescapeText(property.value)

        case "N":
            vcard.name = try parseStructuredName(property.value)

        case "PRODID":
            vcard.prodid = property.value

        case "REV":
            vcard.revision = parseTimestamp(property.value)

        case "NICKNAME":
            vcard.nicknames = property.value.components(separatedBy: ",").map { unescapeText($0.trimmingCharacters(in: .whitespaces)) }

        case "PHOTO":
            vcard.photo = try parseMediaProperty(property)

        case "BDAY":
            vcard.birthday = parseDateOrText(property.value)

        case "ANNIVERSARY":
            vcard.anniversary = parseDateOrText(property.value)

        case "GENDER":
            vcard.gender = parseGender(property.value)

        case "KIND":
            vcard.kind = Kind(rawValue: property.value.lowercased())

        case "TEL":
            vcard.telephones.append(try parseTelephone(property))

        case "EMAIL":
            vcard.emails.append(parseEmail(property))

        case "IMPP":
            vcard.impp.append(parseInstantMessaging(property))

        case "LANG":
            vcard.languages.append(parseLanguage(property))

        case "ADR":
            vcard.addresses.append(try parseAddress(property))

        case "TITLE":
            vcard.title = unescapeText(property.value)

        case "ROLE":
            vcard.role = unescapeText(property.value)

        case "LOGO":
            vcard.logo = try parseMediaProperty(property)

        case "ORG":
            vcard.organization = parseOrganization(property.value)

        case "MEMBER":
            vcard.members.append(property.value)

        case "RELATED":
            vcard.related.append(parseRelated(property))

        case "TZ":
            vcard.timezone = property.value

        case "GEO":
            vcard.geo = parseGeographicPosition(property.value)

        case "URL":
            if let url = URL(string: property.value) {
                vcard.urls.append(url)
            }

        case "SOURCE":
            vcard.source = URL(string: property.value)

        case "KEY":
            vcard.key = try parseMediaProperty(property)

        case "FBURL":
            vcard.freeBusyURL = URL(string: property.value)

        case "CALADRURI":
            vcard.calendarAddressURI = URL(string: property.value)

        case "CALURI":
            vcard.calendarURI = URL(string: property.value)

        case "CATEGORIES":
            vcard.categories = property.value.components(separatedBy: ",").map { unescapeText($0.trimmingCharacters(in: .whitespaces)) }

        case "NOTE":
            vcard.note = unescapeText(property.value)

        case "SOUND":
            vcard.sound = try parseMediaProperty(property)

        default:
            // Extended/custom property
            if property.name.hasPrefix("X-") {
                vcard.extendedProperties[property.name] = property.value
            }
        }
    }

    // MARK: - Value Parsers

    /// Parse structured name (N property)
    /// Format: Family;Given;Additional;Prefix;Suffix
    private func parseStructuredName(_ value: String) throws -> StructuredName {
        let parts = value.components(separatedBy: ";")

        func parseComponent(_ index: Int) -> [String] {
            guard index < parts.count else { return [] }
            return parts[index].components(separatedBy: ",").map { unescapeText($0) }.filter { !$0.isEmpty }
        }

        return StructuredName(
            familyNames: parseComponent(0),
            givenNames: parseComponent(1),
            additionalNames: parseComponent(2),
            honorificPrefixes: parseComponent(3),
            honorificSuffixes: parseComponent(4)
        )
    }

    /// Parse media property (PHOTO, LOGO, SOUND, KEY)
    private func parseMediaProperty(_ property: VCardProperty) throws -> MediaProperty {
        let value = property.value

        // Check if it's a URI or data
        if value.hasPrefix("http://") || value.hasPrefix("https://") {
            guard let url = URL(string: value) else {
                throw SwiftXDAVError.parsingError("Invalid URL in media property: \(value)")
            }
            return MediaProperty(mediaType: .uri(url), parameters: property.parameters)
        } else if value.hasPrefix("data:") {
            // Parse data URI: data:[<mediatype>][;base64],<data>
            let dataPrefix = "data:"
            let withoutPrefix = String(value.dropFirst(dataPrefix.count))

            if let commaIndex = withoutPrefix.firstIndex(of: ",") {
                let header = String(withoutPrefix[..<commaIndex])
                let dataStr = String(withoutPrefix[withoutPrefix.index(after: commaIndex)...])

                let mediaType = header.components(separatedBy: ";").first
                let isBase64 = header.contains("base64")

                if isBase64, let data = Data(base64Encoded: dataStr) {
                    return MediaProperty(mediaType: .data(data, mediaType: mediaType), parameters: property.parameters)
                } else if let data = dataStr.data(using: .utf8) {
                    return MediaProperty(mediaType: .data(data, mediaType: mediaType), parameters: property.parameters)
                }
            }
            throw SwiftXDAVError.parsingError("Invalid data URI: \(value)")
        } else if property.parameters["ENCODING"] == "b" || property.parameters["ENCODING"] == "BASE64" {
            // vCard 3.0 base64 encoding
            if let data = Data(base64Encoded: value) {
                let mediaType = property.parameters["TYPE"]
                return MediaProperty(mediaType: .data(data, mediaType: mediaType), parameters: property.parameters)
            }
            throw SwiftXDAVError.parsingError("Invalid base64 data")
        } else {
            // Treat as URI
            guard let url = URL(string: value) else {
                throw SwiftXDAVError.parsingError("Invalid media property value: \(value)")
            }
            return MediaProperty(mediaType: .uri(url), parameters: property.parameters)
        }
    }

    /// Parse date or text value
    private func parseDateOrText(_ value: String) -> DateOrText {
        // Try to parse as date
        if let date = parseDate(value) {
            return .date(date)
        }
        return .text(unescapeText(value))
    }

    /// Parse date (YYYYMMDD or YYYY-MM-DD)
    private func parseDate(_ value: String) -> Date? {
        let dateFormatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }()
        ]

        for formatter in dateFormatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    /// Parse timestamp (ISO 8601)
    private func parseTimestamp(_ value: String) -> Date? {
        // Support multiple timestamp formats
        let formatters: [DateFormatter] = [
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss'Z'"
                formatter.timeZone = TimeZone(secondsFromGMT: 0)
                return formatter
            }(),
            {
                let formatter = DateFormatter()
                formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssZ"
                return formatter
            }()
        ]

        for formatter in formatters {
            if let date = formatter.date(from: value) {
                return date
            }
        }

        return nil
    }

    /// Parse gender
    private func parseGender(_ value: String) -> Gender {
        let parts = value.components(separatedBy: ";")
        let sex = parts.first.flatMap { Gender.Sex(rawValue: $0.uppercased()) }
        let identity = parts.count > 1 ? unescapeText(parts[1]) : nil
        return Gender(sex: sex, identity: identity)
    }

    /// Parse telephone
    private func parseTelephone(_ property: VCardProperty) throws -> Telephone {
        let types = parseTypes(property.parameters["TYPE"]).compactMap { TelephoneType(rawValue: $0.lowercased()) }
        let preference = property.parameters["PREF"].flatMap { Int($0) }

        return Telephone(
            value: property.value,
            types: types,
            preference: preference,
            parameters: property.parameters
        )
    }

    /// Parse email
    private func parseEmail(_ property: VCardProperty) -> Email {
        let types = parseTypes(property.parameters["TYPE"]).compactMap { EmailType(rawValue: $0.lowercased()) }
        let preference = property.parameters["PREF"].flatMap { Int($0) }

        return Email(
            value: property.value,
            types: types,
            preference: preference,
            parameters: property.parameters
        )
    }

    /// Parse instant messaging
    private func parseInstantMessaging(_ property: VCardProperty) -> InstantMessaging {
        let types = parseTypes(property.parameters["TYPE"])
        let preference = property.parameters["PREF"].flatMap { Int($0) }

        return InstantMessaging(
            uri: property.value,
            types: types,
            preference: preference,
            parameters: property.parameters
        )
    }

    /// Parse language
    private func parseLanguage(_ property: VCardProperty) -> Language {
        let preference = property.parameters["PREF"].flatMap { Int($0) }

        return Language(
            tag: property.value,
            preference: preference,
            parameters: property.parameters
        )
    }

    /// Parse address
    /// Format: PO Box;Extended;Street;Locality;Region;Postal Code;Country
    private func parseAddress(_ property: VCardProperty) throws -> Address {
        let parts = property.value.components(separatedBy: ";")

        func component(_ index: Int) -> String? {
            guard index < parts.count else { return nil }
            let value = unescapeText(parts[index])
            return value.isEmpty ? nil : value
        }

        let types = parseTypes(property.parameters["TYPE"]).compactMap { AddressType(rawValue: $0.lowercased()) }
        let preference = property.parameters["PREF"].flatMap { Int($0) }
        let label = property.parameters["LABEL"].map { unescapeText($0) }

        return Address(
            poBox: component(0),
            extendedAddress: component(1),
            streetAddress: component(2),
            locality: component(3),
            region: component(4),
            postalCode: component(5),
            country: component(6),
            types: types,
            preference: preference,
            label: label,
            parameters: property.parameters
        )
    }

    /// Parse organization
    private func parseOrganization(_ value: String) -> Organization {
        let parts = value.components(separatedBy: ";").map { unescapeText($0) }
        guard let name = parts.first else {
            return Organization(name: "")
        }

        return Organization(
            name: name,
            units: Array(parts.dropFirst())
        )
    }

    /// Parse related
    private func parseRelated(_ property: VCardProperty) -> Related {
        let types = parseTypes(property.parameters["TYPE"]).compactMap { RelationType(rawValue: $0.lowercased()) }

        return Related(
            value: unescapeText(property.value),
            types: types,
            parameters: property.parameters
        )
    }

    /// Parse geographic position
    private func parseGeographicPosition(_ value: String) -> GeographicPosition? {
        // Support both "geo:lat,lon" and "lat;lon" formats
        var coordString = value

        if value.hasPrefix("geo:") {
            coordString = String(value.dropFirst(4))
        }

        let parts = coordString.replacingOccurrences(of: ",", with: ";").components(separatedBy: ";")
        guard parts.count >= 2,
              let lat = Double(parts[0]),
              let lon = Double(parts[1]) else {
            return nil
        }

        return GeographicPosition(latitude: lat, longitude: lon)
    }

    // MARK: - Helpers

    /// Parse TYPE parameter value (can be comma-separated)
    private func parseTypes(_ typeValue: String?) -> [String] {
        guard let typeValue = typeValue else { return [] }
        return typeValue.components(separatedBy: ",").map { $0.trimmingCharacters(in: .whitespaces) }
    }

    /// Unescape text according to vCard rules
    private func unescapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\n", with: "\n")
            .replacingOccurrences(of: "\\N", with: "\n")
            .replacingOccurrences(of: "\\\\", with: "\\")
            .replacingOccurrences(of: "\\;", with: ";")
            .replacingOccurrences(of: "\\,", with: ",")
    }
}

// MARK: - Helper Types

/// Internal representation of a vCard property
private struct VCardProperty {
    let name: String
    let parameters: [String: String]
    let value: String
}
