import Foundation
import Virtualization

/// Translates a `VMConfiguration` into a `VZVirtualMachineConfiguration`
/// and owns the lifetime of the underlying `VZVirtualMachine`.
///
/// This is the only file that touches the Virtualization framework, so
/// everything else in the app deals with plain `VMConfiguration` values.
///
/// Honest scope, stated in code as well as in the README:
/// - Apple Silicon only. The Virtualization framework does not exist on
///   Intel Macs, and x86 Windows cannot run under it at all — only the
///   Windows 11 ARM64 guest works.
/// - There is no built-in snapshot API in the Virtualization framework.
///   Snapshots here are disk-image copies taken while the VM is stopped
///   (see `takeSnapshot` / `restoreSnapshot`).
/// - Windows 11 ARM has no TPM in this setup. The installer normally
///   refuses to proceed without one; the first-boot steps in the README
///   cover the documented registry bypass used during installation.
final class VirtualMachineManager: NSObject {

    enum ManagerError: LocalizedError {
        case diskImageCreationFailed(URL)
        case snapshotWhileRunning
        case snapshotNotFound
        case invalidConfiguration(String)

        var errorDescription: String? {
            switch self {
            case .diskImageCreationFailed(let url):
                return "Could not create the disk image at \(url.path)."
            case .snapshotWhileRunning:
                return "Stop the virtual machine before taking or restoring a snapshot."
            case .snapshotNotFound:
                return "That snapshot no longer exists on disk."
            case .invalidConfiguration(let message):
                return "Invalid virtual machine configuration: \(message)"
            }
        }
    }

    private let config: VMConfiguration
    private let directory: URL
    private(set) var virtualMachine: VZVirtualMachine?

    init(config: VMConfiguration, directory: URL) {
        self.config = config
        self.directory = directory
    }

    // MARK: - Paths

    var diskImageURL: URL { directory.appendingPathComponent("disk.img") }
    var efiVariableStoreURL: URL { directory.appendingPathComponent("efi.nvram") }
    var machineIdentifierURL: URL { directory.appendingPathComponent("machine-identifier") }
    var snapshotsDirectoryURL: URL { directory.appendingPathComponent("Snapshots") }

    // MARK: - First-time setup

    /// Creates the VM folder, the empty disk image, and the EFI variable
    /// store. Called once, when the setup wizard finishes. Safe to call
    /// again — existing files are left alone.
    func prepareFilesIfNeeded() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try FileManager.default.createDirectory(at: snapshotsDirectoryURL, withIntermediateDirectories: true)

