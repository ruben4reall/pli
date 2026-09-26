import AppKit
import ImageIO
import CoreVideo
import PliCore
import PliRender
import ScreenCaptureKit
import SwiftUI
import Testing
@testable import PliUI

/// Shows a view in a real window for an instant and captures that window with ScreenCaptureKit, so Liquid Glass,
/// materials, native controls and the Metal preview all appear as on screen. Needs a logged-in Mac, the Screen
/// Recording permission for the terminal that runs the tests, and PLI_SNAPSHOTS=1. A test process cannot become the
/// active app, so windows show their inactive look (gray switches, dimmed title); the active look is checked on the
/// real app. Images go to Packages/PliKit/.build/snapshots/, never into the repository.
@MainActor
enum Snapshotter {
    static let directory = TestPaths.packageRoot.appendingPathComponent(".build/snapshots", isDirectory: true)

    enum Chrome {
        /// A titled window, like the Settings and welcome windows.
        case window
        /// A borderless panel on the popover material, like the menu bar panel.
        case panel
    }

    @discardableResult
    static func capture<Content: View>(_ name: String, size: CGSize, appearance: NSAppearance.Name, chrome: Chrome = .window,
                                       @ViewBuilder content: () -> Content) async throws -> URL {
        NSApplication.shared.setActivationPolicy(.accessory)
        let window = makeWindow(size: size, chrome: chrome, content: content())
        window.appearance = NSAppearance(named: appearance)
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        try await Task.sleep(for: .milliseconds(1200))
        let shareable = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        let listed = try #require(shareable.windows.first { $0.windowID == CGWindowID(window.windowNumber) })
        let filter = SCContentFilter(desktopIndependentWindow: listed)
        let configuration = SCStreamConfiguration()
        configuration.width = Int(filter.contentRect.width * CGFloat(filter.pointPixelScale))
        configuration.height = Int(filter.contentRect.height * CGFloat(filter.pointPixelScale))
        configuration.showsCursor = false
        configuration.ignoreShadowsSingleWindow = true
        let image = try await SCScreenshotManager.captureImage(contentFilter: filter, configuration: configuration)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("\(name)-\(appearance == .darkAqua ? "dark" : "light").png")
        let data = try #require(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try data.write(to: url)
        return url
    }

