import Foundation

public struct Dotfile: Identifiable, Codable, Sendable, Hashable {
    public var id: UUID
    public var path: String
    public var lastLocalModified: Date?
    public var lastRemoteModified: Date?
    public var lastSynced: Date?
    public var status: SyncStatus
    public var conflictStrategy: ConflictStrategy
    public var isMonitored: Bool
    public var isSecret: Bool
    public var tags: [String]
    public var group: String?
    public var preSyncHook: String?
    public var postSyncHook: String?
    
    public init(
        id: UUID = UUID(),
        path: String,
        lastLocalModified: Date? = nil,
        lastRemoteModified: Date? = nil,
        lastSynced: Date? = nil,
        status: SyncStatus = .synced,
        conflictStrategy: ConflictStrategy = .lastModifiedWins,
        isMonitored: Bool = true,
        isSecret: Bool = false,
        tags: [String] = [],
        group: String? = nil,
        preSyncHook: String? = nil,
        postSyncHook: String? = nil
    ) {
        self.id = id
        self.path = path
        self.lastLocalModified = lastLocalModified
        self.lastRemoteModified = lastRemoteModified
        self.lastSynced = lastSynced
        self.status = status
        self.conflictStrategy = conflictStrategy
        self.isMonitored = isMonitored
        self.isSecret = isSecret
        self.tags = tags
        self.group = group
        self.preSyncHook = preSyncHook
        self.postSyncHook = postSyncHook
    }
}

public enum SyncStatus: String, Codable, Sendable, Hashable {
    case synced, modified, conflict, error
}
