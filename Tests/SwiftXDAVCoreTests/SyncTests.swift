import XCTest
@testable import SwiftXDAVCore

final class SyncTests: XCTestCase {
    // MARK: - SyncToken Tests

    func testSyncTokenEquality() {
        let token1 = SyncToken("abc123")
        let token2 = SyncToken("abc123")
        let token3 = SyncToken("xyz789")

        XCTAssertEqual(token1, token2)
        XCTAssertNotEqual(token1, token3)
    }

    func testSyncTokenCodable() throws {
        let token = SyncToken("test-token-123")

        let encoder = JSONEncoder()
        let data = try encoder.encode(token)

        let decoder = JSONDecoder()
        let decodedToken = try decoder.decode(SyncToken.self, from: data)

        XCTAssertEqual(token, decodedToken)
    }

    // MARK: - SyncChange Tests

    func testSyncChangeTypes() {
        let url = URL(string: "https://example.com/event.ics")!

        let added = SyncChange(type: .added, url: url, etag: "123", data: nil)
        let modified = SyncChange(type: .modified, url: url, etag: "124", data: nil)
        let deleted = SyncChange(type: .deleted, url: url, etag: nil, data: nil)

        XCTAssertEqual(added.type, .added)
        XCTAssertEqual(modified.type, .modified)
        XCTAssertEqual(deleted.type, .deleted)

        XCTAssertNotNil(added.etag)
        XCTAssertNil(deleted.etag)
    }

    func testSyncChangeEquality() {
        let url = URL(string: "https://example.com/event.ics")!
        let data = "TESTDATA".data(using: .utf8)

        let change1 = SyncChange(type: .added, url: url, etag: "123", data: data)
        let change2 = SyncChange(type: .added, url: url, etag: "123", data: data)
        let change3 = SyncChange(type: .modified, url: url, etag: "124", data: data)

        XCTAssertEqual(change1, change2)
        XCTAssertNotEqual(change1, change3)
    }

    // MARK: - SyncResult Tests

    func testSyncResultCounts() {
        let url1 = URL(string: "https://example.com/event1.ics")!
        let url2 = URL(string: "https://example.com/event2.ics")!
        let url3 = URL(string: "https://example.com/event3.ics")!

        let changes = [
            SyncChange(type: .added, url: url1, etag: "1", data: nil),
            SyncChange(type: .added, url: url2, etag: "2", data: nil),
            SyncChange(type: .modified, url: url3, etag: "3", data: nil),
            SyncChange(type: .deleted, url: url1, etag: nil, data: nil)
        ]

        let result = SyncResult(
            newSyncToken: SyncToken("new-token"),
            changes: changes,
            isInitialSync: false
        )

        XCTAssertEqual(result.addedCount, 2)
        XCTAssertEqual(result.modifiedCount, 1)
        XCTAssertEqual(result.deletedCount, 1)
        XCTAssertTrue(result.hasChanges)
    }

    func testSyncResultEmptyChanges() {
        let result = SyncResult(
            newSyncToken: SyncToken("token"),
            changes: [],
            isInitialSync: false
        )

        XCTAssertEqual(result.addedCount, 0)
        XCTAssertEqual(result.modifiedCount, 0)
        XCTAssertEqual(result.deletedCount, 0)
        XCTAssertFalse(result.hasChanges)
    }

    func testSyncResultInitialSync() {
        let changes = [
            SyncChange(type: .added, url: URL(string: "https://example.com/1.ics")!, etag: "1", data: nil)
        ]

        let result = SyncResult(
            newSyncToken: SyncToken("initial-token"),
            changes: changes,
            isInitialSync: true
        )

        XCTAssertTrue(result.isInitialSync)
        XCTAssertEqual(result.changes.count, 1)
    }

    // MARK: - ConflictResolution Tests

    func testConflictVersion() {
        let etag = "abc123"
        let data = "TEST".data(using: .utf8)!
        let date = Date()

        let version = ConflictVersion(etag: etag, data: data, lastModified: date)

        XCTAssertEqual(version.etag, etag)
        XCTAssertEqual(version.data, data)
        XCTAssertEqual(version.lastModified, date)
    }

    func testSyncConflict() {
        let url = URL(string: "https://example.com/event.ics")!
        let localData = "LOCAL".data(using: .utf8)!
        let remoteData = "REMOTE".data(using: .utf8)!

        let conflict = SyncConflict(
            url: url,
            localVersion: ConflictVersion(etag: "local", data: localData),
            remoteVersion: ConflictVersion(etag: "remote", data: remoteData)
        )

        XCTAssertEqual(conflict.url, url)
        XCTAssertEqual(conflict.localVersion.etag, "local")
        XCTAssertEqual(conflict.remoteVersion.etag, "remote")
    }

    func testConflictResolutionStrategyEquality() {
        XCTAssertEqual(ConflictResolutionStrategy.useLocal, .useLocal)
        XCTAssertEqual(ConflictResolutionStrategy.useRemote, .useRemote)
        XCTAssertEqual(ConflictResolutionStrategy.useNewest, .useNewest)
        XCTAssertEqual(ConflictResolutionStrategy.createDuplicate, .createDuplicate)
        XCTAssertEqual(ConflictResolutionStrategy.fail, .fail)

        XCTAssertNotEqual(ConflictResolutionStrategy.useLocal, .useRemote)
    }

    func testSyncOptions() {
        let options = SyncOptions()

        // Default options
        XCTAssertEqual(options.conflictResolution, .useRemote)
        XCTAssertTrue(options.validateETags)
        XCTAssertTrue(options.fetchFullData)
    }

    func testSyncOptionsFast() {
        let options = SyncOptions.fast

        XCTAssertFalse(options.fetchFullData)
    }

    func testSyncOptionsSafe() {
        let options = SyncOptions.safe

        XCTAssertEqual(options.conflictResolution, .fail)
        XCTAssertTrue(options.validateETags)
    }

    func testSyncOptionsCustom() {
        let options = SyncOptions(
            conflictResolution: .useLocal,
            validateETags: false,
            fetchFullData: false
        )

        XCTAssertEqual(options.conflictResolution, .useLocal)
        XCTAssertFalse(options.validateETags)
        XCTAssertFalse(options.fetchFullData)
    }
}
