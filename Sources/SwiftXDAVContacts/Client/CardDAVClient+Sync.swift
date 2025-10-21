import Foundation
import SwiftXDAVCore
import SwiftXDAVNetwork

// MARK: - CardDAV Sync Support

extension CardDAVClient {
    /// Synchronize an address book using sync-tokens (RFC 6578)
    ///
    /// This method performs efficient synchronization by requesting only changes
    /// since the last sync. On first sync (when `syncToken` is nil), all contacts
    /// are returned. Subsequent syncs return only additions, modifications, and deletions.
    ///
    /// - Parameters:
    ///   - addressBook: The address book to synchronize
    ///   - syncToken: The sync token from the previous sync (nil for initial sync)
    ///   - options: Sync options including conflict resolution strategy
    /// - Returns: A sync result containing changes and the new sync token
    /// - Throws: `SwiftXDAVError.syncTokenExpired` if the token is no longer valid
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Initial sync
    /// let result = try await client.syncAddressBook(addressBook, syncToken: nil)
    /// print("Initial sync: \(result.changes.count) contacts")
    /// saveToken(result.newSyncToken)
    ///
    /// // Delta sync
    /// let deltaResult = try await client.syncAddressBook(addressBook, syncToken: savedToken)
    /// print("Delta sync: \(deltaResult.addedCount) added, \(deltaResult.modifiedCount) modified, \(deltaResult.deletedCount) deleted")
    /// saveToken(deltaResult.newSyncToken)
    /// ```
    ///
    /// ## Handling Expired Tokens
    ///
    /// If the sync token has expired, the server returns a 410 Gone or 403 Forbidden status.
    /// Catch `SwiftXDAVError.syncTokenExpired` and perform a full sync:
    ///
    /// ```swift
    /// do {
    ///     let result = try await client.syncAddressBook(addressBook, syncToken: savedToken)
    ///     // Process delta changes
    /// } catch SwiftXDAVError.syncTokenExpired {
    ///     // Token expired, do full sync
    ///     let fullSync = try await client.syncAddressBook(addressBook, syncToken: nil)
    ///     // Reload all contacts
    /// }
    /// ```
    public func syncAddressBook(
        _ addressBook: AddressBook,
        syncToken: SyncToken?,
        options: SyncOptions = .default
    ) async throws -> SyncResult {
        // Create sync-collection request
        let request = SyncCollectionRequest(
            url: addressBook.url,
            syncToken: syncToken,
            properties: [
                DAVPropertyName.getETag,
                CardDAVPropertyName.addressData
            ],
            fetchResourceData: options.fetchFullData
        )

        // Execute the sync request
        let response = try await request.execute(using: httpClient)

        // Convert to sync changes
        var changes: [SyncChange] = []
        let parser = VCardParser()

        // Process deletions
        for url in response.deletedResources {
            let change = SyncChange(
                type: .deleted,
                url: url,
                etag: nil,
                data: nil
            )
            changes.append(change)
        }

        // Process additions and modifications
        for resource in response.changedResources {
            // Determine if this is an addition or modification
            let changeType: SyncChange.ChangeType = syncToken == nil ? .added : .modified

            var data: Data?

            // Fetch full data if needed
            if options.fetchFullData {
                // Check if address-data is in properties
                if let addressData = resource.properties["address-data"] {
                    data = addressData.data(using: .utf8)
                } else {
                    // Fetch the resource separately
                    let webdav = WebDAVOperations(client: httpClient)
                    let (fetchedData, _) = try await webdav.get(from: resource.url)
                    data = fetchedData
                }
            }

            let change = SyncChange(
                type: changeType,
                url: resource.url,
                etag: resource.etag,
                data: data
            )
            changes.append(change)
        }

        return SyncResult(
            newSyncToken: response.newSyncToken,
            changes: changes,
            isInitialSync: syncToken == nil
        )
    }

