import Foundation

/// Detection and validation of the Windows 11 ARM ISO the user supplies.
///
/// WinOnMac never downloads Windows: the user gets the ISO from Microsoft
/// (Windows 11 ARM64) and picks the file in the setup wizard. These helpers
/// only check that the chosen file is plausibly that ISO, before the app
/// tries to boot from it.
public enum ISOValidation {

    /// Minimum plausible size of a Windows 11 ARM ISO.
    /// Real images are roughly 5–6 GB; anything far smaller is not a
    /// Windows installer. The threshold is deliberately set below the real
    /// size (3 GB) so a future, smaller image is not rejected outright.
    public static let minimumISOSizeBytes: UInt64 = 3 * 1_024 * 1_024 * 1_024

    /// File extensions the wizard accepts, matched case-insensitively.
    public static let acceptedExtensions: Set<String> = ["iso"]

    /// True when the path ends in `.iso` (case-insensitive).
    public static func looksLikeISO(path: String) -> Bool {
        let ext = (path as NSString).pathExtension.lowercased()
        return acceptedExtensions.contains(ext)
    }

    /// The file name without its extension, e.g. "Win11_24H2_ARM64".
    public static func baseName(of path: String) -> String {
        ((path as NSString).lastPathComponent as NSString).deletingPathExtension
    }

    /// Heuristic: does the file name look like a Windows 11 ARM64 image?
    /// Used only to show a gentle "this may not be a Windows 11 ARM ISO"
    /// warning in the wizard — it never blocks the user, because Microsoft
    /// renames images and users rename files. A file that passes this
    /// check is very likely the right one; a file that fails it is only
    /// flagged, never rejected.
    public static func looksLikeWindows11ARMISO(fileName: String) -> Bool {
        let lower = fileName.lowercased()
        let mentionsWindows11 = lower.contains("win11")
            || lower.contains("windows11")
            || lower.contains("windows_11")
            || lower.contains("windows-11")
        let mentionsARM = lower.contains("arm64") || lower.contains("arm")
        return mentionsWindows11 && mentionsARM
    }

    /// Size check against the minimum plausible ISO size.
    public static func isPlausibleSize(bytes: UInt64) -> Bool {
        bytes >= minimumISOSizeBytes
    }

    /// Full description of a candidate ISO file, for the wizard's
    /// confirmation step. `sizeBytes` is `nil` when the file cannot be
    /// read (deleted, permission denied, network volume gone).
    public struct ISOFileInfo: Equatable {
        public let path: String
        public let fileName: String
        public let sizeBytes: UInt64?

        public init(path: String, sizeBytes: UInt64?) {
            self.path = path
            self.fileName = (path as NSString).lastPathComponent
            self.sizeBytes = sizeBytes
        }

        public var hasISOExtension: Bool { ISOValidation.looksLikeISO(path: path) }
        public var looksLikeWindows11ARM: Bool {
            ISOValidation.looksLikeWindows11ARMISO(fileName: fileName)
        }
        public var hasPlausibleSize: Bool {
            guard let sizeBytes else { return false }
            return ISOValidation.isPlausibleSize(bytes: sizeBytes)
        }
        /// True only when every check passes. Used by the wizard to decide
        /// whether to enable "Continue" without a warning.
        public var isReadyToUse: Bool {
            hasISOExtension && hasPlausibleSize
        }
        /// Human-readable size, e.g. "5.4 GB", or "Unknown size".
        public var formattedSize: String {
            guard let sizeBytes else { return "Unknown size" }
            let gb = Double(sizeBytes) / 1_073_741_824.0
            return String(format: "%.1f GB", gb)
        }
    }
}
