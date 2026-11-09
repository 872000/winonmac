import SwiftUI

/// Per-VM settings editor. Resource changes (CPU, RAM, disk, display,
/// shared folders) take effect the next time the VM starts — the
/// Virtualization framework builds the configuration at start time, so a
/// running VM keeps its old settings until it is restarted.
///
/// The disk size cannot be shrunk after creation (the disk image file is
/// fixed-size), so the editor only allows growing it.
struct VMSettingsView: View {
    @EnvironmentObject private var viewModel: VMViewModel
    @Environment(\.dismiss) private var dismiss

    let vm: VMConfiguration

    @State private var name: String
    @State private var cpuCount: Int
    @State private var memoryMB: Int
    @State private var diskSizeGB: Int
    @State private var display: DisplaySettings
    @State private var sharedFolders: [SharedFolder]

    init(vm: VMConfiguration) {
        self.vm = vm
        _name = State(initialValue: vm.name)
        _cpuCount = State(initialValue: vm.cpuCount)
        _memoryMB = State(initialValue: vm.memoryMB)
        _diskSizeGB = State(initialValue: vm.diskSizeGB)
        _display = State(initialValue: vm.display)
        _sharedFolders = State(initialValue: vm.sharedFolders)
    }

    private var edited: VMConfiguration {
        VMConfiguration(
            id: vm.id,
            name: name,
            cpuCount: cpuCount,
            memoryMB: memoryMB,
            diskSizeGB: diskSizeGB,
            isoPath: vm.isoPath,
            sharedFolders: sharedFolders,
            display: display,
            createdAt: vm.createdAt
        )
    }

    private var errors: [ValidationError] { VMValidation.validate(edited) }
    private var isRunning: Bool { viewModel.state(for: vm.id) == .running }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Settings — \(vm.name)")
                .font(.title2)
            if isRunning {
                Label("This VM is running. Changes apply after you stop and restart it.", systemImage: "info.circle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }
            Form {
                TextField("Name", text: $name)
                Stepper("CPUs: \(cpuCount)", value: $cpuCount,
                        in: VMConfiguration.minimumCPUCount...VMConfiguration.maximumCPUCount)
                VStack(alignment: .leading) {
                    Text("Memory: \(memoryMB / 1_024) GB")
                    Slider(value: Binding(
                        get: { Double(memoryMB) },
                        set: { memoryMB = (Int($0) / VMConfiguration.memoryStepMB) * VMConfiguration.memoryStepMB }
                    ), in: Double(VMConfiguration.minimumMemoryMB)...Double(VMConfiguration.maximumMemoryMB),
                    step: Double(VMConfiguration.memoryStepMB))
                }
                VStack(alignment: .leading) {
                    Text("Disk: \(diskSizeGB) GB (can only grow)")
                    Slider(value: Binding(
                        get: { Double(diskSizeGB) },
                        set: { diskSizeGB = max(vm.diskSizeGB, Int($0)) }
                    ), in: Double(vm.diskSizeGB)...Double(VMConfiguration.maximumDiskSizeGB),
                    step: 16)
                }
                Picker("Display", selection: $display) {
                    ForEach(DisplaySettings.presets, id: \.self) { preset in
                        Text(preset.label).tag(preset)
                    }
                }
                Section("Shared folders") {
                    ForEach(sharedFolders) { folder in
                        HStack {
                            Text(folder.tag).bold()
                            Text(folder.hostPath)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                            Spacer()
                            Button(role: .destructive) {
                                sharedFolders.removeAll { $0.id == folder.id }
                            } label: { Image(systemName: "trash") }
                            .buttonStyle(.plain)
                        }
                    }
                    Button("Add Shared Folder…") {
                        let panel = NSOpenPanel()
                        panel.canChooseFiles = false
                        panel.canChooseDirectories = true
                        if panel.runModal() == .OK, let url = panel.url {
                            let tag = SharedFolderValidation.suggestedTag(for: url.path)
                            sharedFolders.append(SharedFolder(hostPath: url.path, tag: tag))
                        }
                    }
                }
            }
            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(errors, id: \.description) { error in
                        Label(error.description, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                .font(.callout)
            }
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                Button("Save") {
                    viewModel.updateVM(edited)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .disabled(!errors.isEmpty)
            }
        }
        .padding()
        .frame(width: 520, height: 600)
    }
}
