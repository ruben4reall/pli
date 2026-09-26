import AppKit
import Metal
import PliCore
import PliRender
import Testing
@testable import PliApp
@testable import PliSystem

@MainActor @Suite struct BasicOverlayLayoutTests {
    @Test func nothingShowsAtRest() {
        let layout = BasicOverlayLayout.make(progress: 0, parameters: .duo)
        #expect(layout == BasicOverlayLayout(frostOpacity: 0, frostReach: 0, darkTop: 0, darkBottom: 0, blackout: 0))
    }

    @Test func theEndIsBlack() {
        #expect(BasicOverlayLayout.make(progress: 1, parameters: .duo).blackout == 1)
        var noBlackout = GlassParameters.duo
        noBlackout.finalBlackout = 0
        #expect(BasicOverlayLayout.make(progress: 1, parameters: noBlackout).blackout == 0)
    }

    @Test func everythingGrowsWithTheFold() {
        var previous = BasicOverlayLayout.make(progress: 0, parameters: .duo)
        for step in 1...100 {
            let layout = BasicOverlayLayout.make(progress: Double(step) / 100, parameters: .duo)
            #expect(layout.frostOpacity >= previous.frostOpacity && layout.frostReach >= previous.frostReach)
            #expect(layout.darkTop >= previous.darkTop && layout.blackout >= previous.blackout)
            #expect(layout.darkBottom <= layout.darkTop)
            previous = layout
        }
    }

    @Test func zeroFrostAndZeroDarkeningAreOff() {
        var clear = GlassParameters.duo
        clear.frost = 0
        clear.darkening = 0
        let layout = BasicOverlayLayout.make(progress: 0.7, parameters: clear)
        #expect(layout.frostOpacity == 0 && layout.darkTop == 0)
    }
}

@MainActor @Suite struct OverlayWindowTests {
    init() { _ = NSApplication.shared }

    /// Spec 5.6: the overlay always lets clicks and keys through, and is on every Space above full-screen apps.
    @Test func theOverlayNeverTakesInput() {
        let window = OverlayWindow(frame: CGRect(x: 0, y: 0, width: 64, height: 40))
        #expect(window.level == .screenSaver)
        #expect(window.ignoresMouseEvents)
        #expect(!window.canBecomeKey && !window.canBecomeMain)
        #expect(window.collectionBehavior.isSuperset(of: [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]))
        #expect(!window.isOpaque && !window.hasShadow && window.backgroundColor == .clear)
        #expect(window.styleMask.contains(.nonactivatingPanel))
        #expect(!window.isVisible && window.alphaValue == 0)
    }

    @Test func presentingAndDismissingOrdersInAndOut() {
        let window = OverlayWindow(frame: CGRect(x: 0, y: 0, width: 64, height: 40))
        window.present()
        #expect(window.isVisible && window.alphaValue == 1)
        var done = false
        window.dismiss(fade: 0) { done = true }
        #expect(!window.isVisible && done)
    }
}

@MainActor @Suite struct OverlayControllerTests {
    init() { _ = NSApplication.shared }

    /// A tiny display in the corner, so tests never cover the screen.
    private let display = DisplayDescription(id: 1, isBuiltIn: true, isMain: true, frame: CGRect(x: 0, y: 0, width: 64, height: 40),
                                             backingScale: 2, physicalSizeMM: CGSize(width: 301.2, height: 195.6))

    private func configuration(_ display: DisplayDescription?, basic: Bool = false) -> SurfaceConfiguration {
        SurfaceConfiguration(display: display, glass: .duo, basic: basic, quality: .full, halfResolution: false, reduceMotion: false)
    }

    @Test func withoutMetalOrSkyLightTheDesktopFallsBackToBasicAndThereIsNoLockSurface() {
        let controller = OverlayController(renderer: nil, lockSpace: nil)
        controller.configure(configuration(display))
        controller.show(.desktop)
        controller.render(.desktop, progress: 0.5)
        controller.show(.lockScreen)
        #expect(controller.visibleSurfaces == [.desktop])
        controller.hide(.desktop, fade: 0)
        #expect(controller.visibleSurfaces.isEmpty)
    }

    @Test func pausingRemovesTheSurfaces() {
        let controller = OverlayController(renderer: nil, lockSpace: nil)
        controller.configure(configuration(display))
        controller.show(.desktop)
        controller.configure(configuration(nil))
        #expect(controller.visibleSurfaces.isEmpty)
        controller.show(.desktop)
        #expect(controller.visibleSurfaces.isEmpty)
    }

    @Test(.enabled(if: MTLCreateSystemDefaultDevice() != nil, "needs a GPU"))
    func theGlassDrawsASnapshotAndLetsItGo() throws {
        let controller = OverlayController(renderer: try GlassRenderer(), lockSpace: nil)
        controller.configure(configuration(display))
        controller.setDesktopSnapshot(TestPictures.snapshot())
        controller.show(.desktop)
        for step in 0...10 { controller.render(.desktop, progress: Double(step) / 10) }
        controller.hideAll()
        controller.releaseDesktopSnapshot()
        #expect(controller.visibleSurfaces.isEmpty)
    }
}
