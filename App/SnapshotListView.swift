import SwiftUI

/// Snapshot list for one VM: take a new snapshot (stopped VMs only),
/// restore one, or delete one.
///
/// Snapshots are full copies of the disk image, so each one costs as
/// much disk space as the VM's disk — the total size is shown at the
/// bottom so the cost is never a surprise.
struct SnapshotListView: View {
    @EnvironmentObject private var viewModel: VMViewModel
    @Environment(\.dismiss) private var dismiss

    let vm: VMConfiguration

    @State private var newSnapshotName = ""
    @State private var newSnapshotNote = ""
    @State private var snapshotPendingRestore: SnapshotMetadata?
    @State private var snapshotPendingDelete: SnapshotMetadata?

    private var library: SnapshotLibrary {
        SnapshotLibrary(snapshots: viewModel.snapshots(for: vm.id))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Snapshots — \(vm.name)")
                .font(.title2)

            if viewModel.state(for: vm.id).canTakeSnapshot {
                VStack(alignment: .leading, spacing: 8) {
                    TextField("Snapshot name", text: $newSnapshotName)
                        .textFieldStyle(.roundedBorder)
                    TextField("Note (optional)", text: $newSnapshotNote)
                        .textFieldStyle(.roundedBorder)
                    Button("Take Snapshot") {
                        viewModel.takeSnapshot(for: vm, name: newSnapshotName, note: newSnapshotNote)
                        newSnapshotName = ""
                        newSnapshotNote = ""
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(SnapshotValidation.validateName(newSnapshotName) != nil)
                    Text("Takes a copy of the disk image. The VM must be stopped.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
            } else {
                Label("Stop the VM to take or restore snapshots.", systemImage: "info.circle")
                    .foregroundStyle(.orange)
                    .font(.callout)
            }

            Divider()

            if library.snapshots.isEmpty {
                Text("No snapshots yet.")
                    .foregroundStyle(.secondary)
            } else {
                List(library.snapshots) { snapshot in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(snapshot.name).bold()
                            Spacer()
                            Text(snapshot.formattedSize)
                                .foregroundStyle(.secondary)
                        }
                        Text(snapshot.createdAt, style: .date)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if !snapshot.note.isEmpty {
                            Text(snapshot.note)
                                .font(.callout)
                        }
                        HStack {
                            Button("Restore") {
                                snapshotPendingRestore = snapshot
                            }
                            .disabled(!viewModel.state(for: vm.id).canRestoreSnapshot)
                            Button("Delete", role: .destructive) {
                                snapshotPendingDelete = snapshot
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(.vertical, 4)
                }
                .frame(maxHeight: 300)

                Text("Total snapshot size: \(formattedBytes(library.totalSizeBytes))")
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Spacer()
                Button("Done") { dismiss() }
                    .buttonStyle(.borderedProminent)
            }
        }
        .padding()
        .frame(width: 520, height: 600)
        .alert("Restore this snapshot?", isPresented: Binding(
            get: { snapshotPendingRestore != nil },
            set: { if !$0 { snapshotPendingRestore = nil } }
        )) {
            Button("Cancel", role: .cancel) { snapshotPendingRestore = nil }
            Button("Restore", role: .destructive) {
                if let snapshot = snapshotPendingRestore {
                    viewModel.restoreSnapshot(snapshot, for: vm)
                }
                snapshotPendingRestore = nil
            }
        } message: {
            Text("The current disk is replaced with the snapshot. The current disk is kept as a backup file, but any changes since the snapshot was taken are lost from the VM.")
        }
        .alert("Delete this snapshot?", isPresented: Binding(
            get: { snapshotPendingDelete != nil },
            set: { if !$0 { snapshotPendingDelete = nil } }
        )) {
            Button("Cancel", role: .cancel) { snapshotPendingDelete = nil }
            Button("Delete", role: .destructive) {
                if let snapshot = snapshotPendingDelete {
                    viewModel.deleteSnapshot(snapshot, for: vm)
                }
                snapshotPendingDelete = nil
            }
        } message: {
            Text("The snapshot's disk copy is deleted. This cannot be undone.")
        }
    }

    private func formattedBytes(_ bytes: UInt64) -> String {
        String(format: "%.1f GB", Double(bytes) / 1_073_741_824.0)
    }
}
