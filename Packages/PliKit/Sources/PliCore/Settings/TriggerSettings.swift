import Foundation

/// A global shortcut: a virtual key code plus Carbon modifier flags.
public struct KeyCombo: Codable, Hashable, Sendable {
    public var keyCode: UInt32
    public var modifiers: UInt32

    public init(keyCode: UInt32, modifiers: UInt32) {
        self.keyCode = keyCode
        self.modifiers = modifiers
    }

    // Carbon modifier flags (HIToolbox/Events.h), copied so PliCore stays Foundation-only.
    public static let command: UInt32 = 0x0100
    public static let shift: UInt32 = 0x0200
    public static let option: UInt32 = 0x0800
    public static let control: UInt32 = 0x1000

    /// Control-Option-Command-P (kVK_ANSI_P is 0x23).
    public static let defaultDemo = KeyCombo(keyCode: 0x23, modifiers: control | option | command)
    /// Control-Option-Command-L (kVK_ANSI_L is 0x25).
    public static let defaultLock = KeyCombo(keyCode: 0x25, modifiers: control | option | command)

    /// A global shortcut needs Command, Control, or Option.
    public var isValid: Bool { modifiers & (Self.command | Self.control | Self.option) != 0 }
}

/// When the desktop emerges from the frost after an unlock (spec 5.2).
public enum UnlockRevealMode: String, Codable, CaseIterable, Sendable {
    case afterLidClose
    case always
    case never
}

/// The Triggers pane (spec 8.4).
public struct TriggerSettings: Codable, Hashable, Sendable {
    public var lidClose: Bool
    public var unfoldOnLockScreen: Bool
    public var onUnlock: UnlockRevealMode
    public var demoEnabled: Bool
    public var demoShortcut: KeyCombo?
    public var animatedLockEnabled: Bool
    public var animatedLockShortcut: KeyCombo?

    public init(
        lidClose: Bool = true,
        unfoldOnLockScreen: Bool = true,
        onUnlock: UnlockRevealMode = .afterLidClose,
        demoEnabled: Bool = true,
        demoShortcut: KeyCombo? = .defaultDemo,
        animatedLockEnabled: Bool = true,
        animatedLockShortcut: KeyCombo? = .defaultLock
    ) {
        self.lidClose = lidClose
        self.unfoldOnLockScreen = unfoldOnLockScreen
        self.onUnlock = onUnlock
        self.demoEnabled = demoEnabled
        self.demoShortcut = demoShortcut
        self.animatedLockEnabled = animatedLockEnabled
        self.animatedLockShortcut = animatedLockShortcut
    }

    public static let `default` = TriggerSettings()

    enum CodingKeys: String, CodingKey {
        case lidClose, unfoldOnLockScreen, onUnlock, demoEnabled, demoShortcut, animatedLockEnabled, animatedLockShortcut
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = TriggerSettings.default
        self.init(
            lidClose: c.value(.lidClose, default: d.lidClose),
            unfoldOnLockScreen: c.value(.unfoldOnLockScreen, default: d.unfoldOnLockScreen),
            onUnlock: c.value(.onUnlock, default: d.onUnlock),
            demoEnabled: c.value(.demoEnabled, default: d.demoEnabled),
            demoShortcut: c.optionalValue(.demoShortcut, default: d.demoShortcut),
            animatedLockEnabled: c.value(.animatedLockEnabled, default: d.animatedLockEnabled),
            animatedLockShortcut: c.optionalValue(.animatedLockShortcut, default: d.animatedLockShortcut)
        )
    }

    /// Written by hand so a cleared shortcut is stored as null instead of being omitted
    /// (an omitted key would come back as the default shortcut).
    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(lidClose, forKey: .lidClose)
        try c.encode(unfoldOnLockScreen, forKey: .unfoldOnLockScreen)
        try c.encode(onUnlock, forKey: .onUnlock)
        try c.encode(demoEnabled, forKey: .demoEnabled)
        try c.encode(demoShortcut, forKey: .demoShortcut)
        try c.encode(animatedLockEnabled, forKey: .animatedLockEnabled)
        try c.encode(animatedLockShortcut, forKey: .animatedLockShortcut)
    }
}
