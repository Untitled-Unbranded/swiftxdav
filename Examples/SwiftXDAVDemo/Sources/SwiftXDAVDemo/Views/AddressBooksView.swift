import SwiftUI
import SwiftXDAV

/// View for displaying address books
struct AddressBooksView: View {
    @Bindable var appState: AppState
    @State private var viewModel: CardDAVViewModel?

    var body: some View {
        List {
            if appState.addressBooks.isEmpty {
                if appState.isLoading {
                    ProgressView("Loading address books...")
                } else {
                    Text("No address books found")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(appState.addressBooks, id: \.url) { addressBook in
                    Button(action: { loadContacts(from: addressBook) }) {
                        AddressBookRow(addressBook: addressBook)
                    }
                }
            }
        }
        .navigationTitle("Address Books")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Refresh", action: loadAddressBooks)
                    .disabled(appState.isLoading)
            }
        }
        .onAppear {
            if viewModel == nil {
                viewModel = CardDAVViewModel(appState: appState)
                loadAddressBooks()
            }
        }
    }

    private func loadAddressBooks() {
        Task {
            await viewModel?.loadAddressBooks()
        }
    }

    private func loadContacts(from addressBook: AddressBook) {
        Task {
            await viewModel?.loadContacts(from: addressBook)
        }
    }
}

struct AddressBookRow: View {
    let addressBook: AddressBook

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(addressBook.displayName)
                .font(.headline)

            Text(addressBook.url.absoluteString)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            if let description = addressBook.description {
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}
