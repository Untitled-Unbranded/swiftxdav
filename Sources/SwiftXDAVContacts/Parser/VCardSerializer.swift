import Foundation
import SwiftXDAVCore

/// Serializer for vCard data (RFC 6350)
///
/// Serializes `VCard` objects into vCard 3.0 or 4.0 text format.
///
/// ## Example
///
/// ```swift
/// let vcard = VCard(
///     version: .v4_0,
///     formattedName: "John Doe",
///     name: StructuredName(familyNames: ["Doe"], givenNames: ["John"])
/// )
///
/// let serializer = VCardSerializer()
/// let data = try await serializer.serialize(vcard)
/// print(String(data: data, encoding: .utf8)!)
/// ```
public actor VCardSerializer {
    public init() {}

    /// Serialize vCard to data
    ///
    /// - Parameter vcard: VCard object to serialize
    /// - Returns: UTF-8 encoded vCard data
    /// - Throws: `SwiftXDAVError.invalidData` if serialization fails
    public func serialize(_ vcard: VCard) async throws -> Data {
        let text = try serializeToString(vcard)
        guard let data = text.data(using: .utf8) else {
            throw SwiftXDAVError.invalidData("Failed to encode as UTF-8")
        }
        return data
    }

    /// Serialize vCard to string
    ///
    /// - Parameter vcard: VCard object to serialize
    /// - Returns: vCard text content
    /// - Throws: `SwiftXDAVError.invalidData` if serialization fails
    public func serializeToString(_ vcard: VCard) throws -> String {
        var lines: [String] = []

        // Begin vCard
        lines.append("BEGIN:VCARD")

        // Version (required)
        lines.append("VERSION:\(vcard.version.rawValue)")

        // UID
        if let uid = vcard.uid {
            lines.append("UID:\(uid)")
        }

        // Formatted Name (required)
        lines.append("FN:\(escapeText(vcard.formattedName))")

        // Structured Name
        if let name = vcard.name {
            lines.append(serializeStructuredName(name))
        }

        // Product ID
        if let prodid = vcard.prodid {
            lines.append("PRODID:\(prodid)")
        }

        // Revision
        if let revision = vcard.revision {
            lines.append("REV:\(formatTimestamp(revision))")
        }

        // Nicknames
        if !vcard.nicknames.isEmpty {
            lines.append("NICKNAME:\(vcard.nicknames.map { escapeText($0) }.joined(separator: ","))")
        }

        // Photo
        if let photo = vcard.photo {
            lines.append(contentsOf: serializeMediaProperty("PHOTO", media: photo))
        }

        // Birthday
        if let birthday = vcard.birthday {
            lines.append(serializeDateOrText("BDAY", value: birthday))
        }

        // Anniversary (vCard 4.0)
        if vcard.version == .v4_0, let anniversary = vcard.anniversary {
            lines.append(serializeDateOrText("ANNIVERSARY", value: anniversary))
        }

        // Gender (vCard 4.0)
        if vcard.version == .v4_0, let gender = vcard.gender {
            lines.append(serializeGender(gender))
        }

        // Kind (vCard 4.0)
        if vcard.version == .v4_0, let kind = vcard.kind {
            lines.append("KIND:\(kind.rawValue)")
        }

        // Telephones
        for telephone in vcard.telephones {
            lines.append(serializeTelephone(telephone, version: vcard.version))
        }

        // Emails
        for email in vcard.emails {
            lines.append(serializeEmail(email, version: vcard.version))
        }

        // Instant Messaging
        for impp in vcard.impp {
            lines.append(serializeInstantMessaging(impp))
        }

        // Languages
        for language in vcard.languages {
            lines.append(serializeLanguage(language))
        }

        // Addresses
        for address in vcard.addresses {
            lines.append(contentsOf: serializeAddress(address, version: vcard.version))
        }

        // Title
        if let title = vcard.title {
            lines.append("TITLE:\(escapeText(title))")
        }

        // Role
        if let role = vcard.role {
            lines.append("ROLE:\(escapeText(role))")
        }

        // Logo
        if let logo = vcard.logo {
            lines.append(contentsOf: serializeMediaProperty("LOGO", media: logo))
        }

        // Organization
        if let org = vcard.organization {
            lines.append(serializeOrganization(org))
        }

        // Members
        for member in vcard.members {
            lines.append("MEMBER:\(member)")
        }

        // Related
        for related in vcard.related {
            lines.append(serializeRelated(related))
        }

        // Timezone
        if let timezone = vcard.timezone {
            lines.append("TZ:\(timezone)")
        }

        // Geographic Position
        if let geo = vcard.geo {
            lines.append(serializeGeographicPosition(geo, version: vcard.version))
        }

        // URLs
        for url in vcard.urls {
            lines.append("URL:\(url.absoluteString)")
        }

        // Source
        if let source = vcard.source {
            lines.append("SOURCE:\(source.absoluteString)")
        }

        // Key
        if let key = vcard.key {
            lines.append(contentsOf: serializeMediaProperty("KEY", media: key))
        }

        // Free/Busy URL
        if let fburl = vcard.freeBusyURL {
            lines.append("FBURL:\(fburl.absoluteString)")
        }

        // Calendar Address URI
        if let caluri = vcard.calendarAddressURI {
            lines.append("CALADRURI:\(caluri.absoluteString)")
        }

        // Calendar URI
        if let calendaruri = vcard.calendarURI {
            lines.append("CALURI:\(calendaruri.absoluteString)")
        }

        // Categories
        if !vcard.categories.isEmpty {
            lines.append("CATEGORIES:\(vcard.categories.map { escapeText($0) }.joined(separator: ","))")
        }

        // Note
        if let note = vcard.note {
            lines.append("NOTE:\(escapeText(note))")
        }

        // Sound (vCard 3.0)
        if vcard.version == .v3_0, let sound = vcard.sound {
            lines.append(contentsOf: serializeMediaProperty("SOUND", media: sound))
        }

        // Extended properties
        for (name, value) in vcard.extendedProperties.sorted(by: { $0.key < $1.key }) {
            lines.append("\(name):\(value)")
        }

        // End vCard
        lines.append("END:VCARD")

        // Fold lines and join with CRLF
        return foldLines(lines).joined(separator: "\r\n") + "\r\n"
    }

    // MARK: - Property Serializers

    /// Serialize structured name
    private func serializeStructuredName(_ name: StructuredName) -> String {
        let components = [
            name.familyNames.map { escapeText($0) }.joined(separator: ","),
            name.givenNames.map { escapeText($0) }.joined(separator: ","),
            name.additionalNames.map { escapeText($0) }.joined(separator: ","),
            name.honorificPrefixes.map { escapeText($0) }.joined(separator: ","),
            name.honorificSuffixes.map { escapeText($0) }.joined(separator: ",")
        ]

        return "N:\(components.joined(separator: ";"))"
    }

    /// Serialize media property (photo, logo, sound, key)
    private func serializeMediaProperty(_ propertyName: String, media: MediaProperty) -> [String] {
        switch media.mediaType {
        case .uri(let url):
            let params = serializeParameters(media.parameters)
            return ["\(propertyName)\(params):\(url.absoluteString)"]

        case .data(let data, let mediaType):
            var params = media.parameters
            let base64 = data.base64EncodedString()

            if let mediaType = mediaType {
                params["MEDIATYPE"] = mediaType
            }

            // Use data URI for vCard 4.0
            let paramsString = serializeParameters(params)
            let dataURI = "data:\(mediaType ?? "application/octet-stream");base64,\(base64)"
            return ["\(propertyName)\(paramsString):\(dataURI)"]
        }
    }

    /// Serialize date or text
    private func serializeDateOrText(_ propertyName: String, value: DateOrText) -> String {
        switch value {
        case .date(let date):
            return "\(propertyName):\(formatDate(date))"
        case .text(let text):
            return "\(propertyName);VALUE=text:\(escapeText(text))"
        }
    }

    /// Serialize gender
    private func serializeGender(_ gender: Gender) -> String {
        var parts: [String] = []

        if let sex = gender.sex {
            parts.append(sex.rawValue)
        } else {
            parts.append("")
        }

        if let identity = gender.identity {
            parts.append(escapeText(identity))
        }

        return "GENDER:\(parts.joined(separator: ";"))"
    }

    /// Serialize telephone
    private func serializeTelephone(_ telephone: Telephone, version: VCardVersion) -> String {
        var params = telephone.parameters

        if !telephone.types.isEmpty {
            params["TYPE"] = telephone.types.map { $0.rawValue }.joined(separator: ",")
        }

        if let pref = telephone.preference {
            params["PREF"] = "\(pref)"
        }

        let paramsString = serializeParameters(params)
        return "TEL\(paramsString):\(telephone.value)"
    }

    /// Serialize email
    private func serializeEmail(_ email: Email, version: VCardVersion) -> String {
        var params = email.parameters

        if !email.types.isEmpty {
            params["TYPE"] = email.types.map { $0.rawValue }.joined(separator: ",")
        }

        if let pref = email.preference {
            params["PREF"] = "\(pref)"
        }

        let paramsString = serializeParameters(params)
        return "EMAIL\(paramsString):\(email.value)"
    }

    /// Serialize instant messaging
    private func serializeInstantMessaging(_ impp: InstantMessaging) -> String {
        var params = impp.parameters

        if !impp.types.isEmpty {
            params["TYPE"] = impp.types.joined(separator: ",")
        }

        if let pref = impp.preference {
            params["PREF"] = "\(pref)"
        }

        let paramsString = serializeParameters(params)
        return "IMPP\(paramsString):\(impp.uri)"
    }

    /// Serialize language
    private func serializeLanguage(_ language: Language) -> String {
        var params = language.parameters

        if let pref = language.preference {
            params["PREF"] = "\(pref)"
        }

        let paramsString = serializeParameters(params)
        return "LANG\(paramsString):\(language.tag)"
    }

    /// Serialize address
    private func serializeAddress(_ address: Address, version: VCardVersion) -> [String] {
        var params = address.parameters

        if !address.types.isEmpty {
            params["TYPE"] = address.types.map { $0.rawValue }.joined(separator: ",")
        }

        if let pref = address.preference {
            params["PREF"] = "\(pref)"
        }

        if let label = address.label {
            params["LABEL"] = escapeText(label)
        }

        let components = [
            escapeText(address.poBox ?? ""),
            escapeText(address.extendedAddress ?? ""),
            escapeText(address.streetAddress ?? ""),
            escapeText(address.locality ?? ""),
            escapeText(address.region ?? ""),
            escapeText(address.postalCode ?? ""),
            escapeText(address.country ?? "")
        ]

        let paramsString = serializeParameters(params)
        return ["ADR\(paramsString):\(components.joined(separator: ";"))"]
    }

    /// Serialize organization
    private func serializeOrganization(_ org: Organization) -> String {
        var components = [escapeText(org.name)]
        components.append(contentsOf: org.units.map { escapeText($0) })
        return "ORG:\(components.joined(separator: ";"))"
    }

    /// Serialize related
    private func serializeRelated(_ related: Related) -> String {
        var params = related.parameters

        if !related.types.isEmpty {
            params["TYPE"] = related.types.map { $0.rawValue }.joined(separator: ",")
        }

        let paramsString = serializeParameters(params)
        return "RELATED\(paramsString):\(escapeText(related.value))"
    }

    /// Serialize geographic position
    private func serializeGeographicPosition(_ geo: GeographicPosition, version: VCardVersion) -> String {
        // vCard 4.0 uses geo: URI format
        if version == .v4_0 {
            return "GEO:geo:\(geo.latitude),\(geo.longitude)"
        } else {
            // vCard 3.0 uses lat;lon format
            return "GEO:\(geo.latitude);\(geo.longitude)"
        }
    }

    // MARK: - Helpers

    /// Serialize parameters
    private func serializeParameters(_ parameters: [String: String]) -> String {
        guard !parameters.isEmpty else { return "" }

        let params = parameters.sorted { $0.key < $1.key }.map { key, value in
            // Quote value if it contains special characters
            if value.contains(",") || value.contains(";") || value.contains(":") {
                return ";\(key)=\"\(value)\""
            } else {
                return ";\(key)=\(value)"
            }
        }.joined()

        return params
    }

    /// Escape text according to vCard rules
    private func escapeText(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: ";", with: "\\;")
            .replacingOccurrences(of: ",", with: "\\,")
    }

    /// Format date (YYYYMMDD or YYYY-MM-DD)
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    /// Format timestamp (ISO 8601)
    private func formatTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyyMMdd'T'HHmmss'Z'"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    /// Fold long lines to max 75 octets per RFC 6350
    ///
    /// Lines are folded by inserting CRLF followed by a space.
    private func foldLines(_ lines: [String]) -> [String] {
        lines.flatMap { line in
            // Convert to UTF-8 bytes
            guard let data = line.data(using: .utf8) else {
                return [line]
            }

            // If line is 75 octets or less, no folding needed
            if data.count <= 75 {
                return [line]
            }

            var result: [String] = []
            var currentData = data

            // First line gets 75 octets
            while currentData.count > 75 {
                // Find a safe UTF-8 boundary at or before 75 bytes
                var splitIndex = 75

                // Make sure we don't split in the middle of a multi-byte UTF-8 character
                while splitIndex > 0 {
                    let byte = currentData[splitIndex]
                    // If this is not a continuation byte (10xxxxxx), we can split here
                    if (byte & 0xC0) != 0x80 {
                        break
                    }
                    splitIndex -= 1
                }

                guard splitIndex > 0 else {
                    // Couldn't find a safe split point, use the whole line
                    if let str = String(data: currentData, encoding: .utf8) {
                        result.append(str)
                    }
                    break
                }

                let chunk = currentData.prefix(splitIndex)
                if let str = String(data: chunk, encoding: .utf8) {
                    result.append(str)
                }

                currentData = currentData.dropFirst(splitIndex)
            }

            // Add remaining data
            if !currentData.isEmpty, let str = String(data: currentData, encoding: .utf8) {
                result.append(" " + str)
            }

            return result
        }
    }
}
