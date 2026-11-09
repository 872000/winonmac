import Foundation

/// Display settings for the VM window.
///
/// The guest display is driven by `VZVirtioGraphicsDeviceConfiguration`
/// with a `VZVirtualMachineView` showing it. The resolution here is the
/// size of the virtual display the guest is offered; Windows picks it up
/// as its display resolution.
public struct DisplaySettings: Codable, Equatable, Hashable {

    public static let minimumWidth = 800
    public static let minimumHeight = 600
    public static let maximumWidth = 7_680
    public static let maximumHeight = 4_320

    public static let `default` = DisplaySettings(width: 1_920, height: 1_080)

    /// Common presets offered in the setup wizard.
    public static let presets: [DisplaySettings] = [
        DisplaySettings(width: 1_280, height: 720),
        DisplaySettings(width: 1_920, height: 1_080),
        DisplaySettings(width: 2_560, height: 1_440),
        DisplaySettings(width: 3_840, height: 2_160),
    ]

    public var width: Int
    public var height: Int

    public init(width: Int, height: Int) {
        self.width = width
        self.height = height
    }

    public var label: String { "\(width) × \(height)" }

    /// True when these dimensions are one of the offered presets.
    public var isPreset: Bool { Self.presets.contains(self) }

    /// Pixel count, used to sanity-check absurd custom resolutions.
    public var pixelCount: Int { width * height }
}

public enum DisplaySettingsValidation {

    public static func validate(_ display: DisplaySettings) -> [ValidationError] {
        var errors: [ValidationError] = []
        if display.width < DisplaySettings.minimumWidth
            || display.width > DisplaySettings.maximumWidth {
            errors.append(ValidationError(
                field: "display.width",
                message: "Display width must be between \(DisplaySettings.minimumWidth) and \(DisplaySettings.maximumWidth)."
            ))
        }
        if display.height < DisplaySettings.minimumHeight
            || display.height > DisplaySettings.maximumHeight {
            errors.append(ValidationError(
                field: "display.height",
                message: "Display height must be between \(DisplaySettings.minimumHeight) and \(DisplaySettings.maximumHeight)."
            ))
        }
        return errors
    }
}
