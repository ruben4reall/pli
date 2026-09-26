import AppKit
import CoreGraphics
import Darwin

/// Every private macOS symbol Pli uses, and the only file allowed to look one up (spec 10.7).
///
/// Each feature resolves its own symbols at runtime. A missing library or symbol turns that feature off: nothing
/// here can crash on a macOS release that renamed or removed a function. The README lists each symbol and why.
public enum PrivateAPI {
    public static let skyLightPath = "/System/Library/PrivateFrameworks/SkyLight.framework/Versions/A/SkyLight"
    public static let loginPath = "/System/Library/PrivateFrameworks/login.framework/Versions/A/login"

    /// Opens a library and finds symbols in it. Tests pass their own to play a macOS without some symbol.
    public struct SymbolLoader: Sendable {
        public var open: @Sendable (String) -> UnsafeMutableRawPointer?
        public var find: @Sendable (UnsafeMutableRawPointer, String) -> UnsafeMutableRawPointer?

        public init(open: @escaping @Sendable (String) -> UnsafeMutableRawPointer?,
                    find: @escaping @Sendable (UnsafeMutableRawPointer, String) -> UnsafeMutableRawPointer?) {
            self.open = open
            self.find = find
        }

        /// The real loader: `dlopen` and `dlsym`.
        public static let system = SymbolLoader(open: { dlopen($0, RTLD_LAZY) }, find: { dlsym($0, $1) })

        /// All of `names` from the library at `path`, in order, or nil when the library or any symbol is missing.
        func resolve(_ names: [String], in path: String) -> [UnsafeMutableRawPointer]? {
            guard let handle = open(path) else { return nil }
            var found: [UnsafeMutableRawPointer] = []
            for name in names {
                guard let symbol = find(handle, name) else { return nil }
                found.append(symbol)
            }
            return found
        }
    }

    // C signatures, as used by SkyLightWindow (MIT) and macTilt on macOS 26.
    public typealias MainConnectionID = @convention(c) () -> Int32
    public typealias SpaceCreate = @convention(c) (Int32, Int32, Int32) -> Int32
    public typealias SpaceSetAbsoluteLevel = @convention(c) (Int32, Int32, Int32) -> Int32
    public typealias ShowSpaces = @convention(c) (Int32, CFArray) -> Int32
    public typealias SpaceAddWindowsAndRemoveFromSpaces = @convention(c) (Int32, Int32, CFArray, Int32) -> Int32
    public typealias LockScreenImmediate = @convention(c) () -> Int32
    public typealias SetConnectionProperty = @convention(c) (Int32, Int32, CFString, CFBoolean) -> Int32

    /// SkyLight: a space above the lock screen.
    public struct SkyLightFunctions: @unchecked Sendable {
        var mainConnectionID: MainConnectionID
        var spaceCreate: SpaceCreate
        var spaceSetAbsoluteLevel: SpaceSetAbsoluteLevel
        var showSpaces: ShowSpaces
        var spaceAddWindowsAndRemoveFromSpaces: SpaceAddWindowsAndRemoveFromSpaces
    }

    /// login.framework: lock the screen now.
    public struct LoginFunctions: @unchecked Sendable {
        var lockScreenImmediate: LockScreenImmediate
    }

    /// SkyLight: let a background app hide the cursor.
    public struct CursorFunctions: @unchecked Sendable {
        var mainConnectionID: MainConnectionID
        var setConnectionProperty: SetConnectionProperty
    }

    public static func skyLight(using loader: SymbolLoader = .system) -> SkyLightFunctions? {
        guard let s = loader.resolve(["SLSMainConnectionID", "SLSSpaceCreate", "SLSSpaceSetAbsoluteLevel",
                                      "SLSShowSpaces", "SLSSpaceAddWindowsAndRemoveFromSpaces"], in: skyLightPath) else { return nil }
        return SkyLightFunctions(
            mainConnectionID: unsafeBitCast(s[0], to: MainConnectionID.self),
            spaceCreate: unsafeBitCast(s[1], to: SpaceCreate.self),
            spaceSetAbsoluteLevel: unsafeBitCast(s[2], to: SpaceSetAbsoluteLevel.self),
            showSpaces: unsafeBitCast(s[3], to: ShowSpaces.self),
            spaceAddWindowsAndRemoveFromSpaces: unsafeBitCast(s[4], to: SpaceAddWindowsAndRemoveFromSpaces.self)
        )
    }

    public static func login(using loader: SymbolLoader = .system) -> LoginFunctions? {
        guard let s = loader.resolve(["SACLockScreenImmediate"], in: loginPath) else { return nil }
        return LoginFunctions(lockScreenImmediate: unsafeBitCast(s[0], to: LockScreenImmediate.self))
    }

