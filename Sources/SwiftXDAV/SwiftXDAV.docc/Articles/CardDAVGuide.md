# CardDAV Guide

Master CardDAV operations including address book discovery, contact management, and synchronization.

## Overview

CardDAV (Contact Distributed Authoring and Versioning) is a protocol defined in RFC 6352 that extends WebDAV to provide contact access and management. SwiftXDAV provides a complete implementation with support for:

- Address book discovery
- Contact CRUD operations (Create, Read, Update, Delete)
- vCard 3.0 and 4.0 formats
- Contact photos and binary data
- Efficient synchronization with sync-tokens
- Contact groups (distribution lists)

## Address Book Discovery

### Discovering the Address Book Home

CardDAV uses a similar discovery process to CalDAV:

```swift
let client = CardDAVClient.iCloud(
    username: "user@icloud.com",
    appSpecificPassword: "abcd-efgh-ijkl-mnop"
)

// Discover principal URL (identifies the user)
let principalURL = try await client.discoverPrincipal()
print("Principal: \(principalURL)")

// Discover address book home URL
let addressBookHomeURL = try await client.discoverAddressBookHome()
print("Address Book Home: \(addressBookHomeURL)")
```

### Listing Address Books

```swift
// List all address books (automatic discovery)
let addressBooks = try await client.listAddressBooks()

// Or list at a specific URL
let books = try await client.listAddressBooks(at: addressBookHomeURL)

for addressBook in addressBooks {
    print("📒 \(addressBook.displayName)")
    print("   URL: \(addressBook.url)")
    print("   Description: \(addressBook.description ?? "none")")
    print("   CTag: \(addressBook.ctag ?? "none")")
}
```

### Address Book Properties

```swift
let addressBook = addressBooks.first!

// Display properties
addressBook.displayName // "Personal Contacts"
addressBook.description // "My personal contacts"

// Synchronization
addressBook.ctag // Collection tag - changes when any contact changes
addressBook.syncToken // Token for incremental sync
```

## Working with Contacts

### Fetching Contacts

```swift
// Fetch all contacts from an address book
let contacts = try await client.fetchContacts(from: addressBook)

for contact in contacts {
    print("👤 \(contact.formattedName?.value ?? "Unknown")")

    // Name components
    if let name = contact.name {
        print("   Given: \(name.givenName ?? "")")
        print("   Family: \(name.familyName ?? "")")
    }

    // Email addresses
    for email in contact.emails {
        print("   📧 \(email.value) (\(email.types.map { $0.rawValue }.joined(separator: ", ")))")
    }

    // Phone numbers
    for phone in contact.telephones {
        print("   📱 \(phone.value) (\(phone.types.map { $0.rawValue }.joined(separator: ", ")))")
    }

    // Addresses
    for address in contact.addresses {
        print("   🏠 \(address.street ?? ""), \(address.city ?? ""), \(address.postalCode ?? "")")
    }
}
```

### Fetching a Single Contact

```swift
// Fetch by UID
let contact = try await client.fetchContact(
    uid: "12345-67890-ABCDEF",
    from: addressBook
)

// Fetch with ETag (for safe updates)
let (contact, etag) = try await client.fetchContact(
    uid: "12345-67890-ABCDEF",
    from: addressBook
)
```

### Creating Contacts

#### Basic Contact

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "John Doe")
contact.name = VCard.Name(
    familyName: "Doe",
    givenName: "John",
    additionalNames: "Michael",
    prefix: "Mr.",
    suffix: "Jr."
)

try await client.createContact(contact, in: addressBook)
```

#### Contact with Email and Phone

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "Jane Smith")
contact.name = VCard.Name(
    familyName: "Smith",
    givenName: "Jane"
)

// Multiple email addresses
contact.emails = [
    VCard.Email(value: "jane@work.com", types: [.work, .internet]),
    VCard.Email(value: "jane@personal.com", types: [.home, .internet]),
    VCard.Email(value: "jane@gmail.com", types: [.home], preference: 1)
]

// Multiple phone numbers
contact.telephones = [
    VCard.Telephone(value: "+1-555-0123", types: [.work, .voice]),
    VCard.Telephone(value: "+1-555-0124", types: [.home, .voice]),
    VCard.Telephone(value: "+1-555-0125", types: [.cell, .voice], preference: 1)
]

try await client.createContact(contact, in: addressBook)
```

