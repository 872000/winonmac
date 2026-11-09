import Foundation

/// Metadata for one saved snapshot of a VM.
///
/// Honest scope note: Apple's Virtualization framework has no built-in
/// snapshot API, so WinOnMac snapshots are implemented the plain way — a
/// copy of the VM's disk image file plus this metadata, taken while the
/// VM is stopped. Restoring replaces the current disk image with the
/// saved copy. That is why snapshots are only allowed while the VM is
/// stopped, and why a snapshot costs as much disk space as the VM's disk.
public struct SnapshotMetadata: Codable, Equatable, Identifiable {

    public static let maximumNameLength = 64

    public var id: UUID
    /// The VM this snapshot belongs to. A snapshot can only be restored
    /// onto the VM it was taken from.
    public var vmID: UUID
    public var name: String
    public var note: String
    public var createdAt: Date
    /// Size of the saved disk-image copy, in bytes.
    public var diskSizeBytes: UInt64
    /// The VM's resource settings at snapshot time, so the restore
    /// screen can show what the VM looked like when it was taken.
    public var cpuCount: Int
    public var memoryMB: Int

    public init(
        id: UUID = UUID(),
        vmID: UUID,
        name: String,
        note: String = "",
        createdAt: Date = Date(),
        diskSizeBytes: UInt64,
        cpuCount: Int,
        memoryMB: Int
    ) {
        self.id = id
        self.vmID = vmID
        self.name = name
        self.note = note
        self.createdAt = createdAt
        self.diskSizeBytes = diskSizeBytes
        self.cpuCount = cpuCount
        self.memoryMB = memoryMB
    }

    /// Human-readable size of the saved disk copy, e.g. "12.5 GB".
    public var formattedSize: String {
        let gb = Double(diskSizeBytes) / 1_073_741_824.0
        return String(format: "%.1f GB", gb)
    }
}

public enum SnapshotValidation {

    public static func validateName(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Give the snapshot a name." }
        if trimmed.count > SnapshotMetadata.maximumNameLength {
            return "Snapshot name must be \(SnapshotMetadata.maximumNameLength) characters or fewer."
        }
        return nil
    }
}

/// The snapshot list for a single VM: newest first, with the rules that
/// keep restores safe.
public struct SnapshotLibrary {

    public private(set) var snapshots: [SnapshotMetadata]

    public init(snapshots: [SnapshotMetadata] = []) {
        self.snapshots = snapshots
            .sorted { $0.createdAt > $1.createdAt }
    }

    public var count: Int { snapshots.count }

    public var totalSizeBytes: UInt64 {
        snapshots.reduce(0) { $0 + $1.diskSizeBytes }
    }

    /// Snapshots for one VM only, newest first.
    public func snapshots(for vmID: UUID) -> [SnapshotMetadata] {
        snapshots.filter { $0.vmID == vmID }
    }

    public func snapshot(id: UUID) -> SnapshotMetadata? {
        snapshots.first { $0.id == id }
    }

    /// Adds a snapshot. Returns `false` (and does nothing) when a
    /// snapshot with the same id already exists, or when the name is
    /// blank — the caller validates the name first and shows the error.
    @discardableResult
    public mutating func add(_ snapshot: SnapshotMetadata) -> Bool {
        guard snapshot(id: snapshot.id) == nil else { return false }
        guard SnapshotValidation.validateName(snapshot.name) == nil else { return false }
        snapshots.append(snapshot)
        snapshots.sort { $0.createdAt > $1.createdAt }
        return true
    }

    /// Removes a snapshot. Returns `true` when one was actually removed.
    @discardableResult
    public mutating func remove(id: UUID) -> Bool {
        guard let index = snapshots.firstIndex(where: { $0.id == id }) else { return false }
        snapshots.remove(at: index)
        return true
    }

    /// A snapshot may only be restored onto the VM it was taken from.
    public func canRestore(_ snapshot: SnapshotMetadata, onto vmID: UUID) -> Bool {
        snapshot.vmID == vmID
    }
}
