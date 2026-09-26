import os

/// Pli's system log (spec 10.9): numbers and states only, never an image, a window title or a path.
public enum Log {
    public static let subsystem = "ch.rubencatalao.pli"
    public static let sensor = Logger(subsystem: subsystem, category: "sensor")
    public static let capture = Logger(subsystem: subsystem, category: "capture")
    public static let runtime = Logger(subsystem: subsystem, category: "runtime")
    public static let surfaces = Logger(subsystem: subsystem, category: "surfaces")
    public static let system = Logger(subsystem: subsystem, category: "system")
}