#### Contact with Address

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "Bob Johnson")
contact.name = VCard.Name(
    familyName: "Johnson",
    givenName: "Bob"
)

// Physical addresses
contact.addresses = [
    VCard.Address(
        street: "123 Main St",
        city: "Springfield",
        region: "IL",
        postalCode: "62701",
        country: "USA",
        types: [.work]
    ),
    VCard.Address(
        street: "456 Oak Ave",
        city: "Springfield",
        region: "IL",
        postalCode: "62702",
        country: "USA",
        types: [.home]
    )
]

try await client.createContact(contact, in: addressBook)
```

#### Contact with Organization

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "Alice Williams")
contact.name = VCard.Name(
    familyName: "Williams",
    givenName: "Alice"
)

// Organization details
contact.organization = VCard.Organization(
    name: "Acme Corporation",
    units: ["Engineering", "Backend Team"]
)
contact.title = "Senior Software Engineer"
contact.role = "Tech Lead"

// Work email and phone
contact.emails = [
    VCard.Email(value: "alice@acme.com", types: [.work])
]
contact.telephones = [
    VCard.Telephone(value: "+1-555-0199", types: [.work, .voice])
]

// Website
contact.urls = [
    VCard.URL(value: "https://acme.com", types: [.work])
]

try await client.createContact(contact, in: addressBook)
```

#### Contact with Photo

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "Charlie Brown")
contact.name = VCard.Name(
    familyName: "Brown",
    givenName: "Charlie"
)

// Photo from data (embedded)
if let imageData = UIImage(named: "photo")?.jpegData(compressionQuality: 0.8) {
    contact.photo = VCard.Photo(
        data: imageData,
        mediaType: "image/jpeg"
    )
}

// Or photo from URL (referenced)
contact.photo = VCard.Photo(
    url: URL(string: "https://example.com/photos/charlie.jpg")!,
    mediaType: "image/jpeg"
)

try await client.createContact(contact, in: addressBook)
```

#### Contact with Birthday and Anniversary

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "David Lee")
contact.name = VCard.Name(
    familyName: "Lee",
    givenName: "David"
)

// Birthday
let dateFormatter = DateFormatter()
dateFormatter.dateFormat = "yyyy-MM-dd"
contact.birthday = dateFormatter.date(from: "1990-05-15")

// Anniversary
contact.anniversary = dateFormatter.date(from: "2015-08-20")

try await client.createContact(contact, in: addressBook)
```

### Updating Contacts

Always use ETags to prevent conflicts:

```swift
// Fetch contact with current ETag
let (contact, etag) = try await client.fetchContact(
    uid: contact.uid,
    from: addressBook
)

// Modify contact
var updatedContact = contact
updatedContact.telephones.append(
    VCard.Telephone(value: "+1-555-9999", types: [.cell, .voice])
)

// Update with ETag (fails if contact was modified by someone else)
do {
    try await client.updateContact(updatedContact, in: addressBook, etag: etag)
    print("Contact updated successfully")
} catch SwiftXDAVError.preconditionFailed {
    print("Contact was modified by someone else, please refetch")
}
```

### Deleting Contacts

```swift
// Delete by UID
try await client.deleteContact(uid: contact.uid, from: addressBook)
```

## Contact Groups

Some CardDAV servers support contact groups (distribution lists):

### Creating a Group

```swift
var group = VCard()
group.uid = UUID().uuidString
group.formattedName = VCard.FormattedName(value: "Work Team")
group.kind = .group

// Add members by UID
group.members = [
    "contact-uid-1",
    "contact-uid-2",
    "contact-uid-3"
]

try await client.createContact(group, in: addressBook)
```

