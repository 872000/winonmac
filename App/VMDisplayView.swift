import SwiftUI
import Virtualization

/// The live VM display, wrapping `VZVirtualMachineView` (AppKit) in
/// SwiftUI. The guest's screen, mouse, and keyboard all go through this
/// view — clicking into it captures the mouse, and the capture is
/// released with Control-Option (the framework default).
struct VMDisplayView: NSViewRepresentable {
    let virtualMachine: VZVirtualMachine

    func makeNSView(context: Context) -> VZVirtualMachineView {
        let view = VZVirtualMachineView(frame: .zero)
        view.virtualMachine = virtualMachine
        // Capture the mouse automatically when the user clicks into the
        // VM, and show the capture state in the view's own UI.
        view.capturesMouse = true
        return view
    }

    func updateNSView(_ nsView: VZVirtualMachineView, context: Context) {
        if nsView.virtualMachine !== virtualMachine {
            nsView.virtualMachine = virtualMachine
        }
    }
}
