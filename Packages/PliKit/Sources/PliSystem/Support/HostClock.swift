import Darwin

/// The host clock: seconds since boot, paused during sleep. It is the clock of `CACurrentMediaTime()` and
/// `CADisplayLink`, so sensor samples, frames and timers share one time base. The director only needs it to be
/// monotonic: it measures sensor silence in tick time and suspends that measure from sleep to the first sample
/// after the wake, so the pause during sleep is not load-bearing.
public enum HostClock {
    public static func now() -> Double {
        Double(clock_gettime_nsec_np(CLOCK_UPTIME_RAW)) / 1_000_000_000
    }
}
