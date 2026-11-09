import SwiftUI

/// WinOnMac — run Windows 11 ARM in a virtual machine on Apple Silicon.
///
/// Entry point. The app is a standard macOS SwiftUI app; all Virtualization
/// framework work lives in `VirtualMachineManager` and `VMViewModel`, and
/// all pure logic (configuration, validation, snapshots) lives in the
/// `WinOnMacCore` Swift package, which is tested with `swift test`.
@main
struct WinOnMacApp: App {
    @StateObject private var store = VMViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(store)
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("New Virtual Machine…") {
                    store.beginSetupWizard()
                }
                .keyboardShortcut("n", modifiers: [.command])
            }
        }
    }
}
