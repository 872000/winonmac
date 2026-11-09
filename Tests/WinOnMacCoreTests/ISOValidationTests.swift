import XCTest
@testable import WinOnMacCore

final class ISOValidationTests: XCTestCase {

    func testISOExtensionDetected() {
        XCTAssertTrue(ISOValidation.looksLikeISO(path: "/tmp/Win11_ARM64.iso"))
    }

    func testISOExtensionIsCaseInsensitive() {
        XCTAssertTrue(ISOValidation.looksLikeISO(path: "/tmp/Win11_ARM64.ISO"))
    }

    func testNonISOExtensionRejected() {
        XCTAssertFalse(ISOValidation.looksLikeISO(path: "/tmp/Win11_ARM64.img"))
        XCTAssertFalse(ISOValidation.looksLikeISO(path: "/tmp/Win11_ARM64.dmg"))
        XCTAssertFalse(ISOValidation.looksLikeISO(path: "/tmp/Win11_ARM64"))
    }

    func testBaseNameStripsExtension() {
        XCTAssertEqual(ISOValidation.baseName(of: "/Users/parth/Downloads/Win11_24H2_ARM64.iso"), "Win11_24H2_ARM64")
    }

    func testWindows11ARMFileNameRecognised() {
        XCTAssertTrue(ISOValidation.looksLikeWindows11ARMISO(fileName: "Win11_24H2_ARM64.iso"))
        XCTAssertTrue(ISOValidation.looksLikeWindows11ARMISO(fileName: "Windows11_ARM64.iso"))
    }

    func testNonWindowsOrNonARMFileNameNotRecognised() {
        XCTAssertFalse(ISOValidation.looksLikeWindows11ARMISO(fileName: "Win11_24H2_x64.iso"))
        XCTAssertFalse(ISOValidation.looksLikeWindows11ARMISO(fileName: "Ubuntu_ARM64.iso"))
        XCTAssertFalse(ISOValidation.looksLikeWindows11ARMISO(fileName: "Win10_ARM64.iso"))
    }

    func testPlausibleSizeThreshold() {
        XCTAssertTrue(ISOValidation.isPlausibleSize(bytes: 5_000_000_000))
        XCTAssertFalse(ISOValidation.isPlausibleSize(bytes: 1_000_000_000))
        XCTAssertTrue(ISOValidation.isPlausibleSize(bytes: ISOValidation.minimumISOSizeBytes))
        XCTAssertFalse(ISOValidation.isPlausibleSize(bytes: ISOValidation.minimumISOSizeBytes - 1))
    }

    func testFileInfoReadyToUseWhenExtensionAndSizePass() {
        let info = ISOValidation.ISOFileInfo(path: "/tmp/Win11_24H2_ARM64.iso", sizeBytes: 5_500_000_000)
        XCTAssertTrue(info.hasISOExtension)
        XCTAssertTrue(info.hasPlausibleSize)
        XCTAssertTrue(info.looksLikeWindows11ARM)
        XCTAssertTrue(info.isReadyToUse)
    }

    func testFileInfoNotReadyWhenTooSmall() {
        let info = ISOValidation.ISOFileInfo(path: "/tmp/Win11_24H2_ARM64.iso", sizeBytes: 100_000)
        XCTAssertFalse(info.isReadyToUse)
    }

    func testFileInfoNotReadyWhenSizeUnknown() {
        let info = ISOValidation.ISOFileInfo(path: "/tmp/Win11_24H2_ARM64.iso", sizeBytes: nil)
        XCTAssertFalse(info.isReadyToUse)
        XCTAssertEqual(info.formattedSize, "Unknown size")
    }

    func testFormattedSize() {
        let info = ISOValidation.ISOFileInfo(path: "/tmp/a.iso", sizeBytes: 5_865_697_280)
        XCTAssertEqual(info.formattedSize, "5.5 GB")
    }
}
