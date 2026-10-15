import Foundation

/// Error type used by the selected Steam library protocol code.
enum SteamFileError: LocalizedError {
    case invalid(String)

    var errorDescription: String? {
        switch self {
        case .invalid(let message):
            return message
        }
    }
}
