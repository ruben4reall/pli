import Foundation
import QuartzCore

/// Real time and timers on the main run loop, in common modes so they keep firing while a menu is open.
@MainActor
public final class MainScheduler: Scheduling {
    public init() {}

    public var now: Double { CACurrentMediaTime() }

    @discardableResult
    public func after(_ delay: Double, _ action: @escaping @MainActor () -> Void) -> any Cancellable {
        schedule(Timer(timeInterval: max(delay, 0), repeats: false) { _ in MainActor.assumeIsolated { action() } })
    }

    @discardableResult
    public func every(_ interval: Double, _ action: @escaping @MainActor () -> Void) -> any Cancellable {
        let timer = Timer(timeInterval: interval, repeats: true) { _ in MainActor.assumeIsolated { action() } }
        timer.tolerance = interval * 0.1
        return schedule(timer)
    }

    private func schedule(_ timer: Timer) -> any Cancellable {
        RunLoop.main.add(timer, forMode: .common)
        return TimerToken(timer: timer)
    }
}

@MainActor
final class TimerToken: Cancellable {
    private let timer: Timer

    init(timer: Timer) {
        self.timer = timer
    }

    func cancel() {
        timer.invalidate()
    }
}
