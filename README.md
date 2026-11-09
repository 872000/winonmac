# WinOnMac

**Run Windows 11 on your Apple Silicon Mac — a virtual machine manager built on Apple's Virtualization framework.**

WinOnMac is a macOS app that creates and runs Windows 11 virtual machines using the same framework Apple ships in macOS — no third-party hypervisor, no subscription, nothing to install beyond the app itself. Pick a Windows 11 ARM ISO, choose CPU / RAM / disk, and boot Windows in a window on your Mac.

100% offline. No accounts, no network calls, no telemetry — your VMs never leave your Mac.

## What it does

- **Setup wizard** — pick a Windows 11 ARM ISO from Microsoft, name the VM, choose CPU count, RAM, and disk size, add shared folders, pick a display resolution.
- **Start / Stop / Pause / Resume** — full VM lifecycle from the sidebar, with a live display window (mouse and keyboard captured while you work in Windows).
- **VM list with per-VM settings** — every VM's CPU, RAM, disk (grow-only), display, and shared folders are editable; changes apply on the next start.
- **Shared folders** — folders on your Mac exposed into Windows via virtio filesystem, so moving files between macOS and the VM is drag-and-drop simple.
- **Snapshots** — save a snapshot of a stopped VM and restore it later. A snapshot is a copy of the VM's disk image plus metadata, so restoring brings the whole machine back to that moment. (Snapshots cost disk space — the total is shown in the snapshot sheet.)

## Honest scope and limits — read this first

