import SwiftUI
import SwiftXDAV

/// View for displaying contacts
struct ContactsView: View {
    @Bindable var appState: AppState

    var body: some View {
        List {
            if let addressBook = appState.selectedAddressBook {
                Section {
                    Text("Address Book: \(addressBook.displayName)")
                        .font(.headline)
                }
            }

            if appState.contacts.isEmpty {
                if appState.isLoading {
                    ProgressView("Loading contacts...")
                } else {
                    Text("No contacts found")
                        .foregroundStyle(.secondary)
                }
            } else {
                ForEach(appState.contacts, id: \.uid) { contact in
                    ContactRow(contact: contact)
                }
            }
        }
        .navigationTitle("Contacts")
    }
}

struct ContactRow: View {
    let contact: VCard

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(contact.formattedName)
                .font(.headline)

            if let name = contact.name {
                let givenName = name.givenNames.first ?? ""
                let familyName = name.familyNames.first ?? ""
                Text("\(givenName) \(familyName)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if let organization = contact.organization {
                HStack {
                    Image(systemName: "building.2")
                    Text(organization.name)
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
            }

            if let title = contact.title {
                HStack {
                    Image(systemName: "briefcase")
                    Text(title)
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }

            ForEach(Array(contact.emails.prefix(2)), id: \.value) { email in
                HStack {
                    Image(systemName: "envelope")
                    Text(email.value)
                }
                .font(.caption)
                .foregroundStyle(.blue)
            }

            ForEach(Array(contact.telephones.prefix(2)), id: \.value) { phone in
                HStack {
                    Image(systemName: "phone")
                    Text(phone.value)
                }
                .font(.caption)
                .foregroundStyle(.green)
            }
        }
        .padding(.vertical, 4)
    }
}