    private static func makeWindow<Content: View>(size: CGSize, chrome: Chrome, content: Content) -> NSWindow {
        switch chrome {
        case .window:
            let window = NSWindow(contentRect: NSRect(origin: CGPoint(x: 80, y: 80), size: size),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                                  backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            window.titlebarAppearsTransparent = true
            window.titleVisibility = .hidden
            window.contentViewController = NSHostingController(rootView: content)
            window.setContentSize(size)
            return window
        case .panel:
            // Like MenuBarExtra, the panel takes its content's height; `size` gives its width.
            let host = NSHostingView(rootView: content)
            let fitted = CGSize(width: size.width, height: max(host.fittingSize.height, 1))
            let panel = NSPanel(contentRect: NSRect(origin: CGPoint(x: 120, y: 120), size: fitted),
                                styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
            panel.isReleasedWhenClosed = false
            panel.isOpaque = false
            panel.backgroundColor = .clear
            let glass = NSVisualEffectView(frame: NSRect(origin: .zero, size: fitted))
            glass.material = .popover
            glass.state = .active
            glass.wantsLayer = true
            glass.layer?.cornerRadius = 16
            glass.layer?.masksToBounds = true
            host.frame = glass.bounds
            host.autoresizingMask = [.width, .height]
            glass.addSubview(host)
            panel.contentView = glass
            return panel
        }
    }
}

/// The interface the snapshots show: a MacBook with a sensor and every permission, lid at 104°, rest at 110°, a
/// picture of a made-up desktop, the real renderer.
@MainActor
enum SnapshotFixtures {
    static let appearances: [NSAppearance.Name] = [.aqua, .darkAqua]
    /// The detail area of the Settings window at its minimum size, for a pane shown alone.
    static let paneSize = CGSize(width: 660, height: 600)

    static func interface(live: LiveSnapshot = LiveSnapshot(lidAngle: 104, restAngle: 110),
                          settings: PliSettings = .default) -> InterfaceModel {
        var settings = settings
        settings.general.hasCompletedOnboarding = true
        let interface = InterfaceModel(settings: settings, presetStore: Fixtures.store(), renderer: try? GlassRenderer(),
                                       interpreter: FakeInterpreter(), live: live)
        interface.connect(FakeServices())
        interface.preview.setPicture(TestPicture.desktop())
        return interface
    }
}

/// A made-up desktop for the previews: a warm gradient, three light windows with a title bar and lines of text.
enum TestPicture {
    static func desktop(width: Int = 1512, height: Int = 982) -> PreviewPicture {
        let attributes: [CFString: Any] = [
            kCVPixelBufferIOSurfacePropertiesKey: [CFString: Any]() as CFDictionary,
            kCVPixelBufferMetalCompatibilityKey: true,
            kCVPixelBufferCGBitmapContextCompatibilityKey: true,
        ]
        var buffer: CVPixelBuffer?
        CVPixelBufferCreate(kCFAllocatorDefault, width, height, kCVPixelFormatType_32BGRA, attributes as CFDictionary, &buffer)
        let pixels = buffer!
        CVPixelBufferLockBaseAddress(pixels, [])
        defer { CVPixelBufferUnlockBaseAddress(pixels, []) }
        let space = CGColorSpace(name: CGColorSpace.displayP3)!
        let context = CGContext(data: CVPixelBufferGetBaseAddress(pixels), width: width, height: height, bitsPerComponent: 8,
                                bytesPerRow: CVPixelBufferGetBytesPerRow(pixels), space: space,
                                bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue)!
        // A picture of a real desktop when PLI_SNAPSHOT_DESKTOP names one (a PNG at the display's size).
        if let path = ProcessInfo.processInfo.environment["PLI_SNAPSHOT_DESKTOP"],
           let source = CGImageSourceCreateWithURL(URL(fileURLWithPath: path) as CFURL, nil), let image = CGImageSourceCreateImageAtIndex(source, 0, nil) {
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return PreviewPicture(pixelBuffer: pixels, kind: .screen, displayWidthMM: 301.2)
        }
        let colors = [CGColor(red: 0.29, green: 0.47, blue: 0.86, alpha: 1), CGColor(red: 0.95, green: 0.62, blue: 0.62, alpha: 1)] as CFArray
        let gradient = CGGradient(colorsSpace: space, colors: colors, locations: [0, 1])!
        context.drawLinearGradient(gradient, start: CGPoint(x: 0, y: height), end: CGPoint(x: width, y: 0), options: [])
        let w = Double(width), h = Double(height)
        let windows = [CGRect(x: w * 0.07, y: h * 0.12, width: w * 0.44, height: h * 0.52),
                       CGRect(x: w * 0.55, y: h * 0.18, width: w * 0.37, height: h * 0.40),
                       CGRect(x: w * 0.30, y: h * 0.58, width: w * 0.40, height: h * 0.30)]
        for rect in windows {
            context.setFillColor(CGColor(gray: 1, alpha: 0.97))
            context.addPath(CGPath(roundedRect: rect, cornerWidth: h * 0.016, cornerHeight: h * 0.016, transform: nil))
            context.fillPath()
            context.setFillColor(CGColor(gray: 0.9, alpha: 1))
            context.fill(CGRect(x: rect.minX, y: rect.maxY - h * 0.045, width: rect.width, height: h * 0.03))
            context.setFillColor(CGColor(gray: 0.2, alpha: 1))
            var y = rect.maxY - rect.height * 0.22
            while y > rect.minY + rect.height * 0.08 {
                context.fill(CGRect(x: rect.minX + rect.width * 0.07, y: y, width: rect.width * 0.62, height: max(h * 0.007, 1)))
                y -= rect.height * 0.09
            }
        }
        return PreviewPicture(pixelBuffer: pixels, kind: .screen, displayWidthMM: 301.2)
    }
}