- **Apple Silicon only.** The Virtualization framework exists only on Apple Silicon Macs. This app will not run on an Intel Mac, and there is no Intel path.
- **Windows 11 ARM guest only.** x86 / x64 Windows cannot run under the Virtualization framework — there is no emulation layer. You need the **Windows 11 ARM64** image from Microsoft, not the regular PC download.
- **You supply Windows.** WinOnMac never downloads Windows. You must get the Windows 11 ARM64 ISO from Microsoft yourself and you need your own Windows license.
- **No TPM.** The Virtualization framework provides no TPM device, and the Windows 11 installer normally refuses to proceed without one. The first-boot steps below include the documented registry bypass used during installation (the same step other Virtualization-framework VM apps document).
- **Snapshots are disk copies, not framework snapshots.** The Virtualization framework has no snapshot API, so a snapshot copies the whole disk image while the VM is stopped. A 128 GB disk means a ~128 GB snapshot file. Snapshots can only be taken and restored while the VM is stopped.
- **Not verified on this build machine.** This repository was built on Linux, where the Swift app cannot be compiled and a real VM boot cannot be run. The pure logic (`WinOnMacCore`) is unit-tested (see below); the app itself, the Virtualization configuration, and the first boot are verified on a Mac only — see [What was and was not verified](#what-was-and-was-not-verified).

## Project structure

```
WinOnMac/
├── Package.swift                  # Swift Package Manager — pure-logic library + tests
├── Sources/WinOnMacCore/          # Business logic (Foundation only, no UI imports)
│   ├── VMConfiguration.swift      # VM model: resources, defaults, clamping, disk paths
│   ├── VMValidation.swift         # Wizard validation — every problem reported at once
│   ├── ISOValidation.swift        # Windows 11 ARM ISO detection + size checks
│   ├── Snapshot.swift             # Snapshot metadata + snapshot library rules
│   ├── VMState.swift              # VM lifecycle state machine (start/stop/pause/…)
│   ├── VMStore.swift              # VM list invariants (unique names, sorted)
│   ├── SharedFolder.swift         # Shared-folder model + tag validation
│   └── DisplaySettings.swift      # Display resolutions + presets
├── App/                           # SwiftUI macOS app (Xcode target, not part of `swift test`)
│   ├── WinOnMacApp.swift          # @main entry point
│   ├── ContentView.swift          # VM list sidebar + detail pane + state badges
│   ├── VMDisplayView.swift        # VZVirtualMachineView wrapper (the live display)
│   ├── VirtualMachineManager.swift# VZVirtualMachineConfiguration builder, run control, snapshots
│   ├── VMViewModel.swift          # App state: VM list, run states, snapshots
│   ├── VMStore+Persistence.swift  # JSON persistence in Application Support
│   ├── VMSetupWizard.swift        # 4-step wizard: ISO → Resources → Sharing → Review
│   ├── VMSettingsView.swift       # Per-VM settings editor
│   └── SnapshotListView.swift     # Take / restore / delete snapshots
└── Tests/WinOnMacCoreTests/       # XCTest suite for all business logic (85 tests)
```

## Requirements

- Apple Silicon Mac (M1 or later)
- macOS 14 Sonoma or later (Virtualization framework features used here, including pause/resume, need macOS 14+; macOS 15 recommended)
- Xcode 15 or later
- A Windows 11 ARM64 ISO from Microsoft, and a Windows license

## Run the logic tests (no Xcode needed)

The business logic is a pure Swift package — no SwiftUI, no Apple-only frameworks.

```bash
swift test
```

85 tests cover configuration math and clamping, validation of every field, ISO detection and size checks, snapshot rules, the VM state machine, the VM list invariants, shared-folder tags, and display settings.

## Open the app in Xcode

1. Open Xcode → **File → New → Project → macOS → App**, name it `WinOnMac`, interface **SwiftUI**, language **Swift**. (Do not tick "Include Tests" — the tests live in the Swift package.)
2. **File → Add Package Dependencies → Add Local…** and select this folder, then add `WinOnMacCore` to the app target's **Frameworks, Libraries, and Embedded Content**.
3. Drag the `App/` folder's `.swift` files into the Xcode project.
4. In the app target's **Signing & Capabilities**, make sure the app is signed with your Apple ID (the Virtualization framework requires a signed app; a free Personal Team works). No extra entitlements are needed for the features in this app.
5. Build & run (⌘R) on your Mac.

> The `App/` folder is intentionally outside the SwiftPM build: `swift test` compiles and tests only the pure logic, while the SwiftUI + Virtualization layer is written for Xcode on a Mac (Swift 5.9+, macOS 14+).

## Get Windows 11 ARM

1. Go to Microsoft's Windows 11 ARM64 download page (search "Download Windows 11 ARM64" on microsoft.com) and download the ARM64 ISO. It is roughly 5–6 GB.
2. You need a valid Windows 11 license to activate it. The VM will run unactivated for installation and testing, with the usual unactivated limitations, until you enter a key.
3. Do **not** download the regular x86 Windows 11 ISO — it cannot boot in this app.

## First boot — installing Windows

1. Launch WinOnMac and click **New VM**.
2. **Step 1 — ISO:** click **Browse…** and pick the Windows 11 ARM64 ISO you downloaded. The wizard checks the file looks like a Windows 11 ARM installer and warns you if it does not.
3. **Step 2 — Resources:** 4 CPUs and 8 GB of RAM is a good start; Windows 11 needs at least 4 GB of RAM and a 64 GB disk. Give it a 128 GB disk unless you are short on space.
4. **Step 3 — Sharing & Display:** optionally add a shared folder (e.g. your Documents folder) and pick a display resolution.
5. **Step 4 — Review:** check the summary and click **Create Virtual Machine**.
6. Select the VM and click **Start**. The Windows installer boots.
7. **TPM bypass (needed):** when the installer asks "Select the version of Windows", press **Shift + F10** to open a command prompt and run:
   ```
   reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1
   reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1
   reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1
   ```
   Then close the prompt and continue. Without this the installer refuses to proceed, because the Virtualization framework provides no TPM.
8. Install Windows as normal. Pick the disk the VM created (it appears as the only drive). The install takes a while and the VM restarts a few times — that is normal.
9. After Windows is up, take a snapshot (**Snapshots** button) so you can always get back to a clean install.
10. To move files between macOS and Windows, use the shared folder you added in the wizard. In Windows it appears as a network share; if it does not appear automatically, open File Explorer and browse the network locations.

## How snapshots work

- Snapshots are taken **only while the VM is stopped** — a running VM's disk image cannot be copied safely.
- Taking a snapshot copies the disk image file into the VM's `Snapshots` folder and records the VM's settings at that moment.
- Restoring replaces the current disk image with the snapshot copy. The current disk is kept as `disk.img.before-restore` first, so a restore is never destructive — but anything changed since the snapshot is gone from the VM.
- Each snapshot costs as much disk space as the VM's disk. The snapshot sheet shows the running total.

## Where things live on your Mac

- VM list: `~/Library/Application Support/WinOnMac/vms.json`
- Per VM: `~/Library/Application Support/WinOnMac/VMs/<vm-name>/` — `disk.img`, `efi.nvram`, `machine-identifier`, and the `Snapshots/` folder.
- Deleting a VM in the app deletes its whole folder, including the disk image and snapshots.

## What was and was not verified

- **Verified:** the `WinOnMacCore` logic — 85 XCTest cases covering configuration, validation, ISO detection, snapshots, the VM state machine, the VM list, shared folders, and display settings. On this Linux build machine there is no Swift toolchain, so the Swift tests were **not** executed here; instead the same rules were executed through a Python transliteration of the pure logic, and all 85 mirrored assertions passed. On a Mac, run `swift test` to execute the real XCTest suite.
- **Not verified here:** compiling the SwiftUI app, the `VZVirtualMachineConfiguration` build, and an actual Windows 11 ARM boot. Those need Xcode on an Apple Silicon Mac and a Windows 11 ARM ISO, and are verified on the Mac only.

## Tech stack

- Swift 5.9+ / SwiftUI / AppKit
- Apple's Virtualization framework (`VZVirtualMachine`, `VZVirtualMachineView`, `VZEFIBootLoader`, virtio block / network / graphics / filesystem devices)
- Swift Package Manager for the testable core; XCTest for the suite

## License

MIT — see [LICENSE](LICENSE).
