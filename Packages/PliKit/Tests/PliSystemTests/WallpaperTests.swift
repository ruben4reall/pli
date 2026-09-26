import CoreGraphics
import CoreVideo
import Foundation
import Testing
@testable import PliSystem

@Suite struct WallpaperTests {
    @Test func fillCoversTheScreenCenteredAndCropped() {
        let wide = WallpaperRenderer.aspectFillRect(image: CGSize(width: 3840, height: 2160), target: CGSize(width: 3024, height: 1964))
        #expect(abs(wide.height - 1964) < 1e-9 && wide.width > 3024)
        #expect(abs(wide.midX - 1512) < 1e-9 && abs(wide.midY - 982) < 1e-9)
        let square = WallpaperRenderer.aspectFillRect(image: CGSize(width: 6016, height: 6016), target: CGSize(width: 3024, height: 1964))
        #expect(abs(square.width - 3024) < 1e-9 && square.height > 1964)
        #expect(WallpaperRenderer.aspectFillRect(image: .zero, target: CGSize(width: 10, height: 5)) == CGRect(x: 0, y: 0, width: 10, height: 5))
    }

    @Test func darkAndLightImagesAreFoundInDynamicMetadata() {
        #expect(WallpaperRenderer.appearanceIndex(in: ["l": 0, "d": 1], darkAppearance: true) == 1)
        #expect(WallpaperRenderer.appearanceIndex(in: ["l": 0, "d": 1], darkAppearance: false) == 0)
        #expect(WallpaperRenderer.appearanceIndex(in: ["ap": ["d": 6, "l": 0], "si": [1, 2]], darkAppearance: true) == 6)
        #expect(WallpaperRenderer.appearanceIndex(in: ["x": 1], darkAppearance: true) == nil)
    }

    @Test func videosHaveNoStillAndDescriptorsPointToTheirThumbnail() throws {
        #expect(WallpaperRenderer.imageURL(for: URL(fileURLWithPath: "/tmp/Aerial.mov")) == nil)
        let still = URL(fileURLWithPath: "/tmp/Picture.heic")
        #expect(WallpaperRenderer.imageURL(for: still) == still)
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("pli-wallpaper-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let descriptor = directory.appendingPathComponent("Big Sur.madesktop")
        let plist: [String: Any] = ["thumbnailPath": "/System/Library/Desktop Pictures/.thumbnails/Big Sur.heic", "isDynamic": true]
        try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0).write(to: descriptor)
        #expect(WallpaperRenderer.imageURL(for: descriptor)?.path == "/System/Library/Desktop Pictures/.thumbnails/Big Sur.heic")
        try Data("not a plist".utf8).write(to: descriptor)
        #expect(WallpaperRenderer.imageURL(for: descriptor) == nil)
    }

    /// Reads the BGRA bytes of one row of a buffer.
    private func row(_ buffer: CVPixelBuffer, _ y: Int) -> [UInt8] {
        CVPixelBufferLockBaseAddress(buffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let base = CVPixelBufferGetBaseAddress(buffer)!.advanced(by: y * CVPixelBufferGetBytesPerRow(buffer))
        return Array(UnsafeBufferPointer(start: base.assumingMemoryBound(to: UInt8.self), count: CVPixelBufferGetWidth(buffer) * 4))
    }

    @Test func withoutAWallpaperTheNightGradientIsDrawn() throws {
        let source = try #require(WallpaperRenderer.render(url: nil, width: 40, height: 30, darkAppearance: true, displayID: 1))
        #expect(source.width == 40 && source.height == 30 && CVPixelBufferGetIOSurface(source.pixelBuffer) != nil)
        let top = row(source.pixelBuffer, 0), bottom = row(source.pixelBuffer, 29)
        #expect(top[2] > bottom[2] && top[0] > bottom[0])          // Slate above Night, in red and blue
        #expect(top.enumerated().allSatisfy { $0.offset % 4 == 3 || $0.element < 60 })   // dark everywhere
    }

    @Test func anUnreadableFileAlsoGivesTheGradient() throws {
        let source = try #require(WallpaperRenderer.render(url: URL(fileURLWithPath: "/nonexistent/wall.heic"), width: 8, height: 8,
                                                           darkAppearance: false, displayID: 1))
        #expect(row(source.pixelBuffer, 0)[2] < 60)
    }

    static let sonoma = "/System/Library/Desktop Pictures/Sonoma.heic"

    /// macOS's own dynamic wallpaper: two images, the dark one second.
    @Test(.enabled(if: FileManager.default.fileExists(atPath: sonoma), "needs Sonoma.heic"))
    func aRealDynamicWallpaperFollowsTheAppearance() throws {
        let url = URL(fileURLWithPath: Self.sonoma)
        let source = try #require(CGImageSourceCreateWithURL(url as CFURL, nil))
        let metadata = try #require(CGImageSourceCopyMetadataAtIndex(source, 0, nil))
        #expect(WallpaperRenderer.dynamicIndex(metadata: metadata, darkAppearance: true) == 1)
        #expect(WallpaperRenderer.dynamicIndex(metadata: metadata, darkAppearance: false) == 0)
        #expect(WallpaperRenderer.loadImage(at: url, darkAppearance: true) != nil)
    }
}
