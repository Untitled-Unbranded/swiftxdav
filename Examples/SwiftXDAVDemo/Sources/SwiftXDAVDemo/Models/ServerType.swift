import Foundation

/// Supported server types for the demo app
enum ServerType: String, CaseIterable, Identifiable, Sendable {
    case iCloud = "iCloud"
    case google = "Google"
    case nextcloud = "Nextcloud"
    case radicale = "Radicale"
    case generic = "Generic CalDAV/CardDAV"

    var id: String { rawValue }

    var defaultURL: String {
        switch self {
        case .iCloud:
            return "https://caldav.icloud.com"
        case .google:
            return "https://apidata.googleusercontent.com/caldav/v2"
        case .nextcloud:
            return "https://nextcloud.example.com/remote.php/dav"
        case .radicale:
            return "https://radicale.example.com"
        case .generic:
            return "https://caldav.example.com"
        }
    }

    var requiresOAuth: Bool {
        self == .google
    }

    var supportsAppSpecificPassword: Bool {
        self == .iCloud
    }
}
