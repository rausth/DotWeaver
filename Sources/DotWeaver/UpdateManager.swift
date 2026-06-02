import Foundation
import Combine
#if canImport(Sparkle)
import Sparkle
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    @Published var canCheckForUpdates: Bool = false
    private let updaterController: SPUStandardUpdaterController
    private init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )
        
        // Observe canCheckForUpdates
        updaterController.updater.publisher(for: \.canCheckForUpdates)
            .assign(to: &$canCheckForUpdates)
    }
    
    func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
    
    var automaticallyChecksForUpdates: Bool {
        get { updaterController.updater.automaticallyChecksForUpdates }
        set { updaterController.updater.automaticallyChecksForUpdates = newValue }
    }
    
    var updateCheckInterval: TimeInterval {
        get { updaterController.updater.updateCheckInterval }
        set { updaterController.updater.updateCheckInterval = newValue }
    }
}
#else
@MainActor
final class UpdateManager: ObservableObject {
    static let shared = UpdateManager()
    @Published var canCheckForUpdates: Bool = false
    private init() {}
    func checkForUpdates() {}
    var automaticallyChecksForUpdates: Bool = false
    var updateCheckInterval: TimeInterval = 0
}
#endif
