import Foundation
@testable import WinOnMacCore

/// Shared fixtures for the test suite.
func makeValidConfig(
    name: String = "Windows 11",
    cpuCount: Int = 4,
    memoryMB: Int = 8_192,
    diskSizeGB: Int = 128,
    isoPath: String = "/Users/parth/Downloads/Win11_24H2_ARM64.iso"
) -> VMConfiguration {
    VMConfiguration(
        name: name,
        cpuCount: cpuCount,
        memoryMB: memoryMB,
        diskSizeGB: diskSizeGB,
        isoPath: isoPath
    )
}

func makeSnapshot(
    vmID: UUID = UUID(),
    name: String = "Before updates",
    createdAt: Date = Date(timeIntervalSince1970: 1_700_000_000),
    diskSizeBytes: UInt64 = 12_884_901_888
) -> SnapshotMetadata {
    SnapshotMetadata(
        vmID: vmID,
        name: name,
        createdAt: createdAt,
        diskSizeBytes: diskSizeBytes,
        cpuCount: 4,
        memoryMB: 8_192
    )
}
