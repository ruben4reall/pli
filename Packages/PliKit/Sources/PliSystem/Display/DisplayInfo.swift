import AppKit
import CoreGraphics
import IOKit

/// One display as Pli needs it: where it is, how dense it is, and whether it is the MacBook's own panel.
public struct DisplayDescription: Sendable, Equatable {
    public var id: CGDirectDisplayID
    public var isBuiltIn: Bool
    public var isMain: Bool
    /// Frame in points, in AppKit's global coordinates.
    public var frame: CGRect
    public var backingScale: Double
    /// Physical size reported by CoreGraphics, in millimeters; zero when the display does not say.
    public var physicalSizeMM: CGSize

    public init(id: CGDirectDisplayID, isBuiltIn: Bool, isMain: Bool, frame: CGRect, backingScale: Double, physicalSizeMM: CGSize) {
        self.id = id
        self.isBuiltIn = isBuiltIn
        self.isMain = isMain
        self.frame = frame
        self.backingScale = backingScale
        self.physicalSizeMM = physicalSizeMM
    }

    /// Size of the backing store in pixels: what the overlay draws into and what a capture returns.
    public var pixelWidth: Int { Int((frame.width * backingScale).rounded()) }
    public var pixelHeight: Int { Int((frame.height * backingScale).rounded()) }

    /// Backing pixels per physical millimeter (spec 7.1). A missing or implausible physical size falls back to a
    /// typical Mac density, so the optics stay sane on any display.
    public var pixelsPerMM: Double {
        let width = Double(physicalSizeMM.width)
        guard width >= 100, width <= 2000, pixelWidth > 0 else { return DisplayInfo.fallbackPointsPerMM * backingScale }
        return Double(pixelWidth) / width
    }
}

public enum DisplayInfo {
    /// About 114 points per inch: Mac displays at their default scaling sit between 4.3 and 5.1.
    public static let fallbackPointsPerMM = 4.5

    /// Where the effect plays: the built-in panel, or the main display of a Mac without one (spec 5.4).
    /// A MacBook whose panel is off (closed on an external display) gets nil, and Pli pauses (spec 5.5).
    public static func effectTarget(in displays: [DisplayDescription], isLaptop: Bool) -> DisplayDescription? {
        if let builtIn = displays.first(where: \.isBuiltIn) { return builtIn }
        guard !isLaptop else { return nil }
        return displays.first(where: \.isMain) ?? displays.first
    }

    /// Every display macOS is drawing on now.
    @MainActor
    public static func current() -> [DisplayDescription] {
        NSScreen.screens.compactMap { screen in
            guard let id = displayID(of: screen) else { return nil }
            return DisplayDescription(
                id: id,
                isBuiltIn: CGDisplayIsBuiltin(id) != 0,
                isMain: CGDisplayIsMain(id) != 0,
                frame: screen.frame,
                backingScale: Double(screen.backingScaleFactor),
                physicalSizeMM: CGDisplayScreenSize(id)
            )
        }
    }

    @MainActor
    public static func screen(for id: CGDirectDisplayID) -> NSScreen? {
        NSScreen.screens.first { displayID(of: $0) == id }
    }

    @MainActor
    static func displayID(of screen: NSScreen) -> CGDirectDisplayID? {
        (screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber).map { CGDirectDisplayID($0.uint32Value) }
    }

    /// True on a MacBook: only portables have a clamshell switch in the power manager. `hw.model` cannot tell
    /// (recent MacBooks are named "Mac15,6" like desktops).
    public static let isLaptop: Bool = {
        let root = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("IOPMrootDomain"))
        guard root != 0 else { return false }
        defer { IOObjectRelease(root) }
        return IORegistryEntryCreateCFProperty(root, "AppleClamshellState" as CFString, kCFAllocatorDefault, 0) != nil
    }()
}
