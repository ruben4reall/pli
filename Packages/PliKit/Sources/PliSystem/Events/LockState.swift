import CoreGraphics
import Foundation

/// Whether the screen is locked right now, for wake and for polling while Pli waits for an unlock (spec 5.6).
@MainActor
public protocol LockStateReading: AnyObject {
    func isLocked() -> Bool
}

public enum LockState {
    /// The session dictionary key macOS sets while the lock screen is up.
    public static let lockedKey = "CGSSessionScreenIsLocked"

    public static func isLocked(session: [String: Any]?) -> Bool {
        guard let value = session?[lockedKey] else { return false }
        if let flag = value as? Bool { return flag }
        if let number = value as? NSNumber { return number.boolValue }
        return false
    }

    /// Reads the current session. Public API; the key itself is undocumented but stable since Mac OS X 10.5.
    public static func current() -> Bool {
        isLocked(session: CGSessionCopyCurrentDictionary() as? [String: Any])
    }
}

@MainActor
public final class SessionLockState: LockStateReading {
    public init() {}
    public func isLocked() -> Bool { LockState.current() }
}
