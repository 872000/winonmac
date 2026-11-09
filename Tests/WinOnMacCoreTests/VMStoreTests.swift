import XCTest
@testable import WinOnMacCore

final class VMStoreTests: XCTestCase {

    func testAddValidVM() {
        var store = VMStore()
        XCTAssertTrue(store.add(makeValidConfig()))
        XCTAssertEqual(store.count, 1)
    }

    func testAddRejectsDuplicateNameCaseInsensitively() {
        var store = VMStore()
        XCTAssertTrue(store.add(makeValidConfig(name: "Windows 11")))
        XCTAssertFalse(store.add(makeValidConfig(name: "WINDOWS 11")))
        XCTAssertEqual(store.count, 1)
    }

    func testAddRejectsInvalidConfig() {
        var store = VMStore()
        XCTAssertFalse(store.add(makeValidConfig(cpuCount: 0)))
        XCTAssertTrue(store.isEmpty)
    }

    func testListIsSortedAlphabetically() {
        let store = VMStore(vms: [
            makeValidConfig(name: "Zeta"),
            makeValidConfig(name: "Alpha"),
            makeValidConfig(name: "Mid"),
        ])
        XCTAssertEqual(store.vms.map { $0.name }, ["Alpha", "Mid", "Zeta"])
    }

    func testInitDropsDuplicateNamesKeepingFirst() {
        let first = makeValidConfig(name: "Windows 11")
        let duplicate = makeValidConfig(name: "windows 11")
        let store = VMStore(vms: [first, duplicate])
        XCTAssertEqual(store.count, 1)
        XCTAssertEqual(store.vms.first?.id, first.id)
    }

    func testUpdateChangesConfig() {
        var store = VMStore()
        let original = makeValidConfig()
        store.add(original)
        var updated = original
        updated.memoryMB = 16_384
        XCTAssertTrue(store.update(updated))
        XCTAssertEqual(store.vm(id: original.id)?.memoryMB, 16_384)
    }

    func testUpdateRejectsNameCollisionWithAnotherVM() {
        var store = VMStore()
        let first = makeValidConfig(name: "Alpha")
        let second = makeValidConfig(name: "Beta")
        store.add(first)
        store.add(second)
        var renamed = second
        renamed.name = "Alpha"
        XCTAssertFalse(store.update(renamed))
        XCTAssertEqual(store.vm(id: second.id)?.name, "Beta")
    }

    func testUpdateRejectsUnknownID() {
        var store = VMStore()
        XCTAssertFalse(store.update(makeValidConfig()))
    }

    func testRemoveDeletesByID() {
        var store = VMStore()
        let vm = makeValidConfig()
        store.add(vm)
        XCTAssertTrue(store.remove(id: vm.id))
        XCTAssertFalse(store.remove(id: vm.id))
        XCTAssertTrue(store.isEmpty)
    }

    func testLookupByNameIsCaseInsensitive() {
        var store = VMStore()
        store.add(makeValidConfig(name: "Windows 11"))
        XCTAssertNotNil(store.vm(named: "WINDOWS 11"))
        XCTAssertNil(store.vm(named: "Windows 10"))
    }
}
