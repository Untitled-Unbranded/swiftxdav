import Foundation

/// vCard representation (RFC 6350)
///
/// A vCard represents contact information including names, addresses, phone numbers,
/// email addresses, and other personal or organizational details.
///
/// Supports both vCard 3.0 and 4.0 formats.
public struct VCard: Sendable, Equatable {
    // MARK: - Core Properties

    /// vCard version (3.0 or 4.0)
    public var version: VCardVersion

    /// Unique identifier for this vCard
    public var uid: String?

    /// Formatted name (REQUIRED)
    public var formattedName: String

    /// Structured name components
    public var name: StructuredName?

    /// Product identifier
    public var prodid: String?

    /// Last revision timestamp
    public var revision: Date?

    // MARK: - Identification Properties

    /// Nicknames
    public var nicknames: [String]

    /// Photo or avatar
    public var photo: MediaProperty?

    /// Birthday
    public var birthday: DateOrText?

    /// Anniversary (vCard 4.0 only)
    public var anniversary: DateOrText?

    /// Gender (vCard 4.0 only)
    public var gender: Gender?

    /// Kind of vCard (individual, group, org, location) - vCard 4.0 only
    public var kind: Kind?

    // MARK: - Communication Properties

    /// Telephone numbers
    public var telephones: [Telephone]

    /// Email addresses
    public var emails: [Email]

    /// Instant messaging addresses
    public var impp: [InstantMessaging]

    /// Preferred languages
    public var languages: [Language]

    // MARK: - Delivery Address Properties

    /// Postal addresses
    public var addresses: [Address]

    // MARK: - Organizational Properties

    /// Job title
    public var title: String?

    /// Role or function
    public var role: String?

    /// Organization logo
    public var logo: MediaProperty?

    /// Organization name
    public var organization: Organization?

    /// Group members (for group vCards)
    public var members: [String]

    /// Related persons
    public var related: [Related]

    // MARK: - Geographical Properties

    /// Timezone
    public var timezone: String?

    /// Geographic position
    public var geo: GeographicPosition?

    // MARK: - URL Properties

    /// URLs
    public var urls: [URL]

    /// Source URL
    public var source: URL?

    // MARK: - Security Properties

    /// Public key or certificate
    public var key: MediaProperty?

    // MARK: - Calendar Properties

    /// Free/busy URL
    public var freeBusyURL: URL?

    /// Calendar address URI
    public var calendarAddressURI: URL?

    /// Calendar URI
    public var calendarURI: URL?

    // MARK: - Metadata Properties

    /// Categories or tags
    public var categories: [String]

    /// Notes
    public var note: String?

    /// Sound (for name pronunciation) - vCard 3.0
    public var sound: MediaProperty?

    /// Custom/Extended properties
    public var extendedProperties: [String: String]

    // MARK: - Initialization

    public init(
        version: VCardVersion = .v4_0,
        uid: String? = nil,
        formattedName: String,
        name: StructuredName? = nil,
        prodid: String? = nil,
        revision: Date? = nil,
        nicknames: [String] = [],
        photo: MediaProperty? = nil,
        birthday: DateOrText? = nil,
        anniversary: DateOrText? = nil,
        gender: Gender? = nil,
        kind: Kind? = nil,
        telephones: [Telephone] = [],
        emails: [Email] = [],
        impp: [InstantMessaging] = [],
        languages: [Language] = [],
        addresses: [Address] = [],
        title: String? = nil,
        role: String? = nil,
        logo: MediaProperty? = nil,
        organization: Organization? = nil,
        members: [String] = [],
        related: [Related] = [],
        timezone: String? = nil,
        geo: GeographicPosition? = nil,
        urls: [URL] = [],
        source: URL? = nil,
        key: MediaProperty? = nil,
        freeBusyURL: URL? = nil,
        calendarAddressURI: URL? = nil,
        calendarURI: URL? = nil,
        categories: [String] = [],
        note: String? = nil,
        sound: MediaProperty? = nil,
        extendedProperties: [String: String] = [:]
    ) {
        self.version = version
        self.uid = uid
        self.formattedName = formattedName
        self.name = name
        self.prodid = prodid
        self.revision = revision
        self.nicknames = nicknames
        self.photo = photo
        self.birthday = birthday
        self.anniversary = anniversary
        self.gender = gender
        self.kind = kind
        self.telephones = telephones
        self.emails = emails
        self.impp = impp
        self.languages = languages
        self.addresses = addresses
        self.title = title
        self.role = role
        self.logo = logo
        self.organization = organization
        self.members = members
        self.related = related
        self.timezone = timezone
        self.geo = geo
        self.urls = urls
        self.source = source
        self.key = key
        self.freeBusyURL = freeBusyURL
        self.calendarAddressURI = calendarAddressURI
        self.calendarURI = calendarURI
        self.categories = categories
        self.note = note
        self.sound = sound
        self.extendedProperties = extendedProperties
    }
}

// MARK: - Supporting Types

/// vCard version
public enum VCardVersion: String, Sendable, Equatable {
    case v3_0 = "3.0"
    case v4_0 = "4.0"
}

/// Structured name components
/// Format: Family;Given;Additional;Prefix;Suffix
public struct StructuredName: Sendable, Equatable {
    public var familyNames: [String]
    public var givenNames: [String]
    public var additionalNames: [String]
    public var honorificPrefixes: [String]
    public var honorificSuffixes: [String]

