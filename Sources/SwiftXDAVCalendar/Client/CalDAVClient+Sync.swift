import Foundation
import SwiftXDAVCore
import SwiftXDAVNetwork

// MARK: - CalDAV Sync Support

extension CalDAVClient {
    /// Synchronize a calendar using sync-tokens (RFC 6578)
    ///
    /// This method performs efficient synchronization by requesting only changes
    /// since the last sync. On first sync (when `syncToken` is nil), all events
    /// are returned. Subsequent syncs return only additions, modifications, and deletions.
    ///
    /// - Parameters:
    ///   - calendar: The calendar to synchronize
    ///   - syncToken: The sync token from the previous sync (nil for initial sync)
    ///   - options: Sync options including conflict resolution strategy
    /// - Returns: A sync result containing changes and the new sync token
    /// - Throws: `SwiftXDAVError.syncTokenExpired` if the token is no longer valid
    ///
    /// ## Usage
    ///
    /// ```swift
    /// // Initial sync
    /// let result = try await client.syncCalendar(calendar, syncToken: nil)
    /// print("Initial sync: \(result.changes.count) events")
    /// saveToken(result.newSyncToken)
    ///
    /// // Delta sync
    /// let deltaResult = try await client.syncCalendar(calendar, syncToken: savedToken)
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
    ///     let result = try await client.syncCalendar(calendar, syncToken: savedToken)
    ///     // Process delta changes
    /// } catch SwiftXDAVError.syncTokenExpired {
    ///     // Token expired, do full sync
    ///     let fullSync = try await client.syncCalendar(calendar, syncToken: nil)
    ///     // Reload all events
    /// }
    /// ```
    public func syncCalendar(
        _ calendar: Calendar,
        syncToken: SyncToken?,
        options: SyncOptions = .default
    ) async throws -> SyncResult {
        // Create sync-collection request
        let request = SyncCollectionRequest(
            url: calendar.url,
            syncToken: syncToken,
            properties: [
                DAVPropertyName.getETag,
                CalDAVPropertyName.calendarData
            ],
            fetchResourceData: options.fetchFullData
        )

        // Execute the sync request
        let response = try await request.execute(using: httpClient)

        // Convert to sync changes
        var changes: [SyncChange] = []
        let parser = ICalendarParser()

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
            // (We can't easily tell from sync-collection response, so we treat all as modified)
            let changeType: SyncChange.ChangeType = syncToken == nil ? .added : .modified

            var data: Data?

            // Fetch full data if needed
            if options.fetchFullData {
                // Check if calendar-data is in properties
                if let calendarData = resource.properties["calendar-data"] {
                    data = calendarData.data(using: .utf8)
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

    /// Synchronize and parse events from a calendar
    ///
    /// This is a convenience method that performs a sync and returns the parsed events.
    /// Deletions are returned as events with only the UID populated.
    ///
    /// - Parameters:
    ///   - calendar: The calendar to synchronize
    ///   - syncToken: The sync token from the previous sync
    /// - Returns: Tuple of new sync token and array of event changes
    /// - Throws: `SwiftXDAVError` if sync fails
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let (newToken, eventChanges) = try await client.syncCalendarEvents(
    ///     calendar,
    ///     syncToken: lastToken
    /// )
    ///
    /// for (changeType, event) in eventChanges {
    ///     switch changeType {
    ///     case .added:
    ///         database.insert(event)
    ///     case .modified:
    ///         database.update(event)
    ///     case .deleted:
    ///         database.delete(uid: event.uid)
    ///     }
    /// }
    ///
    /// saveToken(newToken)
    /// ```
    public func syncCalendarEvents(
        _ calendar: Calendar,
        syncToken: SyncToken?
    ) async throws -> (newToken: SyncToken, changes: [(SyncChange.ChangeType, VEvent)]) {
        let result = try await syncCalendar(calendar, syncToken: syncToken)

        var eventChanges: [(SyncChange.ChangeType, VEvent)] = []
        let parser = ICalendarParser()

        for change in result.changes {
            switch change.type {
            case .added, .modified:
                guard let data = change.data else {
                    continue
                }

                do {
                    let ical = try await parser.parse(data)
                    for event in ical.events {
                        eventChanges.append((change.type, event))
                    }
                } catch {
                    // Skip malformed events
                    continue
                }

            case .deleted:
                // Create a minimal event with just the UID for deletion
                // Extract UID from URL (typically /path/to/UUID.ics)
                let uid = change.url.deletingPathExtension().lastPathComponent
                let deletedEvent = VEvent(uid: uid)
                eventChanges.append((.deleted, deletedEvent))
            }
        }

        return (result.newSyncToken, eventChanges)
    }
}

// MARK: - ETag-Based Sync (Fallback)

extension CalDAVClient {
    /// Synchronize using ETags when sync-tokens are not supported
    ///
    /// This is a fallback mechanism for servers that don't support RFC 6578.
    /// It compares ETags of all resources to detect changes.
    ///
    /// - Parameters:
    ///   - calendar: The calendar to synchronize
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
    /// let result = try await client.syncCalendarWithETags(calendar, knownETags: etags)
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
    public func syncCalendarWithETags(
        _ calendar: Calendar,
        knownETags: [URL: String]
    ) async throws -> (changes: [URL: String], deletions: [URL]) {
        // Fetch all resources with their ETags
        let request = PropfindRequest(
            url: calendar.url,
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
            if response.href == calendar.url.path || response.href == calendar.url.path + "/" {
                continue
            }

            guard let url = URL(string: response.href, relativeTo: calendar.url)?.absoluteURL,
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

extension CalDAVClient {
    /// Check if a calendar has changes using CTag
    ///
    /// CTag (collection tag) is a quick way to check if any changes occurred
    /// in a collection. If the CTag hasn't changed, no sync is needed.
    ///
    /// - Parameters:
    ///   - calendar: The calendar to check
    ///   - knownCTag: The CTag from the last check
    /// - Returns: The current CTag, or nil if CTag is not supported
    /// - Throws: `SwiftXDAVError` if the operation fails
    ///
    /// ## Usage
    ///
    /// ```swift
    /// let lastCTag = loadCTag()
    ///
    /// if let currentCTag = try await client.getCalendarCTag(calendar, knownCTag: lastCTag) {
    ///     if currentCTag != lastCTag {
    ///         // Calendar has changed, perform sync
    ///         let result = try await client.syncCalendar(calendar, syncToken: lastToken)
    ///         saveCTag(currentCTag)
    ///     } else {
    ///         // No changes, skip sync
    ///         print("Calendar unchanged")
    ///     }
    /// }
    /// ```
    public func getCalendarCTag(_ calendar: Calendar) async throws -> String? {
        let request = PropfindRequest(
            url: calendar.url,
            depth: 0,
            properties: [CalDAVPropertyName.getctag]
        )

        let responses = try await request.execute(using: httpClient)

        guard let response = responses.first else {
            return nil
        }

        return response.property(named: "getctag")
    }

    /// Check if calendar needs sync by comparing CTags
    ///
    /// - Parameters:
    ///   - calendar: The calendar to check
    ///   - knownCTag: The CTag from the last sync
    /// - Returns: True if the calendar has changed
    /// - Throws: `SwiftXDAVError` if the operation fails
    public func calendarNeedsSync(_ calendar: Calendar, knownCTag: String?) async throws -> Bool {
        guard let currentCTag = try await getCalendarCTag(calendar) else {
            // CTag not supported, assume changes
            return true
        }

        return currentCTag != knownCTag
    }
}