    /// Synchronize and parse contacts from an address book
    ///
    /// This is a convenience method that performs a sync and returns the parsed vCards.
    /// Deletions are returned as vCards with only the UID populated.
    ///
    /// - Parameters:
    ///   - addressBook: The address book to synchronize
    ///   - syncToken: The sync token from the previous sync
    /// - Returns: Tuple of new sync token and array of vCard changes
    /// - Throws: `SwiftXDAVError` if sync fails
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let (newToken, contactChanges) = try await client.syncAddressBookContacts(
    ///     addressBook,
    ///     syncToken: lastToken
    /// )
    ///
    /// for (changeType, vcard) in contactChanges {
    ///     switch changeType {
    ///     case .added:
    ///         database.insert(vcard)
    ///     case .modified:
    ///         database.update(vcard)
    ///     case .deleted:
    ///         database.delete(uid: vcard.uid)
    ///     }
    /// }
    ///
    /// saveToken(newToken)
    /// ```
    public func syncAddressBookContacts(
        _ addressBook: AddressBook,
        syncToken: SyncToken?
    ) async throws -> (newToken: SyncToken, changes: [(SyncChange.ChangeType, VCard)]) {
        let result = try await syncAddressBook(addressBook, syncToken: syncToken)

        var contactChanges: [(SyncChange.ChangeType, VCard)] = []
        let parser = VCardParser()

        for change in result.changes {
            switch change.type {
            case .added, .modified:
                guard let data = change.data else {
                    continue
                }

                do {
                    let vcard = try await parser.parse(data)
                    contactChanges.append((change.type, vcard))
                } catch {
                    // Skip malformed vCards
                    continue
                }

            case .deleted:
                // Create a minimal vCard with just the UID for deletion
                // Extract UID from URL (typically /path/to/UUID.vcf)
                let uid = change.url.deletingPathExtension().lastPathComponent
                let deletedContact = VCard(uid: uid)
                contactChanges.append((.deleted, deletedContact))
            }
        }

        return (result.newSyncToken, contactChanges)
    }
}

// MARK: - ETag-Based Sync (Fallback)

extension CardDAVClient {
    /// Synchronize using ETags when sync-tokens are not supported
    ///
    /// This is a fallback mechanism for servers that don't support RFC 6578.
    /// It compares ETags of all resources to detect changes.
    ///
    /// - Parameters:
    ///   - addressBook: The address book to synchronize
    ///   - knownETags: Dictionary of URL to ETag from the last sync
    /// - Returns: Dictionary of changes (URL -> ETag) and list of deletions
    /// - Throws: `SwiftXDAVError` if the operation fails
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Store ETags from last sync
    /// var etags: [URL: String] = loadETags()
    ///
    /// let result = try await client.syncAddressBookWithETags(addressBook, knownETags: etags)
    ///
    /// // Process changes
    /// for (url, newETag) in result.changes {
    ///     let (data, _) = try await operations.get(from: url)
    ///     // Update local copy
    ///     etags[url] = newETag
    /// }
    ///
    /// // Process deletions
    /// for url in result.deletions {
    ///     // Remove local copy
    ///     etags.removeValue(forKey: url)
    /// }
    ///
    /// saveETags(etags)
    /// ```
    public func syncAddressBookWithETags(
        _ addressBook: AddressBook,
        knownETags: [URL: String]
    ) async throws -> (changes: [URL: String], deletions: [URL]) {
        // Fetch all resources with their ETags
        let request = PropfindRequest(
            url: addressBook.url,
            depth: 1,
            properties: [
                DAVPropertyName.getETag,
                DAVPropertyName.getContentType
            ]
        )

        let responses = try await request.execute(using: httpClient)

        var changes: [URL: String] = [:]
        var currentURLs = Set<URL>()

        for response in responses {
            // Skip the collection itself
            if response.href == addressBook.url.path || response.href == addressBook.url.path + "/" {
                continue
            }

            guard let url = URL(string: response.href, relativeTo: addressBook.url)?.absoluteURL,
                  let newETag = response.property(named: "getetag") else {
                continue
            }

            currentURLs.insert(url)

            // Check if this is new or modified
            if let oldETag = knownETags[url] {
                // Resource exists, check if modified
                if oldETag != newETag {
                    changes[url] = newETag
                }
            } else {
                // New resource
                changes[url] = newETag
            }
        }

        // Find deletions (resources that were in knownETags but not in current)
        let deletions = Set(knownETags.keys).subtracting(currentURLs)

        return (changes, Array(deletions))
    }
}

// MARK: - CTag-Based Change Detection

extension CardDAVClient {
    /// Check if an address book has changes using CTag
    ///
    /// CTag (collection tag) is a quick way to check if any changes occurred
    /// in a collection. If the CTag hasn't changed, no sync is needed.
    ///
    /// - Parameter addressBook: The address book to check
    /// - Returns: The current CTag, or nil if CTag is not supported
    /// - Throws: `SwiftXDAVError` if the operation fails
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let lastCTag = loadCTag()
    ///
    /// if let currentCTag = try await client.getAddressBookCTag(addressBook) {
    ///     if currentCTag != lastCTag {
    ///         // Address book has changed, perform sync
    ///         let result = try await client.syncAddressBook(addressBook, syncToken: lastToken)
    ///         saveCTag(currentCTag)
    ///     } else {
    ///         // No changes, skip sync
    ///         print("Address book unchanged")
    ///     }
    /// }
    /// ```
    public func getAddressBookCTag(_ addressBook: AddressBook) async throws -> String? {
        let request = PropfindRequest(
            url: addressBook.url,
            depth: 0,
            properties: [CardDAVPropertyName.getctag]
        )

        let responses = try await request.execute(using: httpClient)

        guard let response = responses.first else {
            return nil
        }

        return response.property(named: "getctag")
    }

    /// Check if address book needs sync by comparing CTags
    ///
    /// - Parameters:
    ///   - addressBook: The address book to check
    ///   - knownCTag: The CTag from the last sync
    /// - Returns: True if the address book has changed
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func addressBookNeedsSync(_ addressBook: AddressBook, knownCTag: String?) async throws -> Bool {
        guard let currentCTag = try await getAddressBookCTag(addressBook) else {
            // CTag not supported, assume changes
            return true
        }

        return currentCTag != knownCTag
    }
}