        if !FileManager.default.fileExists(atPath: diskImageURL.path) {
            guard createEmptyFile(at: diskImageURL, size: config.diskSizeBytes) else {
                throw ManagerError.diskImageCreationFailed(diskImageURL)
            }
        }
        if !FileManager.default.fileExists(atPath: efiVariableStoreURL.path) {
            // VZEFIVariableStore creates the file on first open.
            _ = VZEFIVariableStore(url: efiVariableStoreURL)
        }
        if !FileManager.default.fileExists(atPath: machineIdentifierURL.path) {
            let identifier = VZGenericMachineIdentifier()
            try identifier.dataRepresentation.write(to: machineIdentifierURL)
        }
    }

    private func createEmptyFile(at url: URL, size: UInt64) -> Bool {
        guard FileManager.default.createFile(atPath: url.path, contents: nil) else { return false }
        do {
            let handle = try FileHandle(forWritingTo: url)
            try handle.truncate(atOffset: size)
            try handle.close()
            return true
        } catch {
            return false
        }
    }

    // MARK: - Building the Virtualization configuration

    /// Builds the framework configuration for this VM. Throws when the
    /// configuration is invalid — the caller surfaces the message.
    func buildConfiguration() throws -> VZVirtualMachineConfiguration {
        let configuration = VZVirtualMachineConfiguration()

        configuration.cpuCount = config.cpuCount
        configuration.memorySize = config.memoryBytes

        // Platform: a generic (non-macOS) guest. The machine identifier
        // is persisted so the guest sees the same "hardware" every boot —
        // Windows activation and the EFI store both depend on it.
        let platform = VZGenericPlatformConfiguration()
        if let data = try? Data(contentsOf: machineIdentifierURL),
           let identifier = VZGenericMachineIdentifier(dataRepresentation: data) {
            platform.machineIdentifier = identifier
        } else {
            platform.machineIdentifier = VZGenericMachineIdentifier()
        }
        configuration.platform = platform

        // UEFI boot. The EFI variable store holds the boot order and the
        // Secure Boot state between runs.
        let bootloader = VZEFIBootLoader()
        bootloader.variableStore = VZEFIVariableStore(url: efiVariableStoreURL)
        configuration.bootLoader = bootloader

        // Main disk (virtio block device backed by the raw disk image).
        let diskAttachment = try VZDiskImageStorageDeviceAttachment(
            url: diskImageURL, readOnly: false)
        configuration.storageDevices = [
            VZVirtioBlockDeviceConfiguration(attachment: diskAttachment)
        ]

        // Installer ISO, attached as a second block device while the VM
        // is being installed. The wizard keeps the ISO attached afterwards
        // too — it is harmless once Windows is installed, and removing it
        // is a per-VM setting for later.
        if !config.isoPath.isEmpty,
           FileManager.default.fileExists(atPath: config.isoPath) {
            let isoAttachment = try VZDiskImageStorageDeviceAttachment(
                url: URL(fileURLWithPath: config.isoPath), readOnly: true)
            configuration.storageDevices.append(
                VZVirtioBlockDeviceConfiguration(attachment: isoAttachment))
        }

        // NAT networking: the guest gets internet through the Mac, with
        // no ports exposed unless the user forwards them.
        let network = VZVirtioNetworkDeviceConfiguration()
        network.attachment = VZNATNetworkDeviceAttachment()
        configuration.networkDevices = [network]

        // Display.
        let graphics = VZVirtioGraphicsDeviceConfiguration()
        graphics.scanouts = [
            VZVirtioGraphicsScanoutConfiguration(
                widthInPixels: config.display.width,
                heightInPixels: config.display.height)
        ]
        configuration.graphicsDevices = [graphics]

        // Input, entropy, and memory balloon — the standard supporting
        // devices for a desktop guest.
        configuration.pointingDevices = [VZUSBScreenCoordinatePointingDeviceConfiguration()]
        configuration.keyboards = [VZUSBKeyboardConfiguration()]
        configuration.entropyDevices = [VZVirtioEntropyDeviceConfiguration()]
        configuration.memoryBalloonDevices = [VZVirtioTraditionalMemoryBalloonDeviceConfiguration()]

        // Shared folders, exposed to the guest as virtio filesystem
        // devices. In Windows they appear as network shares the user
        // mounts from the guest.
        configuration.directorySharingDevices = config.sharedFolders.compactMap { folder in
            let device = VZVirtioFileSystemDeviceConfiguration(tag: folder.tag)
            device.share = VZSharedDirectory(
                url: URL(fileURLWithPath: folder.hostPath), readOnly: false)
            return device
        }

        try configuration.validate()
        return configuration
    }

    // MARK: - Running the VM

    /// Creates the `VZVirtualMachine` and starts it. The completion
    /// reports the framework error, if any; state changes are delivered
    /// through the delegate and the view model's state observation.
    func start(completion: @escaping (Error?) -> Void) {
        do {
            try prepareFilesIfNeeded()
            let vzConfiguration = try buildConfiguration()
            let queue = DispatchQueue(label: "com.winonmac.virtualmachine")
            let machine = VZVirtualMachine(configuration: vzConfiguration, queue: queue)
            machine.delegate = self
            self.virtualMachine = machine
            machine.start { error in
                DispatchQueue.main.async { completion(error) }
            }
        } catch {
            completion(error)
        }
    }

    func stop(completion: @escaping (Error?) -> Void = { _ in }) {
        virtualMachine?.stop { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    func pause(completion: @escaping (Error?) -> Void = { _ in }) {
        virtualMachine?.pause { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    func resume(completion: @escaping (Error?) -> Void = { _ in }) {
        virtualMachine?.resume { error in
            DispatchQueue.main.async { completion(error) }
        }
    }

    // MARK: - Snapshots (disk-image copies, VM must be stopped)

    /// Copies the disk image into the Snapshots folder and returns the
    /// metadata the app stores alongside it. The VM must be stopped.
    func takeSnapshot(
        name: String,
        note: String,
        isRunning: Bool
    ) throws -> SnapshotMetadata {
        guard !isRunning else { throw ManagerError.snapshotWhileRunning }
        try prepareFilesIfNeeded()
        let snapshot = SnapshotMetadata(
            vmID: config.id,
            name: name,
            note: note,
            diskSizeBytes: config.diskSizeBytes,
            cpuCount: config.cpuCount,
            memoryMB: config.memoryMB
        )
        let snapshotURL = snapshotsDirectoryURL
            .appendingPathComponent("\(snapshot.id.uuidString).img")
        try FileManager.default.copyItem(at: diskImageURL, to: snapshotURL)
        let metadataURL = snapshotsDirectoryURL
            .appendingPathComponent("\(snapshot.id.uuidString).json")
        try JSONEncoder().encode(snapshot).write(to: metadataURL)
        return snapshot
    }

    /// Replaces the current disk image with a saved snapshot copy.
    /// The VM must be stopped. The current disk is kept as a
    /// `disk.img.before-restore` backup, so a restore is never
    /// destructive.
    func restoreSnapshot(_ snapshot: SnapshotMetadata, isRunning: Bool) throws {
        guard !isRunning else { throw ManagerError.snapshotWhileRunning }
        let snapshotURL = snapshotsDirectoryURL
            .appendingPathComponent("\(snapshot.id.uuidString).img")
        guard FileManager.default.fileExists(atPath: snapshotURL.path) else {
            throw ManagerError.snapshotNotFound
        }
        let backupURL = directory.appendingPathComponent("disk.img.before-restore")
        try? FileManager.default.removeItem(at: backupURL)
        try FileManager.default.moveItem(at: diskImageURL, to: backupURL)
        try FileManager.default.copyItem(at: snapshotURL, to: diskImageURL)
    }

    /// Deletes a snapshot's disk copy and metadata.
    func deleteSnapshot(_ snapshot: SnapshotMetadata) {
        let base = snapshotsDirectoryURL.appendingPathComponent(snapshot.id.uuidString)
        try? FileManager.default.removeItem(at: base.appendingPathExtension("img"))
        try? FileManager.default.removeItem(at: base.appendingPathExtension("json"))
    }

    /// Loads every snapshot's metadata from the Snapshots folder.
    func loadSnapshots() -> [SnapshotMetadata] {
        let files = (try? FileManager.default.contentsOfDirectory(
            at: snapshotsDirectoryURL,
            includingPropertiesForKeys: nil
        )) ?? []
        return files
            .filter { $0.pathExtension == "json" }
            .compactMap { try? Data(contentsOf: $0) }
            .compactMap { try? JSONDecoder().decode(SnapshotMetadata.self, from: $0) }
    }
}

// MARK: - VZVirtualMachineDelegate

extension VirtualMachineManager: VZVirtualMachineDelegate {
    func virtualMachine(_ virtualMachine: VZVirtualMachine, didStopWithError error: Error) {
        // The view model observes state through its own polling of
        // `virtualMachine.state` and this delegate callback; the error is
        // forwarded via NotificationCenter so the UI can show it.
        NotificationCenter.default.post(
            name: .winOnMacVirtualMachineDidStopWithError,
            object: error
        )
    }

    func guestDidStop(_ virtualMachine: VZVirtualMachine) {
        NotificationCenter.default.post(name: .winOnMacGuestDidStop, object: nil)
    }
}

extension Notification.Name {
    static let winOnMacVirtualMachineDidStopWithError =
        Notification.Name("com.winonmac.vm.didStopWithError")
    static let winOnMacGuestDidStop =
        Notification.Name("com.winonmac.vm.guestDidStop")
}
