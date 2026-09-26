import Darwin
import Foundation

/// What General shows about this Mac and Pli's cost on it: the memory Pli uses right now (the figure Activity
/// Monitor shows), the chip and the model, and which of Pli's features work here.
public enum ThisMac {
    /// Pli's memory footprint in bytes (`phys_footprint`, as Activity Monitor's Memory column), or nil.
    public static func memoryFootprint() -> UInt64? {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<integer_t>.size)
        let result = withUnsafeMutablePointer(to: &info) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), $0, &count)
            }
        }
        return result == KERN_SUCCESS ? info.phys_footprint : nil
    }

    /// Megabytes, as Activity Monitor writes them (1 MB = 1 048 576 bytes), rounded.
    public static func megabytes(_ bytes: UInt64) -> Int { Int((Double(bytes) / 1_048_576).rounded()) }

    /// "Apple M3 Pro", or nil.
    public static var chip: String? { sysctl("machdep.cpu.brand_string") }

    /// "Mac15,6", or nil.
    public static var modelIdentifier: String? { sysctl("hw.model") }

    /// "MacBook Pro", "MacBook Air", or nil, from the model identifier's family.
    public static var family: String? {
        guard let model = modelIdentifier?.lowercased() else { return nil }
        if model.hasPrefix("macbookpro") { return "MacBook Pro" }
        if model.hasPrefix("macbookair") { return "MacBook Air" }
        if model.hasPrefix("macbook") { return "MacBook" }
        return nil
    }

    /// Physical memory in gigabytes.
    public static var memoryGB: Int { Int((Double(ProcessInfo.processInfo.physicalMemory) / 1_073_741_824).rounded()) }

    /// The share of the Mac's memory Pli uses, in percent with one decimal ("0.1").
    public static func shareOfMemory(_ bytes: UInt64) -> Double {
        let total = Double(ProcessInfo.processInfo.physicalMemory)
        return total > 0 ? (Double(bytes) / total * 1000).rounded() / 10 : 0
    }

    private static func sysctl(_ name: String) -> String? {
        var size = 0
        guard sysctlbyname(name, nil, &size, nil, 0) == 0, size > 1 else { return nil }
        var bytes = [CChar](repeating: 0, count: size)
        guard sysctlbyname(name, &bytes, &size, nil, 0) == 0 else { return nil }
        let text = String(decoding: bytes.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
        return text.isEmpty ? nil : text
    }
}

/// Which of Pli's features this Mac supports, for General's "This Mac" card.
public struct Compatibility: Equatable, Sendable {
    public enum Level: Equatable, Sendable {
        /// The fold follows the lid.
        case full
        /// No lid sensor Pli can read: the shortcuts only (demo, animated lock, unlock reveal).
        case shortcutsOnly
    }

    public var level: Level
    public var lockScreen: Bool
    public var animatedLock: Bool
    public var capture: Bool

    public init(live: LiveSnapshot) {
        level = live.sensorAvailable ? .full : .shortcutsOnly
        lockScreen = live.lockScreenSurfaceAvailable
        animatedLock = live.canLockNow
        capture = live.screenCaptureAllowed
    }
}