### Adding Members to Group

```swift
let (group, etag) = try await client.fetchContact(
    uid: groupUID,
    from: addressBook
)

var updatedGroup = group
updatedGroup.members?.append("new-contact-uid")

try await client.updateContact(updatedGroup, in: addressBook, etag: etag)
```

## Synchronization

### Full Sync (Initial)

```swift
// First sync - fetch all contacts
let result = try await client.sync(addressBook: addressBook, syncToken: nil)

print("Changes: \(result.changes.count)")
for change in result.changes {
    switch change {
    case .added(let contact):
        // Store contact in local database
        print("New contact: \(contact.formattedName?.value ?? "Unknown")")
    case .modified(let contact):
        // Update contact in local database
        print("Updated contact: \(contact.formattedName?.value ?? "Unknown")")
    case .deleted(let uid):
        // Delete contact from local database
        print("Deleted contact: \(uid)")
    }
}

// Save sync token for next sync
UserDefaults.standard.set(result.syncToken?.token, forKey: "addressBookSyncToken")
```

### Incremental Sync

```swift
// Load previous sync token
let previousToken: String? = UserDefaults.standard.string(forKey: "addressBookSyncToken")
let syncToken = previousToken.map { SyncToken(token: $0) }

// Perform incremental sync - only fetches changes
let result = try await client.sync(addressBook: addressBook, syncToken: syncToken)

print("Changes since last sync: \(result.changes.count)")

// Process changes
for change in result.changes {
    switch change {
    case .added(let contact):
        localDatabase.insert(contact)
    case .modified(let contact):
        localDatabase.update(contact)
    case .deleted(let uid):
        localDatabase.delete(uid)
    }
}

// Save new sync token
UserDefaults.standard.set(result.syncToken?.token, forKey: "addressBookSyncToken")
```

### Handling Sync Conflicts

```swift
do {
    let result = try await client.sync(addressBook: addressBook, syncToken: oldToken)
    // Process changes
} catch SwiftXDAVError.syncTokenInvalid {
    print("Sync token invalid, performing full sync")

    // Fall back to full sync
    let result = try await client.sync(addressBook: addressBook, syncToken: nil)

    // Replace entire local database
    localDatabase.deleteAll()
    for change in result.changes {
        if case .added(let contact) = change {
            localDatabase.insert(contact)
        }
    }
}
```

## vCard Format Details

### vCard 3.0 vs 4.0

SwiftXDAV supports both vCard 3.0 and 4.0:

```swift
// Parse vCard (automatically detects version)
let vCardData = """
BEGIN:VCARD
VERSION:4.0
FN:John Doe
EMAIL:john@example.com
END:VCARD
""".data(using: .utf8)!

let parser = VCardParser()
let contact = try parser.parse(vCardData)
print("Version: \(contact.version)") // 4.0

// Serialize to specific version
let serializer = VCardSerializer()
let vCard30 = try serializer.serialize(contact, version: .v3_0)
let vCard40 = try serializer.serialize(contact, version: .v4_0)
```

### Property Types

vCard properties can have types to categorize them:

```swift
// Common types
VCard.Email(value: "email@example.com", types: [.work, .internet])
VCard.Telephone(value: "+1-555-0123", types: [.home, .voice, .cell])
VCard.Address(street: "123 Main", types: [.work, .postal, .parcel])

// Custom types (vCard 3.0)
VCard.Email(value: "email@example.com", types: [.custom("X-CUSTOM-TYPE")])
```

### Preference Order

Use preference to indicate priority:

```swift
contact.emails = [
    VCard.Email(value: "primary@example.com", types: [.work], preference: 1),
    VCard.Email(value: "secondary@example.com", types: [.work], preference: 2)
]

// Lower preference number = higher priority
```

### Custom Properties

Add custom (X-) properties:

