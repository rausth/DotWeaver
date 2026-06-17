import Foundation

@MainActor
public final class SyncScheduler {
    private var task: Task<Void, Never>?
    private let syncAction: () async -> Void
    private let now: () -> Date

    public init(now: @escaping () -> Date = Date.init, syncAction: @escaping () async -> Void) {
        self.now = now
        self.syncAction = syncAction
    }

    deinit {
        task?.cancel()
    }

    public var isRunning: Bool {
        task != nil
    }

    public func configure(schedule: SyncSchedule) {
        task?.cancel()
        task = nil
        guard schedule.enabled else { return }
        let interval = max(schedule.intervalSeconds, SyncSchedule.minimumIntervalSeconds)
        task = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
                guard !Task.isCancelled, let self else { return }
                await self.syncAction()
            }
        }
    }

    public func stop() {
        task?.cancel()
        task = nil
    }
}
