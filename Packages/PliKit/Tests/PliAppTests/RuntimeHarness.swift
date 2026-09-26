import PliCore
@testable import PliApp
@testable import PliSystem

/// Runs a DirectorRuntime on virtual time with fake adapters, the way the app runs it on the Mac.
@MainActor final class RuntimeHarness {
    let scheduler = VirtualScheduler()
    let sensor: FakeLidSensor
    let snapshotter: FakeSnapshotter
    let wallpapers: FakeWallpapers
    let surfaces: FakeSurfaces
    let cursor = FakeCursor()
    let locker = FakeLocker()
    let lockState = FakeLockState()
    let clock = ManualClock()
    let environment: FakeEnvironment
    let runtime: DirectorRuntime

    init(settings: PliSettings = .default, environment: RuntimeEnvironment = .macBook, sensorAvailable: Bool = true, rest: Double? = 110) {
        sensor = FakeLidSensor(available: sensorAvailable)
        snapshotter = FakeSnapshotter(scheduler: scheduler)
        wallpapers = FakeWallpapers(scheduler: scheduler)
        surfaces = FakeSurfaces(scheduler: scheduler)
        self.environment = FakeEnvironment(environment)
        runtime = DirectorRuntime(settings: settings, adapters: DirectorRuntime.Adapters(
            sensor: sensor, snapshotter: snapshotter, wallpapers: wallpapers, surfaces: surfaces, cursor: cursor,
            locker: locker, lockState: lockState, clock: clock, scheduler: scheduler, environment: self.environment))
        runtime.start()
        if let rest { setLid(rest) }
    }

    var now: Double { scheduler.now }
    var phase: DirectorPhase { runtime.director.phase }

    /// The lid is at `angle` now. At rest the sensor's stream wakes the runtime; during frames the tick reads it.
    func setLid(_ angle: Double) {
        if sensor.publish(angle, at: now), !clock.isRunning { runtime.sensorUpdated(.angleChanged) }
    }

    /// Advances time frame by frame. `lid(t)` is the lid angle at time t, read like the sensor (whole degrees);
    /// nil means the sensor is silent. Timers fire when due; the clock ticks while it runs.
    func run(for seconds: Double, step: Double = 1.0 / 120, lid: ((Double) -> Double)? = nil) {
        let end = now + seconds
        while now < end - 1e-9 {
            scheduler.advance(to: now + step)
            if let lid { setLid(lid(now).rounded()) }
            if clock.isRunning { clock.fire() }
        }
    }

    /// Moves the lid linearly to `target` over `seconds`, then holds it there for `hold`.
    func moveLid(to target: Double, over seconds: Double, hold: Double = 0) {
        let from = sensor.latest?.angle ?? target
        let start = now
        run(for: seconds) { t in from + (target - from) * min((t - start) / seconds, 1) }
        if hold > 0 { run(for: hold) { _ in target } }
    }
}
