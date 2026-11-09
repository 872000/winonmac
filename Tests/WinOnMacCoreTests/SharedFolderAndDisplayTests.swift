import XCTest
@testable import WinOnMacCore

final class SharedFolderTests: XCTestCase {

    func testValidFolderHasNoErrors() {
        let folder = SharedFolder(hostPath: "/Users/parth/Documents", tag: "Documents")
        XCTAssertTrue(SharedFolderValidation.validate(folder).isEmpty)
    }

    func testBlankHostPathIsAnError() {
        let folder = SharedFolder(hostPath: "   ", tag: "Docs")
        XCTAssertTrue(SharedFolderValidation.validate(folder).contains { $0.field == "hostPath" })
    }

    func testRelativeHostPathIsAnError() {
        let folder = SharedFolder(hostPath: "Documents/shared", tag: "Docs")
        XCTAssertTrue(SharedFolderValidation.validate(folder).contains { $0.field == "hostPath" })
    }

    func testTagWithSpacesIsRejected() {
        XCTAssertNotNil(SharedFolderValidation.validateTag("My Documents"))
    }

    func testTagWithSlashIsRejected() {
        XCTAssertNotNil(SharedFolderValidation.validateTag("docs/shared"))
    }

    func testTagWithHyphensAndUnderscoresIsAccepted() {
        XCTAssertNil(SharedFolderValidation.validateTag("my-docs_2026"))
    }

    func testBlankTagIsRejected() {
        XCTAssertNotNil(SharedFolderValidation.validateTag(""))
    }

    func testTagOver64CharactersIsRejected() {
        XCTAssertNotNil(SharedFolderValidation.validateTag(String(repeating: "a", count: 65)))
    }

    func testSuggestedTagUsesLastPathComponent() {
        XCTAssertEqual(SharedFolderValidation.suggestedTag(for: "/Users/parth/Documents"), "Documents")
    }

    func testSuggestedTagReplacesSpacesWithHyphens() {
        XCTAssertEqual(SharedFolderValidation.suggestedTag(for: "/Users/parth/My Photos"), "My-Photos")
    }

    func testSuggestedTagFallsBackForRootPath() {
        XCTAssertEqual(SharedFolderValidation.suggestedTag(for: "/"), "Shared")
    }
}

final class DisplaySettingsTests: XCTestCase {

    func testDefaultIs1080p() {
        XCTAssertEqual(DisplaySettings.default, DisplaySettings(width: 1_920, height: 1_080))
        XCTAssertEqual(DisplaySettings.default.label, "1920 × 1080")
    }

    func testPresetsAreRecognised() {
        XCTAssertTrue(DisplaySettings(width: 1_920, height: 1_080).isPreset)
        XCTAssertTrue(DisplaySettings(width: 3_840, height: 2_160).isPreset)
        XCTAssertFalse(DisplaySettings(width: 1_600, height: 900).isPreset)
    }

    func testFourPresetsOffered() {
        XCTAssertEqual(DisplaySettings.presets.count, 4)
    }

    func testTooSmallDisplayIsAnError() {
        let errors = DisplaySettingsValidation.validate(DisplaySettings(width: 640, height: 480))
        XCTAssertEqual(errors.count, 2)
    }

    func testTooLargeDisplayIsAnError() {
        let errors = DisplaySettingsValidation.validate(DisplaySettings(width: 8_000, height: 5_000))
        XCTAssertEqual(errors.count, 2)
    }

    func testValidCustomDisplayPasses() {
        XCTAssertTrue(DisplaySettingsValidation.validate(DisplaySettings(width: 1_600, height: 900)).isEmpty)
    }

    func testPixelCount() {
        XCTAssertEqual(DisplaySettings(width: 1_920, height: 1_080).pixelCount, 2_073_600)
    }
}
