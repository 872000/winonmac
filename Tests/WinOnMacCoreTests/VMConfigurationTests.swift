import XCTest
@testable import WinOnMacCore

final class VMConfigurationTests: XCTestCase {

    func testDefaultsAreWindows11Sane() {
        let config = VMConfiguration.default
        XCTAssertEqual(config.cpuCount, 4)
        XCTAssertEqual(config.memoryMB, 8_192)
        XCTAssertEqual(config.diskSizeGB, 128)
        XCTAssertEqual(config.display, DisplaySettings(width: 1_920, height: 1_080))
    }

    func testMemoryBytesConversion() {
        let config = makeValidConfig(memoryMB: 8_192)
        XCTAssertEqual(config.memoryBytes, 8_589_934_592)
    }

    func testDiskSizeBytesConversion() {
        let config = makeValidConfig(diskSizeGB: 128)
        XCTAssertEqual(config.diskSizeBytes, 137_438_953_472)
    }

    func testSummaryString() {
        XCTAssertEqual(makeValidConfig().summary, "4 vCPU · 8 GB RAM · 128 GB disk")
    }

    func testSanitizedDirectoryNameReplacesSpaces() {
        XCTAssertEqual(makeValidConfig(name: "My Windows VM").sanitizedDirectoryName, "My-Windows-VM")
    }

    func testSanitizedDirectoryNameStripsUnsafeCharacters() {
        XCTAssertEqual(makeValidConfig(name: "Win: 11/ARM?").sanitizedDirectoryName, "Win-11ARM")
    }

    func testSanitizedDirectoryNameFallsBackWhenNothingIsSafe() {
        XCTAssertEqual(makeValidConfig(name: "!!!").sanitizedDirectoryName, "Windows-11")
    }

    func testClampedFixesOutOfRangeResources() {
        let config = makeValidConfig(cpuCount: 99, memoryMB: 100, diskSizeGB: 9_999).clamped()
        XCTAssertEqual(config.cpuCount, 16)
        XCTAssertEqual(config.memoryMB, 4_096)
        XCTAssertEqual(config.diskSizeGB, 2_048)
    }

    func testClampedRoundsMemoryDownToWholeGigabytes() {
        let config = makeValidConfig(memoryMB: 8_500).clamped()
        XCTAssertEqual(config.memoryMB, 8_192)
    }

    func testClampedLeavesValidConfigAlone() {
        let config = makeValidConfig()
        XCTAssertEqual(config.clamped(), config)
    }

    func testJSONRoundTripPreservesConfiguration() throws {
        let config = makeValidConfig()
        let data = try JSONEncoder().encode(config)
        let decoded = try JSONDecoder().decode(VMConfiguration.self, from: data)
        XCTAssertEqual(decoded, config)
    }
}
