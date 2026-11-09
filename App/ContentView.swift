import SwiftUI
import Virtualization

/// Main window: VM list on the left, the selected VM's display (or its
/// empty state) on the right.
struct ContentView: View {
    @EnvironmentObject private var viewModel: VMViewModel
    @State private var showingDeleteConfirmation = false
    @State private var vmPendingDeletion: VMConfiguration?

    var body: some View {
        NavigationSplitView {
            List(selection: $viewModel.selectedVMID) {
                ForEach(viewModel.store.vms) { vm in
                    VMRowView(vm: vm)
                        .tag(vm.id)
                        .contextMenu {
                            Button("Start") { viewModel.start(vm) }
                                .disabled(!viewModel.state(for: vm.id).canStart)
                            Button("Stop") { viewModel.stop(vm) }
                                .disabled(!viewModel.state(for: vm.id).canStop)
                            Button("Settings…") { viewModel.showingSettingsFor = vm.id }
                            Divider()
                            Button("Delete…", role: .destructive) {
                                vmPendingDeletion = vm
                                showingDeleteConfirmation = true
                            }
                        }
                }
            }
            .navigationTitle("Virtual Machines")
            .toolbar {
                Button {
                    viewModel.beginSetupWizard()
                } label: {
                    Label("New VM", systemImage: "plus")
                }
            }
        } detail: {
            if let vm = viewModel.selectedVM {
                VMDetailView(vm: vm)
            } else {
                ContentUnavailableView(
                    "No Virtual Machine Selected",
                    systemImage: "desktopcomputer",
                    description: Text("Create a virtual machine to run Windows 11 on your Mac.")
                )
            }
        }
        .sheet(isPresented: $viewModel.showingSetupWizard) {
            VMSetupWizard()
        }
        .sheet(item: Binding(
            get: { viewModel.showingSettingsFor.map { SettingsSheetID(id: $0) } },
            set: { viewModel.showingSettingsFor = $0?.id }
        )) { sheet in
            if let vm = viewModel.store.vm(id: sheet.id) {
                VMSettingsView(vm: vm)
            }
        }
        .alert("Delete this virtual machine?", isPresented: $showingDeleteConfirmation) {
            Button("Cancel", role: .cancel) {}
            Button("Delete", role: .destructive) {
                if let vm = vmPendingDeletion { viewModel.removeVM(vm) }
            }
        } message: {
            Text("This deletes the VM and its disk image. Snapshots are deleted too. This cannot be undone.")
        }
        .alert("Something went wrong", isPresented: Binding(
            get: { viewModel.lastError != nil },
            set: { if !$0 { viewModel.lastError = nil } }
        )) {
            Button("OK", role: .cancel) { viewModel.lastError = nil }
        } message: {
            Text(viewModel.lastError ?? "")
        }
    }
}

private struct SettingsSheetID: Identifiable {
    let id: UUID
}

/// One row in the VM sidebar: name, resource summary, state badge.
struct VMRowView: View {
    @EnvironmentObject private var viewModel: VMViewModel
    let vm: VMConfiguration

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(vm.name).font(.headline)
                Spacer()
                Text(viewModel.state(for: vm.id).displayName)
                    .font(.caption)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(stateColor.opacity(0.2))
                    .foregroundStyle(stateColor)
                    .clipShape(Capsule())
            }
            Text(vm.summary)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

    private var stateColor: Color {
        switch viewModel.state(for: vm.id) {
        case .running: .green
        case .paused: .orange
        case .starting, .stopping: .blue
        case .error: .red
        case .stopped: .gray
        }
    }
}

/// The right-hand pane for the selected VM: toolbar controls, the live
/// display while running, and the snapshot section.
struct VMDetailView: View {
    @EnvironmentObject private var viewModel: VMViewModel
    let vm: VMConfiguration

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    viewModel.start(vm)
                } label: {
                    Label("Start", systemImage: "play.fill")
                }
                .disabled(!viewModel.state(for: vm.id).canStart)

                Button {
                    viewModel.stop(vm)
                } label: {
                    Label("Stop", systemImage: "stop.fill")
                }
                .disabled(!viewModel.state(for: vm.id).canStop)

                Button {
                    viewModel.pause(vm)
                } label: {
                    Label("Pause", systemImage: "pause.fill")
                }
                .disabled(!viewModel.state(for: vm.id).canPause)

                Button {
                    viewModel.resume(vm)
                } label: {
                    Label("Resume", systemImage: "playpause.fill")
                }
                .disabled(!viewModel.state(for: vm.id).canResume)

                Spacer()

                Button {
                    viewModel.showingSnapshotSheetFor = vm.id
                } label: {
                    Label("Snapshots", systemImage: "camera.fill")
                }
                .disabled(!viewModel.state(for: vm.id).canTakeSnapshot
                          && viewModel.snapshots(for: vm.id).isEmpty)

                Button("Settings…") {
                    viewModel.showingSettingsFor = vm.id
                }
            }
            .padding()
            .background(.bar)

            if viewModel.state(for: vm.id) == .running
                || viewModel.state(for: vm.id) == .paused {
                if let machine = viewModel.virtualMachine(for: vm) {
                    VMDisplayView(virtualMachine: machine)
                }
            } else {
                VMStoppedView(vm: vm)
            }
        }
        .navigationTitle(vm.name)
        .sheet(item: Binding(
            get: { viewModel.showingSnapshotSheetFor.map { SettingsSheetID(id: $0) } },
            set: { viewModel.showingSnapshotSheetFor = $0?.id }
        )) { sheet in
            if let target = viewModel.store.vm(id: sheet.id) {
                SnapshotListView(vm: target)
            }
        }
    }
}

/// Shown when the VM is not running: its summary and a first-boot hint.
struct VMStoppedView: View {
    @EnvironmentObject private var viewModel: VMViewModel
    let vm: VMConfiguration

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "desktopcomputer")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text(vm.name).font(.title2)
            Text(vm.summary).foregroundStyle(.secondary)
            Text("Display: \(vm.display.label)")
                .foregroundStyle(.secondary)
            if !vm.sharedFolders.isEmpty {
                Text("\(vm.sharedFolders.count) shared folder(s)")
                    .foregroundStyle(.secondary)
            }
            Button("Start Windows") {
                viewModel.start(vm)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!viewModel.state(for: vm.id).canStart)
            Text("First boot? See the README's first-boot steps — the Windows installer needs the TPM bypass before it will proceed.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
