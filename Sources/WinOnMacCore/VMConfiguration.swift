import Foundation

/// The persistent configuration of one Windows 11 ARM virtual machine.
///
/// This type is pure Foundation: no Virtualization, AppKit, or SwiftUI
/// imports, so it can be unit-tested with `swift test` on any platform.
/// The macOS app layer (see `App/VirtualMachineManager.swift`) translates
/// a `VMConfiguration` into a `VZVirtualMachineConfiguration`.
///
/// Limits mirror what Windows 11 ARM and Apple's Virtualization framework
/// actually need:
/// - Windows 11 requires at least 4 GB of RAM and a 64 GB system disk.
/// - The Virtualization framework exposes the host CPU count; a guest
///   cannot usefully be given more vCPUs than the host has, and 16 is a
///   sane upper bound for a desktop VM.
public struct VMConfiguration: Codable, Equatable, Identifiable {

    public static let minimumCPUCount = 1
    public static let maximumCPUCount = 16
    public static let minimumMemoryMB = 4_096
    public static let maximumMemoryMB = 131_072
    public static let memoryStepMB = 1_024
    public static let minimumDiskSizeGB = 64
    public static let maximumDiskSizeGB = 2_048
    public static let maximumNameLength = 64

    /// Sensible first-VM defaults: 4 vCPUs, 8 GB RAM, 128 GB disk.
    public static let `default` = VMConfiguration(
        name: "Windows 11",
        cpuCount: 4,
        memoryMB: 8_192,
        diskSizeGB: 128,
        isoPath: "",
        sharedFolders: [],
        display: DisplaySettings.default
    )

    public var id: UUID
    public var name: String
    public var cpuCount: Int
    public var memoryMB: Int
    public var diskSizeGB: Int
    /// Absolute path to the Windows 11 ARM ISO supplied by the user.
    public var isoPath: String
    public var sharedFolders: [SharedFolder]
    public var display: DisplaySettings
    public var createdAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        cpuCount: Int,
        memoryMB: Int,
        diskSizeGB: Int,
        isoPath: String,
        sharedFolders: [SharedFolder] = [],
        display: DisplaySettings = .default,
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.cpuCount = cpuCount
        self.memoryMB = memoryMB
        self.diskSizeGB = diskSizeGB
        self.isoPath = isoPath
        self.sharedFolders = sharedFolders
        self.display = display
        self.createdAt = createdAt
    }

    /// RAM in bytes, as the Virtualization framework expects it.
    public var memoryBytes: UInt64 {
        UInt64(memoryMB) * 1_024 * 1_024
    }

    /// Disk size in bytes (the size of the raw disk image file to create).
    public var diskSizeBytes: UInt64 {
        UInt64(diskSizeGB) * 1_024 * 1_024 * 1_024
    }

    /// Human-readable summary, e.g. "4 vCPU · 8 GB RAM · 128 GB disk".
    public var summary: String {
        "\(cpuCount) vCPU · \(memoryMB / 1_024) GB RAM · \(diskSizeGB) GB disk"
    }

    /// A filesystem-safe directory name derived from the VM name, used as
    /// the folder under Application Support that holds the disk image,
    /// EFI variable store, and snapshots.
    public var sanitizedDirectoryName: String {
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filtered = name.unicodeScalars.filter { allowed.contains($0) }
        let collapsed = String(String.UnicodeScalarView(filtered))
            .trimmingCharacters(in: .whitespaces)
            .replacingOccurrences(of: " ", with: "-")
        return collapsed.isEmpty ? "Windows-11" : collapsed
    }

    /// A copy of this configuration with the resource sliders clamped to
    /// their valid ranges, so the wizard can never produce an invalid VM.
    public func clamped() -> VMConfiguration {
        var copy = self
        copy.cpuCount = min(max(cpuCount, Self.minimumCPUCount), Self.maximumCPUCount)
        copy.memoryMB = min(max(memoryMB, Self.minimumMemoryMB), Self.maximumMemoryMB)
        copy.memoryMB = (copy.memoryMB / Self.memoryStepMB) * Self.memoryStepMB
        copy.diskSizeGB = min(max(diskSizeGB, Self.minimumDiskSizeGB), Self.maximumDiskSizeGB)
        return copy
    }
}
