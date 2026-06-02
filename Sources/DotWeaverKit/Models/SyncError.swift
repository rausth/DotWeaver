import Foundation

enum SyncError: LocalizedError {
    case configurationMissing(String)
    case authenticationFailed
    case networkError(String)
    case conflictDetected([Dotfile])
    case fileNotFound(String)
    
    var errorDescription: String? {
        switch self {
        case .configurationMissing(let message):
            return "Configuration missing: \(message)"
        case .authenticationFailed:
            return "Authentication failed. Please check your credentials."
        case .networkError(let message):
            return "Network error: \(message)"
        case .conflictDetected(let files):
            return "Conflict detected in \(files.count) files"
        case .fileNotFound(let path):
            return "File not found: \(path)"
        }
    }
}