    public init(
        familyNames: [String] = [],
        givenNames: [String] = [],
        additionalNames: [String] = [],
        honorificPrefixes: [String] = [],
        honorificSuffixes: [String] = []
    ) {
        self.familyNames = familyNames
        self.givenNames = givenNames
        self.additionalNames = additionalNames
        self.honorificPrefixes = honorificPrefixes
        self.honorificSuffixes = honorificSuffixes
    }
}

/// Media property (photo, logo, sound, key)
public struct MediaProperty: Sendable, Equatable {
    public enum MediaType: Sendable, Equatable {
        case uri(URL)
        case data(Data, mediaType: String?)
    }

    public var mediaType: MediaType
    public var parameters: [String: String]

    public init(mediaType: MediaType, parameters: [String: String] = [:]) {
        self.mediaType = mediaType
        self.parameters = parameters
    }
}

/// Date or text value (for birthday, anniversary)
public enum DateOrText: Sendable, Equatable {
    case date(Date)
    case text(String)
}

/// Gender
public struct Gender: Sendable, Equatable {
    public enum Sex: String, Sendable, Equatable {
        case male = "M"
        case female = "F"
        case other = "O"
        case none = "N"
        case unknown = "U"
    }

    public var sex: Sex?
    public var identity: String?

    public init(sex: Sex?, identity: String? = nil) {
        self.sex = sex
        self.identity = identity
    }
}

/// Kind of vCard
public enum Kind: String, Sendable, Equatable {
    case individual = "individual"
    case group = "group"
    case org = "org"
    case location = "location"
}

/// Telephone number
public struct Telephone: Sendable, Equatable {
    public var value: String
    public var types: [TelephoneType]
    public var preference: Int?
    public var parameters: [String: String]

    public init(
        value: String,
        types: [TelephoneType] = [],
        preference: Int? = nil,
        parameters: [String: String] = [:]
    ) {
        self.value = value
        self.types = types
        self.preference = preference
        self.parameters = parameters
    }
}

/// Telephone type
public enum TelephoneType: String, Sendable, Equatable {
    case work
    case home
    case cell
    case voice
    case fax
    case pager
    case video
    case textphone
    case text
    case main
}

/// Email address
public struct Email: Sendable, Equatable {
    public var value: String
    public var types: [EmailType]
    public var preference: Int?
    public var parameters: [String: String]

    public init(
        value: String,
        types: [EmailType] = [],
        preference: Int? = nil,
        parameters: [String: String] = [:]
    ) {
        self.value = value
        self.types = types
        self.preference = preference
        self.parameters = parameters
    }
}

/// Email type
public enum EmailType: String, Sendable, Equatable {
    case work
    case home
    case internet
}

/// Instant messaging address
public struct InstantMessaging: Sendable, Equatable {
    public var uri: String
    public var types: [String]
    public var preference: Int?
    public var parameters: [String: String]

    public init(
        uri: String,
        types: [String] = [],
        preference: Int? = nil,
        parameters: [String: String] = [:]
    ) {
        self.uri = uri
        self.types = types
        self.preference = preference
        self.parameters = parameters
    }
}

/// Language
public struct Language: Sendable, Equatable {
    public var tag: String
    public var preference: Int?
    public var parameters: [String: String]

    public init(
        tag: String,
        preference: Int? = nil,
        parameters: [String: String] = [:]
    ) {
        self.tag = tag
        self.preference = preference
        self.parameters = parameters
    }
}

/// Postal address
/// Format: PO Box;Extended;Street;Locality;Region;Postal Code;Country
public struct Address: Sendable, Equatable {
    public var poBox: String?
    public var extendedAddress: String?
    public var streetAddress: String?
    public var locality: String?
    public var region: String?
    public var postalCode: String?
    public var country: String?
    public var types: [AddressType]
    public var preference: Int?
    public var label: String?
    public var parameters: [String: String]

    public init(
        poBox: String? = nil,
        extendedAddress: String? = nil,
        streetAddress: String? = nil,
        locality: String? = nil,
        region: String? = nil,
        postalCode: String? = nil,
        country: String? = nil,
        types: [AddressType] = [],
        preference: Int? = nil,
        label: String? = nil,
        parameters: [String: String] = [:]
    ) {
        self.poBox = poBox
        self.extendedAddress = extendedAddress
        self.streetAddress = streetAddress
        self.locality = locality
        self.region = region
        self.postalCode = postalCode
        self.country = country
        self.types = types
        self.preference = preference
        self.label = label
        self.parameters = parameters
    }
}

/// Address type
public enum AddressType: String, Sendable, Equatable {
    case work
    case home
    case postal
    case parcel
    case domestic = "dom"
    case international = "intl"
}

/// Organization
public struct Organization: Sendable, Equatable {
    public var name: String
    public var units: [String]

    public init(name: String, units: [String] = []) {
        self.name = name
        self.units = units
    }
}

/// Related person
public struct Related: Sendable, Equatable {
    public var value: String
    public var types: [RelationType]
    public var parameters: [String: String]

    public init(
        value: String,
        types: [RelationType] = [],
        parameters: [String: String] = [:]
    ) {
        self.value = value
        self.types = types
        self.parameters = parameters
    }
}

/// Relation type
public enum RelationType: String, Sendable, Equatable {
    case spouse
    case child
    case parent
    case sibling
    case friend
    case colleague
    case coresident
    case crush
    case date
    case sweetheart
    case me
    case agent
    case emergency
}

/// Geographic position
public struct GeographicPosition: Sendable, Equatable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }
}
