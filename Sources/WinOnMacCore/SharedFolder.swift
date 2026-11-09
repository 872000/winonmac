import Foundation

/// One folder on the Mac shared into the Windows guest.
///
/// Implemented with the Virtualization framework's virtio filesystem
/// device (`VZVirtioFileSystemDeviceConfiguration` + `VZSharedDirectory`),
/// which exposes the folder inside Windows as a network-style share the
/// guest mounts. The `tag` is the identifier the guest uses to find the
/// share, so it must be unique per VM and limited to safe characters.
public struct SharedFolder: Codable, Equatable, Identifiable {
    public var id: UUID
    /// Absolute path of the folder on the Mac, e.g. "/Users/parth/Documents".
    public var hostPath: String
    /// The share name the Windows guest sees, e.g. "Documents".
    public var tag: String

    public init(id: UUID = UUID(), hostPath: String, tag: String) {
        self.id = id
        self.hostPath = hostPath
        self.tag = tag
    }
}

public enum SharedFolderValidation {

    public static let maximumTagLength = 64

    /// Validates one shared folder. Returns one error per broken rule.
    public static func validate(_ folder: SharedFolder) -> [ValidationError] {
        var errors: [ValidationError] = []

        if folder.hostPath.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            errors.append(ValidationError(
                field: "hostPath",
                message: "Choose a folder on your Mac to share."
            ))
        } else if !(folder.hostPath as NSString).isAbsolutePath {
            errors.append(ValidationError(
                field: "hostPath",
                message: "Shared folder path must be an absolute path."
            ))
        }

        if let tagError = validateTag(folder.tag) {
            errors.append(ValidationError(field: "tag", message: tagError))
        }

        return errors
    }

    /// Tags may contain letters, digits, hyphens, and underscores only —
    /// the virtio filesystem tag is used as a share identifier inside the
    /// guest, and spaces or slashes break mounting.
    public static func validateTag(_ tag: String) -> String? {
        if tag.isEmpty { return "Give the shared folder a name." }
        if tag.count > maximumTagLength {
            return "Shared folder name must be \(maximumTagLength) characters or fewer."
        }
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        if tag.unicodeScalars.contains(where: { !allowed.contains($0) }) {
            return "Shared folder name may only contain letters, numbers, hyphens, and underscores."
        }
        return nil
    }

    /// Suggests a tag from a host path: the last path component, with
    /// spaces and unsafe characters replaced by hyphens.
    public static func suggestedTag(for hostPath: String) -> String {
        let last = (hostPath as NSString).lastPathComponent
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_"))
        let cleaned = last.unicodeScalars.map { allowed.contains($0) ? String($0) : "-" }.joined()
        let trimmed = cleaned.trimmingCharacters(in: CharacterSet(charactersIn: "-"))
        return trimmed.isEmpty ? "Shared" : trimmed
    }
}
