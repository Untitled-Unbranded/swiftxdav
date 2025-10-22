import Foundation
import SwiftXDAV

/// Handles CardDAV operations
@MainActor
final class CardDAVViewModel {
    let appState: AppState

    init(appState: AppState) {
        self.appState = appState
    }

    func loadAddressBooks() async {
        guard let client = appState.cardDAVClient else { return }

        appState.isLoading = true
        appState.clearError()

        do {
            let addressBooks = try await client.listAddressBooks()
            appState.addressBooks = addressBooks
        } catch let error as SwiftXDAVError {
            appState.errorMessage = "Failed to load address books: \(error)"
        } catch {
            appState.errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        appState.isLoading = false
    }

    func loadContacts(from addressBook: AddressBook) async {
        guard let client = appState.cardDAVClient else { return }

        appState.isLoading = true
        appState.clearError()

        do {
            let contacts = try await client.fetchContacts(from: addressBook)
            appState.contacts = contacts
            appState.selectedAddressBook = addressBook
        } catch let error as SwiftXDAVError {
            appState.errorMessage = "Failed to load contacts: \(error)"
        } catch {
            appState.errorMessage = "Unexpected error: \(error.localizedDescription)"
        }

        appState.isLoading = false
    }
}
