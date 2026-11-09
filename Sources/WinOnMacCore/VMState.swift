import Foundation

/// The lifecycle state of a VM, as a strict state machine.
///
/// The Virtualization framework's real states are `VZVirtualMachine.State`
/// (stopped / running / paused / ...); this enum is the app's own,
/// UI-facing version, and `VMViewModel` maps the framework states onto it.
/// The transition table here is what the buttons in the UI obey, so a
/// "Resume" button can never appear for a stopped VM and a "Start" button
/// can never appear for a running one.
public enum VMState: String, Codable, Equatable, CaseIterable {
    case stopped
    case starting
    case running
    case paused
    case stopping
    case error

    /// Human-readable label for the status badge in the VM list.
    public var displayName: String {
        switch self {
        case .stopped: return "Stopped"
        case .starting: return "Starting…"
        case .running: return "Running"
        case .paused: return "Paused"
        case .stopping: return "Stopping…"
        case .error: return "Error"
        }
    }

    /// Which states the VM can move to from here. Transitional states
    /// (`starting`, `stopping`) accept no user action — the framework
    /// reports the next settled state when the operation finishes.
    public func canTransition(to target: VMState) -> Bool {
        switch (self, target) {
        case (.stopped, .starting), (.stopped, .error):
            return true
        case (.starting, .running), (.starting, .stopped), (.starting, .error):
            return true
        case (.running, .paused), (.running, .stopping), (.running, .error):
            return true
        case (.paused, .running), (.paused, .stopping), (.paused, .error):
            return true
        case (.stopping, .stopped), (.stopping, .error):
            return true
        case (.error, .starting), (.error, .stopped):
            return true
        default:
            return false
        }
    }

    public var canStart: Bool { self == .stopped || self == .error }
    public var canStop: Bool { self == .running || self == .paused }
    public var canPause: Bool { self == .running }
    public var canResume: Bool { self == .paused }
    /// Snapshots copy the disk image, so the VM must be fully stopped.
    public var canTakeSnapshot: Bool { self == .stopped }
    /// Restoring replaces the disk image, so the VM must be fully stopped.
    public var canRestoreSnapshot: Bool { self == .stopped }
    public var isBusy: Bool { self == .starting || self == .stopping }
}
