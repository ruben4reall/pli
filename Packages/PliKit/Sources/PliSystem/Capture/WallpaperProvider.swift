import AppKit
import CoreVideo
import ImageIO

/// The picture for the lock screen surface (spec 10.6).
@MainActor
public protocol WallpaperProviding: AnyObject {
    /// Draws the wallpaper of `display` at its pixel size, off the main thread. A missing, unreadable or video
    /// wallpaper gives the Night gradient; the completion runs on the main actor.
    func load(for display: DisplayDescription, darkAppearance: Bool, completion: @escaping @MainActor (WallpaperSource) -> Void)
}

@MainActor
public final class WallpaperProvider: WallpaperProviding {
    public init() {}

    public func load(for display: DisplayDescription, darkAppearance: Bool, completion: @escaping @MainActor (WallpaperSource) -> Void) {
        let url = DisplayInfo.screen(for: display.id).flatMap { NSWorkspace.shared.desktopImageURL(for: $0) }
        let width = display.pixelWidth, height = display.pixelHeight, id = display.id
        Task.detached(priority: .userInitiated) {
            guard let source = WallpaperRenderer.render(url: url, width: width, height: height,
                                                        darkAppearance: darkAppearance, displayID: id) else { return }
            await completion(source)
        }
    }
}

/// Draws a wallpaper the way macOS fills the screen. Pure CoreGraphics, safe off the main thread.
enum WallpaperRenderer {
    static let videoExtensions: Set<String> = ["mov", "mp4", "m4v"]

    static func render(url: URL?, width: Int, height: Int, darkAppearance: Bool, displayID: CGDirectDisplayID) -> WallpaperSource? {
        guard let buffer = PixelBuffers.make(width: width, height: height) else { return nil }
        let image = url.flatMap(imageURL(for:)).flatMap { loadImage(at: $0, darkAppearance: darkAppearance) }
        draw(image, into: buffer)
        return WallpaperSource(pixelBuffer: buffer, displayID: displayID)
    }

    /// The still image behind a wallpaper URL: a `.madesktop` descriptor points to its thumbnail, a video has none.
    static func imageURL(for url: URL) -> URL? {
        let pathExtension = url.pathExtension.lowercased()
        if videoExtensions.contains(pathExtension) { return nil }
        guard pathExtension == "madesktop" else { return url }
        guard let data = try? Data(contentsOf: url),
              let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
              let path = plist["thumbnailPath"] as? String else { return nil }
        return URL(fileURLWithPath: path)
    }

    /// For a dynamic wallpaper, the image of the current appearance.
    static func loadImage(at url: URL, darkAppearance: Bool) -> CGImage? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil) else { return nil }
        let count = CGImageSourceGetCount(source)
        guard count > 0 else { return nil }
        var index = 0
        if count > 1, let metadata = CGImageSourceCopyMetadataAtIndex(source, 0, nil) {
            index = dynamicIndex(metadata: metadata, darkAppearance: darkAppearance) ?? 0
        }
        return CGImageSourceCreateImageAtIndex(source, index < count ? index : 0, nil)
    }

    /// Dynamic wallpapers carry a base64 property list naming the light and dark images: `apple_desktop:apr` is
    /// `{ l = 0; d = 1; }` (Sonoma.heic on macOS 26); solar and time-based ones keep the same pair under `ap`.
    static func dynamicIndex(metadata: CGImageMetadata, darkAppearance: Bool) -> Int? {
        for key in ["apple_desktop:apr", "apple_desktop:solar", "apple_desktop:h24"] {
            guard let value = CGImageMetadataCopyStringValueWithPath(metadata, nil, key as CFString) as String?,
                  let data = Data(base64Encoded: value),
                  let plist = try? PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any],
                  let index = appearanceIndex(in: plist, darkAppearance: darkAppearance) else { continue }
            return index
        }
        return nil
    }

    static func appearanceIndex(in plist: [String: Any], darkAppearance: Bool) -> Int? {
        let table = (plist["ap"] as? [String: Any]) ?? plist
        return (table[darkAppearance ? "d" : "l"] as? NSNumber)?.intValue
    }

    /// macOS's "Fill Screen": covers the target, centered, the overflow cropped.
    static func aspectFillRect(image: CGSize, target: CGSize) -> CGRect {
        guard image.width > 0, image.height > 0 else { return CGRect(origin: .zero, size: target) }
        let scale = max(target.width / image.width, target.height / image.height)
        let size = CGSize(width: image.width * scale, height: image.height * scale)
        return CGRect(x: (target.width - size.width) / 2, y: (target.height - size.height) / 2, width: size.width, height: size.height)
    }

    /// Draws `image` filling the buffer, or without one the Night gradient: Slate #161A22 at the top, Night #0A0C10 below.
    static func draw(_ image: CGImage?, into buffer: CVPixelBuffer) {
        CVPixelBufferLockBaseAddress(buffer, [])
        defer { CVPixelBufferUnlockBaseAddress(buffer, []) }
        let width = CVPixelBufferGetWidth(buffer), height = CVPixelBufferGetHeight(buffer)
        guard let space = CGColorSpace(name: CGColorSpace.displayP3),
              let context = CGContext(data: CVPixelBufferGetBaseAddress(buffer), width: width, height: height, bitsPerComponent: 8,
                                      bytesPerRow: CVPixelBufferGetBytesPerRow(buffer), space: space,
                                      bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)
        else { return }
        let bounds = CGRect(x: 0, y: 0, width: width, height: height)
        if let image {
            context.interpolationQuality = .high
            context.draw(image, in: aspectFillRect(image: CGSize(width: image.width, height: image.height), target: bounds.size))
            return
        }
        let night = CGColor(srgbRed: 10 / 255, green: 12 / 255, blue: 16 / 255, alpha: 1)
        let slate = CGColor(srgbRed: 22 / 255, green: 26 / 255, blue: 34 / 255, alpha: 1)
        guard let gradient = CGGradient(colorsSpace: space, colors: [night, slate] as CFArray, locations: [0, 1]) else {
            context.setFillColor(night)
            context.fill(bounds)
            return
        }
        context.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: height), options: [])
    }
}
