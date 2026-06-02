import Foundation

public enum SyncProvider: String, CaseIterable, Identifiable, Codable, Sendable {
    case git
    case icloud
    case onedrive
    case googledrive
    case dropbox
    case webdav
    case sftp
    case ftps
    case s3
    
    public var id: String { rawValue }
    
    public var title: String {
        switch self {
        case .git: return "Git"
        case .icloud: return "iCloud Drive"
        case .onedrive: return "OneDrive"
        case .googledrive: return "Google Drive"
        case .dropbox: return "Dropbox"
        case .webdav: return "WebDAV"
        case .sftp: return "SFTP"
        case .ftps: return "FTPS"
        case .s3: return "Amazon S3"
        }
    }
}
