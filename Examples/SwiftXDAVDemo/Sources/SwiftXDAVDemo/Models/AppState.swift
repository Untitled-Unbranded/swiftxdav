import Foundation
import SwiftXDAV
import SwiftXDAVCalendar
import SwiftXDAVContacts

/// Main application state
@MainActor
@Observable
final class AppState {
    var serverType: ServerType = .iCloud
    var serverURL: String = ""
    var username: String = ""
    var password: String = ""
    var isAuthenticated: Bool = false
    var isLoading: Bool = false
    var errorMessage: String?

    // Clients
    var calDAVClient: CalDAVClient?
    var cardDAVClient: CardDAVClient?

    // Data
    var calendars: [SwiftXDAVCalendar.Calendar] = []
    var events: [VEvent] = []
    var addressBooks: [AddressBook] = []
    var contacts: [VCard] = []
    var todos: [VTodo] = []

    // Selected items
    var selectedCalendar: SwiftXDAVCalendar.Calendar?
    var selectedAddressBook: AddressBook?

    init() {
        self.serverURL = serverType.defaultURL
    }

    func updateServerURL() {
        serverURL = serverType.defaultURL
    }

    func clearError() {
        errorMessage = nil
    }

    func clearData() {
        calendars = []
        events = []
        addressBooks = []
        contacts = []
        todos = []
        selectedCalendar = nil
        selectedAddressBook = nil
    }

    func disconnect() {
        isAuthenticated = false
        calDAVClient = nil
        cardDAVClient = nil
        clearData()
    }
}
