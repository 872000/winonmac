import SwiftUI
import UniformTypeIdentifiers

/// Four-step setup wizard: ISO → Resources → Shared folders & display →
/// Review. Every step validates through `WinOnMacCore`, so the wizard can
/// never produce a configuration `VZVirtualMachineConfiguration` would
/// reject for a reason the user could have fixed here.
struct VMSetupWizard: View {
    @EnvironmentObject private var viewModel: VMViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var step = 0
    @State private var name = "Windows 11"
    @State private var cpuCount = 4
    @State private var memoryMB = 8_192
    @State private var diskSizeGB = 128
    @State private var isoPath = ""
    @State private var isoInfo: ISOValidation.ISOFileInfo?
    @State private var sharedFolders: [SharedFolder] = []
    @State private var display = DisplaySettings.default

    private var draft: VMConfiguration {
        VMConfiguration(
            name: name,
            cpuCount: cpuCount,
            memoryMB: memoryMB,
            diskSizeGB: diskSizeGB,
            isoPath: isoPath,
            sharedFolders: sharedFolders,
            display: display
        )
    }

    private var errors: [ValidationError] { VMValidation.validate(draft) }

    var body: some View {
        VStack(spacing: 0) {
            Text("New Virtual Machine")
                .font(.title2)
                .padding(.top)

            Picker("Step", selection: $step) {
                Text("1. ISO").tag(0)
                Text("2. Resources").tag(1)
                Text("3. Sharing & Display").tag(2)
                Text("4. Review").tag(3)
            }
            .pickerStyle(.segmented)
            .padding()

            Group {
                switch step {
                case 0: isoStep
                case 1: resourcesStep
                case 2: sharingStep
                default: reviewStep
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(.horizontal)

            Divider()
            HStack {
                Button("Cancel") { dismiss() }
                Spacer()
                if step > 0 {
                    Button("Back") { step -= 1 }
                }
                if step < 3 {
                    Button("Continue") { step += 1 }
                        .buttonStyle(.borderedProminent)
                        .disabled(!canContinueFromStep(step))
                } else {
                    Button("Create Virtual Machine") {
                        viewModel.addVM(draft)
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!errors.isEmpty)
                }
            }
            .padding()
        }
        .frame(width: 560, height: 520)
    }

    // MARK: - Step 1: ISO

    private var isoStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Choose the Windows 11 ARM installer")
                .font(.headline)
            Text("Download the Windows 11 ARM64 ISO from Microsoft first — WinOnMac never downloads Windows for you, and you need your own license. Only ARM64 works: an x86 Windows ISO cannot boot under the Virtualization framework.")
                .font(.callout)
                .foregroundStyle(.secondary)
            HStack {
                TextField("Windows 11 ARM ISO", text: $isoPath)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: isoPath) { _, newValue in
                        isoInfo = isoInfo(for: newValue)
                    }
                Button("Browse…") {
                    let panel = NSOpenPanel()
                    panel.allowedContentTypes = [.init(filenameExtension: "iso") ?? .data]
                    panel.canChooseFiles = true
                    panel.canChooseDirectories = false
                    if panel.runModal() == .OK, let url = panel.url {
                        isoPath = url.path
                        isoInfo = isoInfo(for: url.path)
                    }
                }
            }
            if let info = isoInfo {
                VStack(alignment: .leading, spacing: 4) {
                    Text("File: \(info.fileName)")
                    Text("Size: \(info.formattedSize)")
                    if !info.looksLikeWindows11ARM {
                        Label("This file's name does not look like a Windows 11 ARM ISO. It may still work — check it is the ARM64 image from Microsoft.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else if !info.hasPlausibleSize {
                        Label("This file looks smaller than a Windows 11 installer. Make sure the download finished.", systemImage: "exclamationmark.triangle")
                            .foregroundStyle(.orange)
                    } else {
                        Label("Looks like a Windows 11 ARM installer.", systemImage: "checkmark.circle")
                            .foregroundStyle(.green)
                    }
                }
                .font(.callout)
            }
            TextField("Virtual machine name", text: $name)
                .textFieldStyle(.roundedBorder)
        }
    }

    private func isoInfo(for path: String) -> ISOValidation.ISOFileInfo? {
        guard !path.isEmpty else { return nil }
        let size = (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? UInt64)
            ?? (try? FileManager.default.attributesOfItem(atPath: path)[.size] as? NSNumber)?.uint64Value
        return ISOValidation.ISOFileInfo(path: path, sizeBytes: size)
    }

    // MARK: - Step 2: Resources

    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("How much of your Mac should Windows get?")
                .font(.headline)
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
                Text("Disk: \(diskSizeGB) GB")
                Slider(value: Binding(
                    get: { Double(diskSizeGB) },
                    set: { diskSizeGB = Int($0) }
                ), in: Double(VMConfiguration.minimumDiskSizeGB)...Double(VMConfiguration.maximumDiskSizeGB),
                step: 16)
            }
            Text("Windows 11 needs at least 4 GB of RAM and a 64 GB disk. More RAM makes Windows noticeably faster; the disk is a fixed-size file created when the VM is first started.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 3: Sharing & display

    private var sharingStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Shared folders & display")
                .font(.headline)
            Text("Shared folders appear inside Windows so you can move files between macOS and the VM.")
                .font(.callout)
                .foregroundStyle(.secondary)
            ForEach(sharedFolders) { folder in
                HStack {
                    Text(folder.tag).bold()
                    Text(folder.hostPath)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Spacer()
                    Button(role: .destructive) {
                        sharedFolders.removeAll { $0.id == folder.id }
                    } label: {
                        Image(systemName: "trash")
                    }
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
            Divider()
            Text("Display")
                .font(.headline)
            Picker("Resolution", selection: $display) {
                ForEach(DisplaySettings.presets, id: \.self) { preset in
                    Text(preset.label).tag(preset)
                }
            }
            .pickerStyle(.segmented)
            Text("The resolution Windows is offered. You can change it later in Settings.")
                .font(.callout)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Step 4: Review

    private var reviewStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Review your virtual machine")
                .font(.headline)
            LabeledContent("Name", value: name)
            LabeledContent("Resources", value: draft.summary)
            LabeledContent("Display", value: display.label)
            LabeledContent("Installer", value: ISOValidation.baseName(of: isoPath))
            if !sharedFolders.isEmpty {
                LabeledContent("Shared folders", value: sharedFolders.map { $0.tag }.joined(separator: ", "))
            }
            if !errors.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    ForEach(errors, id: \.description) { error in
                        Label(error.description, systemImage: "exclamationmark.circle")
                            .foregroundStyle(.red)
                    }
                }
                .font(.callout)
            } else {
                Label("Ready to create. The disk image is created when you first start the VM.", systemImage: "checkmark.circle")
                    .foregroundStyle(.green)
            }
        }
    }

    private func canContinueFromStep(_ step: Int) -> Bool {
        switch step {
        case 0:
            return !isoPath.isEmpty
                && ISOValidation.looksLikeISO(path: isoPath)
                && !name.trimmingCharacters(in: .whitespaces).isEmpty
        case 1:
            return errors.allSatisfy { $0.field != "cpuCount" && $0.field != "memoryMB" && $0.field != "diskSizeGB" }
        case 2:
            return errors.allSatisfy { !$0.field.hasPrefix("sharedFolders.") && !$0.field.hasPrefix("display.") }
        default:
            return true
        }
    }
}
