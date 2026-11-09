import XCTest
@testable import WinOnMacCore

final class VMValidationTests: XCTestCase {

    func testValidConfigHasNoErrors() {
        XCTAssertTrue(VMValidation.validate(makeValidConfig()).isEmpty)
        XCTAssertTrue(VMValidation.isValid(makeValidConfig()))
    }

    func testBlankNameIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(name: "   "))
        XCTAssertTrue(errors.contains { $0.field == "name" })
    }

    func testNameOver64CharactersIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(name: String(repeating: "W", count: 65)))
        XCTAssertTrue(errors.contains { $0.field == "name" })
    }

    func testNameOfExactly64CharactersIsValid() {
        XCTAssertTrue(VMValidation.isValid(makeValidConfig(name: String(repeating: "W", count: 64))))
    }

    func testZeroCPUsIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(cpuCount: 0))
        XCTAssertTrue(errors.contains { $0.field == "cpuCount" })
    }

    func testTooManyCPUsIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(cpuCount: 17))
        XCTAssertTrue(errors.contains { $0.field == "cpuCount" })
    }

    func testMemoryBelowWindows11MinimumIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(memoryMB: 2_048))
        XCTAssertTrue(errors.contains { $0.field == "memoryMB" })
    }

    func testMemoryNotAMultipleOfOneGigabyteIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(memoryMB: 4_500))
        XCTAssertTrue(errors.contains { $0.field == "memoryMB" })
    }

    func testMemoryOfExactly4GBIsValid() {
        XCTAssertTrue(VMValidation.isValid(makeValidConfig(memoryMB: 4_096)))
    }

    func testDiskBelow64GBIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(diskSizeGB: 32))
        XCTAssertTrue(errors.contains { $0.field == "diskSizeGB" })
    }

    func testMissingISOIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(isoPath: ""))
        XCTAssertTrue(errors.contains { $0.field == "isoPath" })
    }

    func testNonISOFileIsAnError() {
        let errors = VMValidation.validate(makeValidConfig(isoPath: "/Users/parth/Downloads/windows.exe"))
        XCTAssertTrue(errors.contains { $0.field == "isoPath" })
    }

    func testUppercaseISOExtensionIsAccepted() {
        XCTAssertTrue(VMValidation.isValid(makeValidConfig(isoPath: "/Users/parth/Downloads/WIN11.ISO")))
    }

    func testAllProblemsAreReportedAtOnce() {
        let config = makeValidConfig(name: "", cpuCount: 0, memoryMB: 512, diskSizeGB: 10, isoPath: "")
        let errors = VMValidation.validate(config)
        XCTAssertGreaterThanOrEqual(errors.count, 5)
        let fields = Set(errors.map { $0.field })
        XCTAssertTrue(fields.contains("name"))
        XCTAssertTrue(fields.contains("cpuCount"))
        XCTAssertTrue(fields.contains("memoryMB"))
        XCTAssertTrue(fields.contains("diskSizeGB"))
        XCTAssertTrue(fields.contains("isoPath"))
    }

    func testInvalidSharedFolderSurfacesUnderSharedFoldersField() {
        var config = makeValidConfig()
        config.sharedFolders = [SharedFolder(hostPath: "/Users/parth/Documents", tag: "bad tag!")]
        let errors = VMValidation.validate(config)
        XCTAssertTrue(errors.contains { $0.field.hasPrefix("sharedFolders.") })
    }

    func testInvalidDisplaySurfacesAsError() {
        var config = makeValidConfig()
        config.display = DisplaySettings(width: 100, height: 100)
        XCTAssertFalse(VMValidation.validate(config).isEmpty)
    }
}