```swift
var contact = VCard()
contact.uid = UUID().uuidString
contact.formattedName = VCard.FormattedName(value: "John Doe")

// Add custom property
contact.customProperties["X-COMPANY-ID"] = ["12345"]
contact.customProperties["X-DEPARTMENT"] = ["Engineering"]

try await client.createContact(contact, in: addressBook)
```

## Best Practices

### 1. Always Use ETags for Updates

```swift
// ✅ Good
let (contact, etag) = try await client.fetchContact(uid: uid, from: addressBook)
var updated = contact
updated.emails.append(VCard.Email(value: "new@example.com", types: [.work]))
try await client.updateContact(updated, in: addressBook, etag: etag)

// ❌ Bad - race condition possible
var contact = try await client.fetchContact(uid: uid, from: addressBook)
contact.emails.append(VCard.Email(value: "new@example.com", types: [.work]))
try await client.updateContact(contact, in: addressBook, etag: nil)
```

### 2. Use Sync Tokens for Efficiency

```swift
// ✅ Good - only fetches changes
let result = try await client.sync(addressBook: addressBook, syncToken: lastToken)

// ❌ Bad - fetches all contacts every time
let contacts = try await client.fetchContacts(from: addressBook)
```

### 3. Validate Contact Data

```swift
func validateContact(_ contact: VCard) -> Bool {
    // Must have either formatted name or name
    guard contact.formattedName != nil || contact.name != nil else {
        return false
    }

    // Validate email format
    for email in contact.emails {
        guard email.value.contains("@") else {
            return false
        }
    }

    // Validate phone format (basic check)
    for phone in contact.telephones {
        guard !phone.value.isEmpty else {
            return false
        }
    }

    return true
}
```

### 4. Handle Photo Data Efficiently

```swift
// For display, use thumbnails
if let photoData = contact.photo?.data {
    // Resize for display
    let thumbnail = resizeImage(photoData, maxSize: 200)
    imageView.image = UIImage(data: thumbnail)
}

// For storage, consider external storage
if let photoData = contact.photo?.data, photoData.count > 100_000 {
    // Store photo separately and use URL reference
    let photoURL = try savePhotoToStorage(photoData)
    contact.photo = VCard.Photo(url: photoURL, mediaType: "image/jpeg")
}
```

### 5. Normalize Data

```swift
// Normalize phone numbers
func normalizePhoneNumber(_ phone: String) -> String {
    // Remove non-digits
    let digits = phone.filter { $0.isNumber }

    // Format consistently
    if digits.count == 10 {
        return "+1-\(digits.prefix(3))-\(digits.dropFirst(3).prefix(3))-\(digits.suffix(4))"
    }
    return phone
}

// Normalize email addresses
func normalizeEmail(_ email: String) -> String {
    return email.lowercased().trimmingCharacters(in: .whitespaces)
}

// Apply before saving
contact.emails = contact.emails.map { email in
    var normalized = email
    normalized.value = normalizeEmail(email.value)
    return normalized
}
```

### 6. Cache Address Book List

```swift
// Cache address book list to avoid frequent queries
actor AddressBookCache {
    private var addressBooks: [AddressBook]?
    private var lastUpdate: Date?
    private let cacheTimeout: TimeInterval = 3600 // 1 hour

    func getAddressBooks(from client: CardDAVClient) async throws -> [AddressBook] {
        if let books = addressBooks,
           let lastUpdate = lastUpdate,
           Date().timeIntervalSince(lastUpdate) < cacheTimeout {
            return books
        }

        let books = try await client.listAddressBooks()
        self.addressBooks = books
        self.lastUpdate = Date()
        return books
    }

    func invalidate() {
        addressBooks = nil
        lastUpdate = nil
    }
}
```

## See Also

- ``CardDAVClient``
- ``VCard``
- ``VCardParser``
- ``VCardSerializer``
- ``AddressBook``
- <doc:GettingStarted>
- <doc:ErrorHandling>
