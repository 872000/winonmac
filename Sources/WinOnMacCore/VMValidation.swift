import Foundation

/// One validation failure for a VM configuration, with a message the
/// setup wizard can show verbatim next to the offending field.
public struct ValidationError: Equatable, CustomStringConvertible {
    public let field: String
    public let message: String

    public init(field: String, message: String) {
        self.field = field
        self.message = message
    }

    public var description: String { "\(field): \(message)" }
}

/// Validates a `VMConfiguration` before the app hands it to the
/// Virtualization framework. `VZVirtualMachineConfiguration.validate()`
/// is the final gate on the Mac, but these checks run first so the wizard
/// can explain problems in plain language instead of surfacing a
/// framework error after the user has already picked an ISO.
public enum VMValidation {

    /// Returns every problem found; an empty array means the
    /// configuration is valid. All problems are reported at once so the
    /// wizard does not make the user fix them one at a time.
    public static func validate(_ config: VMConfiguration) -> [ValidationError] {
        var errors: [ValidationError] = []

        let trimmedName = config.name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty {
            errors.append(ValidationError(
                field: "name",
                message: "Give the virtual machine a name."
            ))
        } else if trimmedName.count > VMConfiguration.maximumNameLength {
            errors.append(ValidationError(
                field: "name",
                message: "Name must be \(VMConfiguration.maximumNameLength) characters or fewer."
            ))
        }

        if config.cpuCount < VMConfiguration.minimumCPUCount
            || config.cpuCount > VMConfiguration.maximumCPUCount {
            errors.append(ValidationError(
                field: "cpuCount",
                message: "CPU count must be between \(VMConfiguration.minimumCPUCount) and \(VMConfiguration.maximumCPUCount)."
            ))
        }

        if config.memoryMB < VMConfiguration.minimumMemoryMB {
            errors.append(ValidationError(
                field: "memoryMB",
                message: "Windows 11 needs at least \(VMConfiguration.minimumMemoryMB / 1_024) GB of RAM."
            ))
        } else if config.memoryMB > VMConfiguration.maximumMemoryMB {
            errors.append(ValidationError(
                field: "memoryMB",
                message: "Memory must be \(VMConfiguration.maximumMemoryMB / 1_024) GB or less."
            ))
        } else if config.memoryMB % VMConfiguration.memoryStepMB != 0 {
            errors.append(ValidationError(
                field: "memoryMB",
                message: "Memory must be a multiple of \(VMConfiguration.memoryStepMB / 1_024) GB."
            ))
        }

        if config.diskSizeGB < VMConfiguration.minimumDiskSizeGB {
            errors.append(ValidationError(
                field: "diskSizeGB",
                message: "Windows 11 needs at least a \(VMConfiguration.minimumDiskSizeGB) GB disk."
            ))
        } else if config.diskSizeGB > VMConfiguration.maximumDiskSizeGB {
            errors.append(ValidationError(
                field: "diskSizeGB",
                message: "Disk size must be \(VMConfiguration.maximumDiskSizeGB) GB or less."
            ))
        }

        if config.isoPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                field: "isoPath",
                message: "Choose a Windows 11 ARM ISO file to install from."
            ))
        } else if !ISOValidation.looksLikeISO(path: config.isoPath) {
            errors.append(ValidationError(
                field: "isoPath",
                message: "That file does not look like an ISO image (expected a .iso file)."
            ))
        }

        for folder in config.sharedFolders {
            errors.append(contentsOf: SharedFolderValidation.validate(folder).map {
                ValidationError(field: "sharedFolders.\($0.field)", message: $0.message)
            })
        }

        errors.append(contentsOf: DisplaySettingsValidation.validate(config.display))

        return errors
    }

    public static func isValid(_ config: VMConfiguration) -> Bool {
        validate(config).isEmpty
    }
}
