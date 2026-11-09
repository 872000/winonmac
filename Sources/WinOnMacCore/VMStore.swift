import Foundation

/// The in-memory list of VMs, with the rules that keep the list sane:
/// no two VMs share a name (names are how the user tells them apart in
/// the sidebar), and the list is always shown alphabetically.
///
/// Persistence lives in the app layer (`App/VMStore+Persistence.swift`),
/// which encodes `[VMConfiguration]` as JSON in Application Support.
/// This type only owns the list invariants, so it stays testable.
public struct VMStore {

    public private(set) var vms: [VMConfiguration]

    public init(vms: [VMConfiguration] = []) {
        // Keep the first VM when names collide; duplicates are a data
        // error, not something to crash over.
        var seen: Set<String> = []
        self.vms = vms.filter { vm in
            let key = vm.name.lowercased()
            guard !seen.contains(key) else { return false }
            seen.insert(key)
            return true
        }.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public var count: Int { vms.count }
    public var isEmpty: Bool { vms.isEmpty }

    public func vm(id: UUID) -> VMConfiguration? {
        vms.first { $0.id == id }
    }

    public func vm(named name: String) -> VMConfiguration? {
        vms.first { $0.name.lowercased() == name.lowercased() }
    }

    public func containsName(_ name: String, excluding excludedID: UUID? = nil) -> Bool {
        vms.contains {
            $0.name.lowercased() == name.lowercased() && $0.id != excludedID
        }
    }

    /// Adds a VM. Fails (returns `false`, adds nothing) when the name is
    /// already taken or the configuration is invalid.
    @discardableResult
    public mutating func add(_ vm: VMConfiguration) -> Bool {
        guard !containsName(vm.name) else { return false }
        guard VMValidation.isValid(vm) else { return false }
        vms.append(vm)
        sort()
        return true
    }

    /// Replaces the VM with the same id. Fails when the id is unknown,
    /// the new name collides with another VM, or the new configuration
    /// is invalid.
    @discardableResult
    public mutating func update(_ vm: VMConfiguration) -> Bool {
        guard let index = vms.firstIndex(where: { $0.id == vm.id }) else { return false }
        guard !containsName(vm.name, excluding: vm.id) else { return false }
        guard VMValidation.isValid(vm) else { return false }
        vms[index] = vm
        sort()
        return true
    }

    /// Removes a VM. Returns `true` when one was actually removed.
    @discardableResult
    public mutating func remove(id: UUID) -> Bool {
        guard let index = vms.firstIndex(where: { $0.id == id }) else { return false }
        vms.remove(at: index)
        return true
    }

    private mutating func sort() {
        vms.sort { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }
}
