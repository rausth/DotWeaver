import Foundation

public enum ActivityType: String, Codable, Sendable {
    case sync
    case edit
    case add
    case system
}

public struct ActivityLog: Identifiable, Codable, Sendable {
    public let id: UUID
    public let message: String
    public let timestamp: Date
    public let type: ActivityType
    
    public init(id: UUID = UUID(), message: String, timestamp: Date = Date(), type: ActivityType) {
        self.id = id
        self.message = message
        self.timestamp = timestamp
        self.type = type
    }
}