    public static func cursor(using loader: SymbolLoader = .system) -> CursorFunctions? {
        guard let s = loader.resolve(["CGSMainConnectionID", "CGSSetConnectionProperty"], in: skyLightPath) else { return nil }
        return CursorFunctions(
            mainConnectionID: unsafeBitCast(s[0], to: MainConnectionID.self),
            setConnectionProperty: unsafeBitCast(s[1], to: SetConnectionProperty.self)
        )
    }
}

/// A SkyLight space above the lock screen (spec 5.2, 10.7): a window moved into it stays visible while the Mac is
/// locked. Only ever used for the lock screen surface, which the compiler limits to the wallpaper (spec 10.6).
@MainActor
public final class LockScreenSpace {
    /// kSLSSpaceAbsoluteLevelNotificationCenterAtScreenLock, the level SkyLightWindow and macTilt use on macOS 26.
    /// 300 is the lock screen's own level; early check R3 (spec section 15) confirms which one shows.
    public static let absoluteLevel: Int32 = 400
    /// Window level inside the space, as in SkyLightWindow.
    public static let windowLevel = NSWindow.Level(rawValue: Int(Int32.max - 2))
    /// The last argument SkyLightWindow passes to SLSSpaceAddWindowsAndRemoveFromSpaces.
    static let moveFlags: Int32 = 7

    private let functions: PrivateAPI.SkyLightFunctions
    private var connection: Int32 = 0
    private var space: Int32 = 0

    public init?(functions: PrivateAPI.SkyLightFunctions?) {
        guard let functions else { return nil }
        self.functions = functions
    }

    /// Moves `window` into the space, creating the space on first use. Call it after every `orderFront`.
    @discardableResult
    public func adopt(_ window: NSWindow) -> Bool {
        guard window.windowNumber > 0 else { return false }
        if space == 0 {
            connection = functions.mainConnectionID()
            space = functions.spaceCreate(connection, 1, 0)
            guard space != 0 else { return false }
            _ = functions.spaceSetAbsoluteLevel(connection, space, Self.absoluteLevel)
            _ = functions.showSpaces(connection, [space] as CFArray)
        }
        window.canBecomeVisibleWithoutLogin = true
        window.level = Self.windowLevel
        return functions.spaceAddWindowsAndRemoveFromSpaces(connection, space, [window.windowNumber] as CFArray, Self.moveFlags) == 0
    }
}

/// Locks the screen (animated lock, spec 5.4).
@MainActor
public protocol ScreenLocking: AnyObject {
    var isAvailable: Bool { get }
    /// Locks now. False when this macOS has no way to.
    @discardableResult func lockNow() -> Bool
}

@MainActor
public final class ScreenLocker: ScreenLocking {
    private let functions: PrivateAPI.LoginFunctions?

    public init(functions: PrivateAPI.LoginFunctions?) {
        self.functions = functions
    }

    public var isAvailable: Bool { functions != nil }

    @discardableResult
    public func lockNow() -> Bool {
        guard let functions else { return false }
        _ = functions.lockScreenImmediate()
        return true
    }
}

/// Hides the cursor during the effect (spec 8.3, General).
@MainActor
public protocol CursorControlling: AnyObject {
    func setHidden(_ hidden: Bool)
}

/// macOS lets only the frontmost app hide the cursor, unless its connection sets "SetsCursorInBackground" (spec 10.7).
/// Hide and show calls stay balanced: macOS counts them.
@MainActor
public final class BackgroundCursor: CursorControlling {
    private let functions: PrivateAPI.CursorFunctions?
    private let hide: () -> Void
    private let show: () -> Void
    private var prepared = false
    public private(set) var isHidden = false

    public init(functions: PrivateAPI.CursorFunctions?,
                hide: @escaping () -> Void = { _ = CGDisplayHideCursor(CGMainDisplayID()) },
                show: @escaping () -> Void = { _ = CGDisplayShowCursor(CGMainDisplayID()) }) {
        self.functions = functions
        self.hide = hide
        self.show = show
    }

    public var isAvailable: Bool { functions != nil }

    public func setHidden(_ hidden: Bool) {
        guard let functions, hidden != isHidden else { return }
        if hidden, !prepared {
            let connection = functions.mainConnectionID()
            _ = functions.setConnectionProperty(connection, connection, "SetsCursorInBackground" as CFString, kCFBooleanTrue)
            prepared = true
        }
        if hidden { hide() } else { show() }
        isHidden = hidden
    }
}
