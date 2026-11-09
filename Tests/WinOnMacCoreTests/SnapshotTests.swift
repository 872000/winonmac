import XCTest
@testable import WinOnMacCore

final class SnapshotTests: XCTestCase {

    func testBlankSnapshotNameIsInvalid() {
        XCTAssertNotNil(SnapshotValidation.validateName("   "))
    }

    func testLongSnapshotNameIsInvalid() {
        XCTAssertNotNil(SnapshotValidation.validateName(String(repeating: "S", count: 65)))
    }

    func testNormalSnapshotNameIsValid() {
        XCTAssertNil(SnapshotValidation.validateName("Before Windows Update"))
    }

    func testFormattedSize() {
        XCTAssertEqual(makeSnapshot(diskSizeBytes: 12_884_901_888).formattedSize, "12.0 GB")
    }

    func testLibrarySortsNewestFirst() {
        let older = makeSnapshot(name: "Older", createdAt: Date(timeIntervalSince1970: 1_700_000_000))
        let newer = makeSnapshot(name: "Newer", createdAt: Date(timeIntervalSince1970: 1_700_100_000))
        let library = SnapshotLibrary(snapshots: [older, newer])
        XCTAssertEqual(library.snapshots.map { $0.name }, ["Newer", "Older"])
    }

    func testAddRejectsDuplicateID() {
        var library = SnapshotLibrary()
        let snapshot = makeSnapshot()
        XCTAssertTrue(library.add(snapshot))
        XCTAssertFalse(library.add(snapshot))
        XCTAssertEqual(library.count, 1)
    }

    func testAddRejectsBlankName() {
        var library = SnapshotLibrary()
        XCTAssertFalse(library.add(makeSnapshot(name: "  ")))
        XCTAssertEqual(library.count, 0)
    }

    func testRemoveDeletesAndReports() {
        var library = SnapshotLibrary()
        let snapshot = makeSnapshot()
        library.add(snapshot)
        XCTAssertTrue(library.remove(id: snapshot.id))
        XCTAssertFalse(library.remove(id: snapshot.id))
        XCTAssertEqual(library.count, 0)
    }

    func testTotalSizeSumsSnapshots() {
        var library = SnapshotLibrary()
        library.add(makeSnapshot(diskSizeBytes: 1_073_741_824))
        library.add(makeSnapshot(name: "Second", diskSizeBytes: 2_147_483_648))
        XCTAssertEqual(library.totalSizeBytes, 3_221_225_472)
    }

    func testSnapshotsFilteredByVM() {
        let vmA = UUID()
        let vmB = UUID()
        let library = SnapshotLibrary(snapshots: [
            makeSnapshot(vmID: vmA, name: "A1"),
            makeSnapshot(vmID: vmB, name: "B1"),
            makeSnapshot(vmID: vmA, name: "A2"),
        ])
        XCTAssertEqual(library.snapshots(for: vmA).count, 2)
        XCTAssertEqual(library.snapshots(for: vmB).count, 1)
    }

    func testCanRestoreOnlyOntoSameVM() {
        let vmA = UUID()
        let vmB = UUID()
        let library = SnapshotLibrary()
        let snapshot = makeSnapshot(vmID: vmA)
        XCTAssertTrue(library.canRestore(snapshot, onto: vmA))
        XCTAssertFalse(library.canRestore(snapshot, onto: vmB))
    }

    func testJSONRoundTripPreservesSnapshot() throws {
        let snapshot = makeSnapshot()
        let data = try JSONEncoder().encode(snapshot)
        let decoded = try JSONDecoder().decode(SnapshotMetadata.self, from: data)
        XCTAssertEqual(decoded, snapshot)
    }
}
