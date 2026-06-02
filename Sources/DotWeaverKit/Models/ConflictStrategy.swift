import Foundation

public enum ConflictStrategy: String, Codable, CaseIterable, Sendable {
    case lastModifiedWins
    case localWins
    case remoteWins
    case manual
    
    public var description: String {
        switch self {
        case .lastModifiedWins: return "Use most recently modified version"
        case .localWins: return "Always keep local version"
        case .remoteWins: return "Always use remote version"
        case .manual: return "Ask user to resolve manually"
        }
    }
}
