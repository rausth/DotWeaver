import Foundation

public final class FileWatcher {
    private var fileDescriptor: Int32 = -1
    private var source: DispatchSourceFileSystemObject?
    private let path: String
    private let callback: () -> Void
    
    public init(path: String, callback: @escaping () -> Void) {
        self.path = (path as NSString).expandingTildeInPath
        self.callback = callback
    }
    
    public func start() {
        fileDescriptor = open(path, O_EVTONLY)
        guard fileDescriptor != -1 else { return }
        
        source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fileDescriptor,
            eventMask: .write,
            queue: DispatchQueue.global()
        )
        
        source?.setEventHandler { [weak self] in
            self?.callback()
        }
        
        source?.setCancelHandler { [weak self] in
            guard let self = self else { return }
            close(self.fileDescriptor)
        }
        
        source?.resume()
    }
    
    public func stop() {
        source?.cancel()
    }
    
    deinit {
        stop()
    }
}
