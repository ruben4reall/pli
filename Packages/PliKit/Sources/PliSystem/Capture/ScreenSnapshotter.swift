import AppKit
import CoreMedia
import ScreenCaptureKit

public enum CaptureError: Error, Sendable, Equatable {
    case permissionMissing
    case displayNotFound
    case failed(String)
}

/// One-shot captures of the desktop (spec 5.1, 10.5).
@MainActor
public protocol DesktopCapturing: AnyObject {
    /// Captures `display` without the cursor and without Pli's windows. The completion runs on the main actor.
    func capture(display: CGDirectDisplayID, completion: @escaping @MainActor (Result<DesktopSnapshot, CaptureError>) -> Void)
    /// Forgets the cached list of displays and windows: after a display change or a wake (spec 10.5).
    func invalidate()
    /// Lists displays and windows and makes one tiny capture ahead of time: measured on an M3 Pro, a cold first
    /// capture takes about 170 ms, a warm one about 45 ms, and the director gives a capture 250 ms (spec 5.6).
    func prewarm()
}

/// The Screen Recording permission (spec 10.5). macOS has no purpose string for it in Info.plist.
public enum ScreenRecordingPermission {
    public static var isGranted: Bool { CGPreflightScreenCaptureAccess() }

    /// Shows the system prompt the first time; afterwards macOS only lists Pli in System Settings.
    @discardableResult
    public static func request() -> Bool { CGRequestScreenCaptureAccess() }

    public static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!
}

@MainActor
public final class ScreenSnapshotter: DesktopCapturing {
    private let isGranted: () -> Bool
    private var content: SCShareableContent?

    public init(isGranted: @escaping () -> Bool = { ScreenRecordingPermission.isGranted }) {
        self.isGranted = isGranted
    }

    public func invalidate() {
        content = nil
    }

    public func prewarm() {
        guard isGranted() else { return }
        Task { @MainActor in
            do {
                let content = try await self.shareableContent()
                guard let display = content.displays.first else { return }
                let filter = SCContentFilter(display: display, excludingApplications: [], exceptingWindows: [])
                _ = try await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: Self.configuration(width: 16, height: 16))
            } catch {
                Log.capture.error("prewarm failed: \(String(describing: error), privacy: .public)")
            }
        }
    }

    public func capture(display: CGDirectDisplayID, completion: @escaping @MainActor (Result<DesktopSnapshot, CaptureError>) -> Void) {
        guard isGranted() else {
            completion(.failure(.permissionMissing))
            return
        }
        let requestedAt = HostClock.now()
        Task { @MainActor in
            do {
                let snapshot = try await self.snapshot(of: display, requestedAt: requestedAt)
                Log.capture.info("capture \(Int((HostClock.now() - requestedAt) * 1000)) ms, \(snapshot.width)x\(snapshot.height)")
                completion(.success(snapshot))
            } catch let error as CaptureError {
                completion(.failure(error))
            } catch {
                self.content = nil
                Log.capture.error("capture failed: \(String(describing: error), privacy: .public)")
                completion(.failure(.failed(String(describing: error))))
            }
        }
    }

    private func snapshot(of displayID: CGDirectDisplayID, requestedAt: Double) async throws -> DesktopSnapshot {
        let pid = ProcessInfo.processInfo.processIdentifier
        var content = try await shareableContent()
        if !content.applications.contains(where: { $0.processID == pid }) {
            // Listed before Pli had a window: list again, or the filter could not exclude Pli's own overlay.
            self.content = nil
            content = try await shareableContent()
        }
        guard let display = content.displays.first(where: { $0.displayID == displayID }) else { throw CaptureError.displayNotFound }
        let ownApps = content.applications.filter { $0.processID == pid }
        let filter = SCContentFilter(display: display, excludingApplications: ownApps, exceptingWindows: [])
        let size = Self.pixelSize(points: filter.contentRect.size, scale: Double(filter.pointPixelScale))
        let configuration = Self.configuration(width: size.width, height: size.height)
        let sample = try await SCScreenshotManager.captureSampleBuffer(contentFilter: filter, configuration: configuration)
        guard let pixelBuffer = sample.imageBuffer, CVPixelBufferGetIOSurface(pixelBuffer) != nil else {
            throw CaptureError.failed("no IOSurface-backed image")
        }
        return DesktopSnapshot(pixelBuffer: pixelBuffer, displayID: displayID, requestedAt: requestedAt)
    }

    /// Cached, refreshed after `invalidate()`. It lists windows that are not on screen too, so Pli's own app is in
    /// it even while every overlay is ordered out, and the filter can exclude it.
    private func shareableContent() async throws -> SCShareableContent {
        if let content { return content }
        let fresh = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        content = fresh
        return fresh
    }

    /// Native resolution, no cursor, BGRA, Display P3 (spec 10.5).
    static func configuration(width: Int, height: Int) -> SCStreamConfiguration {
        let configuration = SCStreamConfiguration()
        configuration.width = width
        configuration.height = height
        configuration.showsCursor = false
        configuration.pixelFormat = kCVPixelFormatType_32BGRA
        configuration.colorSpaceName = CGColorSpace.displayP3
        configuration.captureResolution = .best
        return configuration
    }

    static func pixelSize(points: CGSize, scale: Double) -> (width: Int, height: Int) {
        (max(Int((Double(points.width) * scale).rounded()), 1), max(Int((Double(points.height) * scale).rounded()), 1))
    }
}
