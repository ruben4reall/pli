import CoreGraphics
import CoreVideo

/// A capture of the desktop (spec 5.1). Only the desktop overlay draws it: the lock screen surface accepts a
/// `WallpaperSource` and nothing else, so the compiler keeps screen content off the lock screen (spec 5.2, 10.6).
/// Its initializer is internal: only `ScreenSnapshotter` makes one.
public final class DesktopSnapshot: @unchecked Sendable {
    /// IOSurface-backed BGRA pixels in Display P3. In memory only, never written anywhere (spec 10.9).
    public let pixelBuffer: CVPixelBuffer
    public let displayID: CGDirectDisplayID
    /// Host time when the capture was requested.
    public let requestedAt: Double

    init(pixelBuffer: CVPixelBuffer, displayID: CGDirectDisplayID, requestedAt: Double) {
        self.pixelBuffer = pixelBuffer
        self.displayID = displayID
        self.requestedAt = requestedAt
    }

    public var width: Int { CVPixelBufferGetWidth(pixelBuffer) }
    public var height: Int { CVPixelBufferGetHeight(pixelBuffer) }
}

/// The wallpaper, drawn at a display's pixel size: the only picture the lock screen surface accepts.
/// Its initializer is internal: only `WallpaperProvider` makes one.
public final class WallpaperSource: @unchecked Sendable {
    /// IOSurface-backed BGRA pixels in Display P3.
    public let pixelBuffer: CVPixelBuffer
    public let displayID: CGDirectDisplayID

    init(pixelBuffer: CVPixelBuffer, displayID: CGDirectDisplayID) {
        self.pixelBuffer = pixelBuffer
        self.displayID = displayID
    }

    public var width: Int { CVPixelBufferGetWidth(pixelBuffer) }
    public var height: Int { CVPixelBufferGetHeight(pixelBuffer) }
}

/// Shared by the capture and the wallpaper: an IOSurface-backed BGRA buffer Metal can use without a copy.
enum PixelBuffers {
    static func make(width: Int, height: Int) -> CVPixelBuffer? {
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any]() as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        var buffer: CVPixelBuffer?
        let status = CVPixelBufferCreate(kCFAllocatorDefault, max(width, 1), max(height, 1), kCVPixelFormatType_32BGRA,
                                         attributes as CFDictionary, &buffer)
        return status == kCVReturnSuccess ? buffer : nil
    }
}
