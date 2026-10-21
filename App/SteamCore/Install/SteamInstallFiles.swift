import Foundation

/// Minimal path helpers required by Madeira's DepotDownloader.
/// Full Madeira SteamInstall.swift also parses appmanifest records; this
/// companion only needs safe folder/relative path validation.
enum SteamInstallFiles {
    /// Validates a manifest path and folds directory spelling to the first
    /// one seen (case-insensitively). Returns nil for anything that could
    /// escape the install folder.
    nonisolated static func safeRelativePath(_ name: String, folded: inout [String: String]) -> String? {
        let parts = name
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/", omittingEmptySubsequences: true)
            .map(String.init)
        guard !parts.isEmpty,
              parts.count <= 64,
              name.utf8.count < 1024,
              !parts.contains(where: {
                  $0 == "." || $0 == ".." || $0.contains(":") ||
                      $0.unicodeScalars.contains(where: { $0.value < 0x20 })
              }) else { return nil }

        var built: [String] = []
        for (index, part) in parts.enumerated() {
            if index == parts.count - 1 {
                built.append(part)
                break
            }
            let key = (built + [part]).joined(separator: "/").lowercased()
            if let existing = folded[key] {
                built = existing.split(separator: "/").map(String.init)
            } else {
                built.append(part)
                folded[key] = built.joined(separator: "/")
            }
        }
        return built.joined(separator: "/")
    }

    /// Install folders come from app metadata; keep them to one safe component.
    nonisolated static func safeFolderName(_ name: String) -> String {
        let cleaned = name
            .replacingOccurrences(of: "\\", with: "/")
            .split(separator: "/")
            .last
            .map(String.init) ?? ""
        guard !cleaned.isEmpty,
              cleaned != ".",
              cleaned != "..",
              !cleaned.contains(":"),
              !cleaned.unicodeScalars.contains(where: { $0.value < 0x20 }) else {
            return "app"
        }
        return cleaned
    }
}
