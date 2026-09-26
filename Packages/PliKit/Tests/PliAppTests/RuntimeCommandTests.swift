import PliCore
import Testing
@testable import PliApp

@MainActor @Suite struct RuntimeCommandTests {
    @Test func closingTheLidCapturesThenShowsTheDesktop() {
        let h = RuntimeHarness()
        h.moveLid(to: 40, over: 0.5)
        #expect(h.snapshotter.requests == [1])
        #expect(h.surfaces.count(.snapshot) == 1)
        #expect(h.surfaces.visibleSurfaces == [.desktop])
        #expect((h.surfaces.renders(.desktop).last ?? 0) > 0.5)
        #expect(h.cursor.hidden)
        let shown = h.surfaces.time(of: .show(.desktop)) ?? 0
        let captured = h.surfaces.time(of: .snapshot) ?? 1
        #expect(captured <= shown)   // the picture is in place before the overlay appears
    }

    @Test func reopeningHidesAtOnceAndReleasesThePictureASecondLater() {
        let h = RuntimeHarness()
        h.moveLid(to: 40, over: 0.5)
        h.moveLid(to: 110, over: 0.4, hold: 0.3)
        #expect(h.surfaces.visibleSurfaces.isEmpty)
        #expect(h.surfaces.count(.hide(.desktop, 0)) == 1)
        #expect(h.surfaces.count(.release) == 0)
        h.run(for: 1.0)
        #expect(h.surfaces.count(.release) == 1)
        let hidden = h.surfaces.time(of: .hide(.desktop, 0)) ?? 0
        let released = h.surfaces.time(of: .release) ?? 0
        #expect(abs(released - hidden - 1) < 0.02)
        #expect(!h.cursor.hidden)
    }

    @Test func aNewCaptureKeepsTheDelayedReleaseFromFiring() {
        let h = RuntimeHarness()
        h.moveLid(to: 40, over: 0.5)
        h.moveLid(to: 110, over: 0.4, hold: 0.1)
        let hidden = h.surfaces.time(of: .hide(.desktop, 0)) ?? 0
        h.moveLid(to: 40, over: 0.4, hold: 0.6)
        #expect(h.now > hidden + 1)
        #expect(h.surfaces.count(.release) == 0)
        #expect(h.surfaces.visibleSurfaces == [.desktop])
        #expect(h.snapshotter.requests.count == 2)
    }

    @Test func aCaptureRefusedForPermissionSwitchesToBasic() {
        let h = RuntimeHarness()
        h.snapshotter.behavior = .fail(.permissionMissing)
        h.environment.value.screenCaptureAllowed = false   // revoked while running (spec 11)
        h.moveLid(to: 60, over: 0.4, hold: 0.2)
        #expect(h.surfaces.configurations.last?.basic == true)
        #expect(!h.runtime.director.capabilities.screenCaptureAllowed)
        #expect(!h.surfaces.visibleSurfaces.contains(.desktop))   // no effect for that gesture
        h.moveLid(to: 110, over: 0.4, hold: 0.3)
        h.moveLid(to: 40, over: 0.4)
        #expect(h.snapshotter.requests.count == 1)                // the next gesture is Basic: no capture
        #expect(h.surfaces.visibleSurfaces == [.desktop])
    }
}
