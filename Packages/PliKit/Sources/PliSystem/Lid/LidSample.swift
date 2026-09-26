import Foundation

/// One reading of the lid angle (spec 6.1).
public struct LidSample: Sendable, Equatable {
    /// Whole degrees, as the sensor reports them.
    public var angle: Double
    /// Host time of the read (`HostClock`).
    public var time: Double
    /// Grows by one on every successful read, so a reader can tell a fresh reading from one it already has,
    /// even when the angle did not change.
    public var sequence: UInt64

    public init(angle: Double, time: Double, sequence: UInt64) {
        self.angle = angle
        self.time = time
        self.sequence = sequence
    }
}

/// What the sensor signals on its stream. Samples themselves are read from `LidSensing.latest`.
public enum LidSensorUpdate: Sendable, Equatable {
    case angleChanged
    case availabilityChanged(Bool)
}

/// How often the sensor is read (spec 10.3).
public enum LidPollingMode: Sendable, Equatable {
    /// Lid at rest: pushed reports, plus `LidSensor.restPollingHz` reads per second.
    case rest
    /// During a gesture: reads at the display's rate.
    case active(hz: Double)
}

/// The lid, as the runtime sees it: the real sensor, or the simulator.
@MainActor
public protocol LidSensing: AnyObject {
    var latest: LidSample? { get }
    var isAvailable: Bool { get }
    /// Signals angle changes and availability changes. One consumer: the runtime.
    var updates: AsyncStream<LidSensorUpdate> { get }
    func start()
    func stop()
    func setMode(_ mode: LidPollingMode)
    /// After a wake: check the sensor still answers, and reopen it if not (spec 10.4).
    func didWake()
}

/// The lid angle feature report: report 1, angle as a little-endian UInt16 at bytes 1 and 2 (spec 10.4).
public enum LidReport {
    public static let reportID: CFIndex = 1
    public static let length = 8

    /// The angle in a report, or nil when the report is short or holds an impossible value.
    public static func angle(from bytes: [UInt8]) -> Double? {
        guard bytes.count >= 3 else { return nil }
        let raw = UInt16(bytes[1]) | UInt16(bytes[2]) << 8
        guard raw <= 360 else { return nil }
        return Double(raw)
    }
}

/// The sensor's shared bookkeeping, pure so it is tested without hardware.
public struct LidSampleBook: Sendable, Equatable {
    public private(set) var latest: LidSample?
    public private(set) var isAvailable = false

    public init() {}

    /// Records a successful read. True when the angle differs from the previous reading.
    public mutating func record(angle: Double, at time: Double) -> Bool {
        let changed = latest?.angle != angle
        latest = LidSample(angle: angle, time: time, sequence: (latest?.sequence ?? 0) + 1)
        return changed
    }

    /// True when availability flipped.
    public mutating func setAvailable(_ available: Bool) -> Bool {
        defer { isAvailable = available }
        return isAvailable != available
    }
}
