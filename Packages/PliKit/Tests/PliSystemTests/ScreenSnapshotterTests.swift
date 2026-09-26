import CoreGraphics
import CoreVideo
import Foundation
import Testing
@testable import PliSystem

@MainActor @Suite struct ScreenSnapshotterTests {
    final class Box { var result: Result<DesktopSnapshot, CaptureError>? }

    @Test func withoutThePermissionNothingIsAttempted() {
        let snapshotter = ScreenSnapshotter(isGranted: { false })
        let box = Box()
        snapshotter.capture(display: 1) { box.result = $0 }
        guard case .failure(.permissionMissing) = box.result else {
            Issue.record("expected an immediate permissionMissing, got \(String(describing: box.result))")
            return
        }
    }

    @Test func theCaptureIsNativeSizeWithoutCursorInDisplayP3() {
        #expect(ScreenSnapshotter.pixelSize(points: CGSize(width: 1512, height: 982), scale: 2) == (3024, 1964))
        #expect(ScreenSnapshotter.pixelSize(points: .zero, scale: 2) == (1, 1))
        let configuration = ScreenSnapshotter.configuration(width: 3024, height: 1964)
        #expect(configuration.width == 3024 && configuration.height == 1964)
        #expect(!configuration.showsCursor)
        #expect(configuration.pixelFormat == kCVPixelFormatType_32BGRA)
        #expect(configuration.colorSpaceName == CGColorSpace.displayP3)
    }

    @Test func picturesAreIOSurfaceBacked() throws {
        let buffer = try #require(PixelBuffers.make(width: 64, height: 40))
        #expect(CVPixelBufferGetIOSurface(buffer) != nil)
        let snapshot = DesktopSnapshot(pixelBuffer: buffer, displayID: 1, requestedAt: 0)
        #expect(snapshot.width == 64 && snapshot.height == 40)
        let wallpaper = WallpaperSource(pixelBuffer: buffer, displayID: 1)
        #expect(wallpaper.width == 64)
    }

    /// Opt-in, on a Mac where the test runner has Screen Recording: `PLI_CAPTURE_TEST=1 swift test --filter realCapture`.
    @Test(.enabled(if: ProcessInfo.processInfo.environment["PLI_CAPTURE_TEST"] == "1", "set PLI_CAPTURE_TEST=1"))
    func realCapture() async throws {
        let main = DisplayInfo.current().first { $0.isMain }
        let display = try #require(main)
        let snapshotter = ScreenSnapshotter()
        let result: Result<DesktopSnapshot, CaptureError> = await withCheckedContinuation { continuation in
            snapshotter.capture(display: display.id) { continuation.resume(returning: $0) }
        }
        let snapshot = try result.get()
        #expect(snapshot.width == display.pixelWidth && snapshot.height == display.pixelHeight)
        #expect(HostClock.now() - snapshot.requestedAt < 1)
    }
}
