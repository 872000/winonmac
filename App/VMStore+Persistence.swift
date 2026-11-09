import Foundation

/// JSON persistence for the VM list.
///
/// Location: `~/Library/Application Support/WinOnMac/vms.json`, with one
/// folder per VM (`~/Library/Application Support/WinOnMac/VMs/<name>/`)
/// holding the disk image, EFI variable store, machine identifier, and
/// snapshots. Nothing is synced or sent anywhere — the whole app is
/// offline by design.
enum VMStorePersistence {

    static var applicationSupportDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("WinOnMac")
    }

    static var vmsFileURL: URL {
        applicationSupportDirectory.appendingPathComponent("vms.json")
    }

    static func directory(for vm: VMConfiguration) -> URL {
        applicationSupportDirectory
            .appendingPathComponent("VMs")
            .appendingPathComponent(vm.sanitizedDirectoryName)
    }

    static func load() -> VMStore {
        guard let data = try? Data(contentsOf: vmsFileURL),
              let vms = try? JSONDecoder().decode([VMConfiguration].self, from: data)
        else { return VMStore() }
        return VMStore(vms: vms)
    }

    static func save(_ vms: [VMConfiguration]) {
        do {
            try FileManager.default.createDirectory(
                at: applicationSupportDirectory, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(vms)
            try data.write(to: vmsFileURL, options: .atomic)
        } catch {
            // Persistence failure must never crash the app; the in-memory
            // list stays usable for the session.
            print("WinOnMac: failed to save VM list: \(error)")
        }
    }
}
