import Foundation
import SwiftUI
import Virtualization

/// The app's single source of truth: the VM list, the selected VM, each
/// VM's run state, and the snapshot libraries. The SwiftUI views only
/// read this object and call its methods — no view talks to the
/// Virtualization framework directly.
@MainActor
final class VMViewModel: ObservableObject {

    // MARK: - State

    @Published private(set) var store: VMStore
    @Published var selectedVMID: UUID?
    @Published private(set) var vmStates: [UUID: VMState] = [:]
    @Published private(set) var snapshots: [UUID: SnapshotLibrary] = [:]
    @Published var lastError: String?

    @Published var showingSetupWizard = false
    @Published var showingSettingsFor: UUID?
    @Published var showingSnapshotSheetFor: UUID?

    private var managers: [UUID: VirtualMachineManager] = [:]

    init() {
        self.store = VMStorePersistence.load()
        for vm in store.vms {
            vmStates[vm.id] = .stopped
            snapshots[vm.id] = SnapshotLibrary(
                snapshots: manager(for: vm).loadSnapshots())
        }
        NotificationCenter.default.addObserver(
            forName: .winOnMacVirtualMachineDidStopWithError,
            object: nil, queue: .main
        ) { [weak self] note in
            if let error = note.object as? Error {
                self?.lastError = error.localizedDescription
            }
        }
        NotificationCenter.default.addObserver(
            forName: .winOnMacGuestDidStop,
            object: nil, queue: .main
        ) { [weak self] _ in
            self?.refreshStatesFromManagers()
        }
    }

    // MARK: - Derived

    var selectedVM: VMConfiguration? {
        guard let id = selectedVMID else { return nil }
        return store.vm(id: id)
    }

    func state(for vmID: UUID) -> VMState {
        vmStates[vmID] ?? .stopped
    }

    func snapshots(for vmID: UUID) -> [SnapshotMetadata] {
        snapshots[vmID]?.snapshots ?? []
    }

    // MARK: - VM list

    func beginSetupWizard() {
        showingSetupWizard = true
    }

    func addVM(_ config: VMConfiguration) {
        guard store.add(config) else { return }
        vmStates[config.id] = .stopped
        snapshots[config.id] = SnapshotLibrary()
        selectedVMID = config.id
        persist()
    }

    func updateVM(_ config: VMConfiguration) {
        guard store.update(config) else { return }
        persist()
    }

    func removeVM(_ vm: VMConfiguration) {
        stop(vm) { [weak self] in
            guard let self else { return }
            _ = self.store.remove(id: vm.id)
            self.managers.removeValue(forKey: vm.id)
            self.vmStates.removeValue(forKey: vm.id)
            self.snapshots.removeValue(forKey: vm.id)
            if self.selectedVMID == vm.id { self.selectedVMID = nil }
            self.persist()
            try? FileManager.default.removeItem(
                at: VMStorePersistence.directory(for: vm))
        }
    }

    // MARK: - Running

    func start(_ vm: VMConfiguration) {
        guard state(for: vm.id).canStart else { return }
        vmStates[vm.id] = .starting
        manager(for: vm).start { [weak self] error in
            guard let self else { return }
            if let error {
                self.vmStates[vm.id] = .error
                self.lastError = error.localizedDescription
            } else {
                self.vmStates[vm.id] = .running
            }
            self.refreshStatesFromManagers()
        }
    }

    func stop(_ vm: VMConfiguration, completion: @escaping () -> Void = {}) {
        guard state(for: vm.id).canStop else { completion(); return }
        vmStates[vm.id] = .stopping
        manager(for: vm).stop { [weak self] _ in
            self?.vmStates[vm.id] = .stopped
            completion()
        }
    }

    func pause(_ vm: VMConfiguration) {
        guard state(for: vm.id).canPause else { return }
        manager(for: vm).pause { [weak self] error in
            if error == nil { self?.vmStates[vm.id] = .paused }
            else { self?.lastError = error?.localizedDescription }
        }
    }

    func resume(_ vm: VMConfiguration) {
        guard state(for: vm.id).canResume else { return }
        manager(for: vm).resume { [weak self] error in
            if error == nil { self?.vmStates[vm.id] = .running }
            else { self?.lastError = error?.localizedDescription }
        }
    }

    /// Reads the real framework state back into the app's state machine,
    /// so the UI never disagrees with the VM (e.g. after the guest shuts
    /// itself down from inside Windows).
    func refreshStatesFromManagers() {
        for vm in store.vms {
            guard let machine = managers[vm.id]?.virtualMachine else { continue }
            switch machine.state {
            case .running: vmStates[vm.id] = .running
            case .paused: vmStates[vm.id] = .paused
            case .stopped: vmStates[vm.id] = .stopped
            case .starting: vmStates[vm.id] = .starting
            case .stopping: vmStates[vm.id] = .stopping
            case .error: vmStates[vm.id] = .error
            @unknown default: break
            }
        }
    }

    func virtualMachine(for vm: VMConfiguration) -> VZVirtualMachine? {
        manager(for: vm).virtualMachine
    }

    // MARK: - Snapshots

    func takeSnapshot(for vm: VMConfiguration, name: String, note: String) {
        guard state(for: vm.id).canTakeSnapshot else {
            lastError = "Stop the virtual machine before taking a snapshot."
            return
        }
        do {
            let snapshot = try manager(for: vm).takeSnapshot(
                name: name, note: note, isRunning: false)
            snapshots[vm.id, default: SnapshotLibrary()].add(snapshot)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func restoreSnapshot(_ snapshot: SnapshotMetadata, for vm: VMConfiguration) {
        guard state(for: vm.id).canRestoreSnapshot else {
            lastError = "Stop the virtual machine before restoring a snapshot."
            return
        }
        do {
            try manager(for: vm).restoreSnapshot(snapshot, isRunning: false)
        } catch {
            lastError = error.localizedDescription
        }
    }

    func deleteSnapshot(_ snapshot: SnapshotMetadata, for vm: VMConfiguration) {
        manager(for: vm).deleteSnapshot(snapshot)
        snapshots[vm.id]?.remove(id: snapshot.id)
    }

    // MARK: - Private

    private func manager(for vm: VMConfiguration) -> VirtualMachineManager {
        if let existing = managers[vm.id] { return existing }
        let manager = VirtualMachineManager(
            config: vm, directory: VMStorePersistence.directory(for: vm))
        managers[vm.id] = manager
        return manager
    }

    private func persist() {
        VMStorePersistence.save(store.vms)
    }
}
